import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../../domain/models/emergency_contact.dart';
import '../../domain/models/emergency_packet.dart';
import 'critical_alert_service.dart';
import 'gprs_gateway_service.dart';
import 'local_storage_service.dart';
import 'mesh_packet_codec.dart';

abstract final class MeshServiceEvents {
  static const String broadcastOwnSos = 'broadcast_own_sos';
  static const String reloadConfiguration = 'reload_configuration';
  static const String incomingEmergencyAlert = 'incoming_emergency_alert';
  static const String meshStatsUpdated = 'mesh_stats_updated';
  static const String meshPingReceived = 'mesh_ping_received';
  static const String restartRadio = 'restart_radio';
  static const String diagnostics = 'mesh_diagnostics';
}

/// Caché circular con TTL en memoria RAM para deduplicar paquetes Mesh.
class SeenPacketsCache {
  SeenPacketsCache({
    this.maxEntries = 512,
    this.ttl = const Duration(minutes: 10),
  });

  final int maxEntries;
  final Duration ttl;
  final LinkedHashMap<String, DateTime> _entries = LinkedHashMap<String, DateTime>();

  bool markIfNew(EmergencyPacket packet) {
    final now = DateTime.now();
    _evictExpired(now);

    final key = packet.deduplicationKey;
    final previousTimestamp = _entries[key];
    if (previousTimestamp != null && now.difference(previousTimestamp) < ttl) {
      return false;
    }

    _entries.remove(key);
    _entries[key] = now;

    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return true;
  }

  void _evictExpired(DateTime now) {
    _entries.removeWhere((_, timestamp) => now.difference(timestamp) >= ttl);
  }
}

class BleMeshBackgroundService {
  const BleMeshBackgroundService._();

  static const String _foregroundChannelId = 'flare_mesh_relay_daemon';
  static const int _foregroundNotificationId = 9911;

  static Future<void> initializeAndStart() async {
    final service = FlutterBackgroundService();

    const relayDaemonChannel = AndroidNotificationChannel(
      _foregroundChannelId,
      'Nodo Puente FlareMesh Activo',
      description: 'Mantiene la antena BLE escuchando y retransmitiendo emergencias off-grid.',
      importance: Importance.low,
    );

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(relayDaemonChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onMeshServiceStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId: _foregroundChannelId,
        initialNotificationTitle: 'FlareMesh SOS • Red Activa',
        initialNotificationContent: 'Escaneando balizas BLE Mesh y listo para retransmitir',
        foregroundServiceNotificationId: _foregroundNotificationId,
        // SOLO connectedDevice: el tipo `location` lanza SecurityException en Android 14+
        // cuando el servicio arranca desde BOOT/background y mata el nodo.
        foregroundServiceTypes: <AndroidForegroundType>[
          AndroidForegroundType.connectedDevice,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onMeshServiceStart,
        onBackground: onIosBackground,
      ),
    );

    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  /// Garantiza que el nodo esté vivo (si murió, `invoke` se pierde en silencio).
  static Future<void> ensureRunning() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await initializeAndStart();
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  /// Fuerza al nodo a reiniciar escaneo tras conceder permisos.
  static void restartRadio() {
    FlutterBackgroundService().invoke(MeshServiceEvents.restartRadio);
  }

  static Stream<Map<String, dynamic>?> get onDiagnosticsStream =>
      FlutterBackgroundService().on(MeshServiceEvents.diagnostics);

  static Future<void> dispatchOwnEmergency(EmergencyPacket packet) async {
    await ensureRunning();
    FlutterBackgroundService().invoke(
      MeshServiceEvents.broadcastOwnSos,
      packet.toIsolateMap(),
    );
  }

  static void notifyConfigChanged() {
    FlutterBackgroundService().invoke(MeshServiceEvents.reloadConfiguration);
  }

  static Stream<Map<String, dynamic>?> get onIncomingAlertStream =>
      FlutterBackgroundService().on(MeshServiceEvents.incomingEmergencyAlert);

  static Stream<Map<String, dynamic>?> get onMeshStatsStream =>
      FlutterBackgroundService().on(MeshServiceEvents.meshStatsUpdated);

  static Stream<Map<String, dynamic>?> get onMeshPingStream =>
      FlutterBackgroundService().on(MeshServiceEvents.meshPingReceived);
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> onMeshServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final storage = LocalStorageService();
  final blePeripheral = FlutterBlePeripheral();
  final gprsGateway = GprsGatewayService();
  final seenCache = SeenPacketsCache();
  final random = Random();

  await CriticalAlertService.instance.initialize();

  int? ownPhoneId = await storage.getRegisteredPhoneUint64(reload: true);
  List<EmergencyContact> emergencyContacts = await storage.getEmergencyContacts(reload: true);
  int relayedPacketsCount = 0;
  int meshFramesHeard = 0;
  String scanStatus = 'iniciando';
  String advStatus = 'inactivo';
  Timer? stopAdvertisingTimer;
  Timer? scanWatchdogTimer;

  void publishDiagnostics() {
    final text = 'Escaneo: $scanStatus | Antena TX: $advStatus | '
        'Tramas Mesh oídas: $meshFramesHeard | Retransmitidas: $relayedPacketsCount';
    service.invoke(MeshServiceEvents.diagnostics, <String, dynamic>{
      'text': text,
      'scanStatus': scanStatus,
      'advStatus': advStatus,
      'heard': meshFramesHeard,
      'relayed': relayedPacketsCount,
    });
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'FlareMesh SOS • Nodo Mesh',
        content: text,
      );
    }
  }

  Future<void> advertisePayload(
    Uint8List payloadBytes, {
    Duration burstDuration = const Duration(seconds: 25),
  }) async {
    stopAdvertisingTimer?.cancel();
    try {
      if (await blePeripheral.isAdvertising) {
        await blePeripheral.stop();
        // Android necesita liberar el slot del advertiser antes de reiniciarlo.
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      // PDU BLE Legacy: Flags (3 B) + Manufacturer AD (1+1+2+20 = 24 B) = 27 B <= 31 B.
      // Sin UUID de 128 bits, sin nombre de dispositivo, sin TxPower.
      final advertiseData = AdvertiseDataCore(
        manufacturerId: MeshPacketCodec.meshManufacturerId,
        manufacturerData: payloadBytes,
      );

      const androidSettings = AndroidAdvertiseSettings(
        advertiseSettings: AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeLowLatency,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          connectable: false,
          timeout: 0,
        ),
      );

      final state = await blePeripheral.start(
        advertiseData: advertiseData,
        androidSettings: androidSettings,
      );
      final nowAdvertising = await blePeripheral.isAdvertising;
      advStatus = nowAdvertising ? 'EMITIENDO' : 'FALLO (${state.name})';
    } catch (e) {
      advStatus = 'ERROR: $e';
    }
    publishDiagnostics();

    stopAdvertisingTimer = Timer(burstDuration, () async {
      try {
        if (await blePeripheral.isAdvertising) {
          await blePeripheral.stop();
        }
      } catch (_) {}
      advStatus = 'inactivo';
      publishDiagnostics();
    });
  }

  Uint8List? extractRawPayload(AdvertisementData adv) {
    // 1. Coincidencia directa por ID de fabricante de FlareMesh (0xFF45 = 65349)
    final mfBytes = adv.manufacturerData[MeshPacketCodec.meshManufacturerId];
    if (mfBytes != null && mfBytes.length == MeshPacketCodec.payloadByteLength) {
      return Uint8List.fromList(mfBytes);
    }

    // 2. Coincidencia por endianness invertido (0x45FF = 17919) común en chipsets MediaTek/Exynos
    final mfBytesInv = adv.manufacturerData[0x45FF];
    if (mfBytesInv != null && mfBytesInv.length == MeshPacketCodec.payloadByteLength) {
      return Uint8List.fromList(mfBytesInv);
    }

    // 3. Fallback tolerante: inspeccionar cualquier fabricante cuyo payload sea exactamente 20 bytes
    for (final entry in adv.manufacturerData.entries) {
      if (entry.value.length == MeshPacketCodec.payloadByteLength) {
        return Uint8List.fromList(entry.value);
      }
    }
    return null;
  }

  Future<void> handleScanResults(List<ScanResult> results) async {
    for (final result in results) {
      final rawBytes = extractRawPayload(result.advertisementData);
      if (rawBytes == null) continue;

      final packet = MeshPacketCodec.tryDecode(rawBytes);
      if (packet == null) continue;

      meshFramesHeard++;
      if (meshFramesHeard == 1 || meshFramesHeard % 10 == 0) {
        publishDiagnostics();
      }

      // 1. Ignorar eco de transmisiones propias
      if (ownPhoneId != null && packet.senderPhone == ownPhoneId) {
        continue;
      }

      // 2. Deduplicación por (senderPhone, messageId)
      if (!seenCache.markIfNew(packet)) {
        continue;
      }

      // 3. Buscar si el emisor coincide con alguno de los 4 contactos de emergencia
      EmergencyContact? matchedContact;
      for (final contact in emergencyContacts) {
        if (contact.matchesSender(packet.senderPhone)) {
          matchedContact = contact;
          break;
        }
      }

      // 4. Caso Especial: Pulso de Prueba (Ping de Enlace)
      if (packet.isTestPing) {
        final isAuthentic = matchedContact != null &&
            packet.authTag ==
                matchedContact.computeExpectedAuthTag(
                  senderPhone: packet.senderPhone,
                  emergencyCode: packet.emergencyCode,
                  messageId: packet.messageId,
                );

        service.invoke(MeshServiceEvents.meshPingReceived, <String, dynamic>{
          'senderPhone': packet.senderPhone,
          'senderName': matchedContact?.displayName ?? '+${packet.senderPhone}',
          'rssi': result.rssi,
          'isKnownContact': matchedContact != null,
          'isAuthentic': isAuthentic,
        });

        if (await Vibration.hasVibrator()) {
          await Vibration.vibrate(duration: 120, amplitude: 180);
        }
        continue;
      }

      // 5. Casos de Emergencias Reales (Códigos 1..4)
      if (matchedContact == null) {
        // MODO PUENTE CIEGO (BLIND RELAY):
        // Retransmite silenciosamente el paquete con jitter aleatorio
        final jitterMs = 50 + random.nextInt(220);
        unawaited(
          Future<void>.delayed(Duration(milliseconds: jitterMs), () async {
            await advertisePayload(rawBytes, burstDuration: const Duration(seconds: 15));
          }),
        );
        unawaited(gprsGateway.tryForwardBinaryPacket(rawBytes));

        relayedPacketsCount++;
        service.invoke(MeshServiceEvents.meshStatsUpdated, <String, dynamic>{
          'relayedCount': relayedPacketsCount,
        });

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'FlareMesh SOS • Nodo Puente Activo',
            content: 'Paquetes solidarios retransmitidos: $relayedPacketsCount',
          );
        }
      } else {
        // CONTACTO DE EMERGENCIA REGISTRADO:
        // Validar comprobación anti-usurpación con el PIN acordado
        final expectedAuthTag = matchedContact.computeExpectedAuthTag(
          senderPhone: packet.senderPhone,
          emergencyCode: packet.emergencyCode,
          messageId: packet.messageId,
        );
        final isAuthentic = (packet.authTag == expectedAuthTag);

        final alertSettings = await storage.getAlertSettings(reload: true);
        await CriticalAlertService.instance.triggerIncomingEmergencyAlert(
          packet: packet,
          senderDisplayName: matchedContact.displayName,
          settings: alertSettings,
        );

        service.invoke(MeshServiceEvents.incomingEmergencyAlert, <String, dynamic>{
          'packet': packet.toIsolateMap(),
          'senderName': matchedContact.displayName,
          'senderRawPhone': matchedContact.rawPhone,
          'isAuthentic': isAuthentic,
        });

        unawaited(advertisePayload(rawBytes, burstDuration: const Duration(seconds: 15)));
        unawaited(gprsGateway.tryForwardBinaryPacket(rawBytes));
      }
    }
  }

  Future<void> ensureScanningActive() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        scanStatus = 'activo (escuchando)';
        publishDiagnostics();
        return;
      }

      final adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 3), onTimeout: () => FlutterBluePlus.adapterStateNow);

      if (adapterState != BluetoothAdapterState.on) {
        scanStatus = 'Bluetooth apagado (${adapterState.name})';
        publishDiagnostics();
        return;
      }

      scanStatus = 'iniciando escaneo...';
      publishDiagnostics();

      await FlutterBluePlus.startScan(
        androidScanMode: AndroidScanMode.lowLatency,
        continuousUpdates: true,
        continuousDivisor: 1,
        oneByOne: true,
        androidLegacy: true, // Forzar escaneo en 1M PHY para capturar balizas Legacy
        androidUsesFineLocation: false, // Permisos ya gestionados en el hilo UI
        androidCheckLocationServices: false, // Evita fallo si el toggle GPS está desactivado
      );

      scanStatus = 'activo (escuchando)';
      publishDiagnostics();
    } catch (e) {
      scanStatus = 'error: $e';
      publishDiagnostics();
    }
  }

  final scanSubscription = FlutterBluePlus.onScanResults.listen(
    (results) {
      unawaited(handleScanResults(results));
    },
    onError: (Object error) {
      scanStatus = 'error stream: $error';
      publishDiagnostics();
    },
  );

  service.on(MeshServiceEvents.restartRadio).listen((_) async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}
    await ensureScanningActive();
  });

  service.on(MeshServiceEvents.reloadConfiguration).listen((_) async {
    ownPhoneId = await storage.getRegisteredPhoneUint64(reload: true);
    emergencyContacts = await storage.getEmergencyContacts(reload: true);
    publishDiagnostics();
  });

  service.on(MeshServiceEvents.broadcastOwnSos).listen((payload) async {
    if (payload == null) return;
    final packet = EmergencyPacket.fromIsolateMap(payload);
    seenCache.markIfNew(packet);

    final rawBytes = MeshPacketCodec.encode(packet);
    await advertisePayload(
      rawBytes,
      burstDuration: packet.isTestPing
          ? const Duration(seconds: 10)
          : const Duration(seconds: 35),
    );
    unawaited(gprsGateway.tryForwardBinaryPacket(rawBytes));
  });

  await ensureScanningActive();
  scanWatchdogTimer = Timer.periodic(const Duration(seconds: 20), (_) {
    unawaited(ensureScanningActive());
  });

  FlutterBluePlus.adapterState.listen((state) {
    if (state == BluetoothAdapterState.on) {
      unawaited(ensureScanningActive());
    }
  });

  service.on('stopService').listen((_) async {
    scanWatchdogTimer?.cancel();
    stopAdvertisingTimer?.cancel();
    await scanSubscription.cancel();
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    }
    await FlutterBluePlus.stopScan();
    await service.stopSelf();
  });
}
