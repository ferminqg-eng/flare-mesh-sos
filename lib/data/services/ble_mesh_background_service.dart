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

import '../../domain/models/emergency_contact.dart';
import '../../domain/models/emergency_packet.dart';
import 'critical_alert_service.dart';
import 'gprs_gateway_service.dart';
import 'local_storage_service.dart';
import 'mesh_packet_codec.dart';

/// Nombres de eventos IPC entre el Isolate de UI y el Isolate del Servicio Background.
abstract final class MeshServiceEvents {
  static const String broadcastOwnSos = 'broadcast_own_sos';
  static const String reloadConfiguration = 'reload_configuration';
  static const String incomingEmergencyAlert = 'incoming_emergency_alert';
  static const String meshStatsUpdated = 'mesh_stats_updated';
}

/// Caché circular con TTL en memoria RAM para deduplicar paquetes Mesh por `(senderPhone, messageId)`.
class SeenPacketsCache {
  SeenPacketsCache({
    this.maxEntries = 512,
    this.ttl = const Duration(minutes: 10),
  });

  final int maxEntries;
  final Duration ttl;
  final LinkedHashMap<String, DateTime> _entries = LinkedHashMap<String, DateTime>();

  /// Retorna `true` si el paquete es NUEVO y lo registra; retorna `false` si ya fue visto.
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

/// Inicializador y orquestador del nodo BLE Mesh en segundo plano.
class BleMeshBackgroundService {
  const BleMeshBackgroundService._();

  static const String _foregroundChannelId = 'flare_mesh_relay_daemon';
  static const int _foregroundNotificationId = 9911;

  /// Configura e inicia el Foreground Service (Android) y los hooks Background (iOS).
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
        initialNotificationTitle: 'FlareMesh SOS • Nodo Activo',
        initialNotificationContent: 'Escuchando balizas BLE y colaborando como puente off-grid',
        foregroundServiceNotificationId: _foregroundNotificationId,
        foregroundServiceTypes: <AndroidForegroundType>[
          AndroidForegroundType.connectedDevice,
          AndroidForegroundType.location,
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

  static void dispatchOwnEmergency(EmergencyPacket packet) {
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
  Timer? stopAdvertisingTimer;
  Timer? scanWatchdogTimer;

  Future<void> advertise18BytePayload(
    Uint8List payload18Bytes, {
    Duration burstDuration = const Duration(seconds: 20),
  }) async {
    assert(payload18Bytes.length == MeshPacketCodec.payloadByteLength);

    stopAdvertisingTimer?.cancel();
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
    }

    // Presupuesto PDU BLE 4.0 Legacy (Máx 31 bytes):
    // Flags (3 B) + 16-bit Service UUID 0xFD99 (4 B) + Manufacturer Data (4 B header + 18 B) = 29 bytes <= 31 B.
    final advertiseData = AdvertiseDataCore(
      serviceUuid: MeshPacketCodec.meshServiceUuid,
      manufacturerId: MeshPacketCodec.meshManufacturerId,
      manufacturerData: payload18Bytes,
    );

    const androidSettings = AndroidAdvertiseSettings(
      advertiseSettings: AdvertiseSettings(
        advertiseMode: AdvertiseMode.advertiseModeLowLatency,
        txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
        connectable: false,
        timeout: 0,
      ),
    );

    await blePeripheral.start(
      advertiseData: advertiseData,
      androidSettings: androidSettings,
    );

    stopAdvertisingTimer = Timer(burstDuration, () async {
      if (await blePeripheral.isAdvertising) {
        await blePeripheral.stop();
      }
    });
  }

  Uint8List? extractRawPayload(AdvertisementData adv) {
    final mfBytes = adv.manufacturerData[MeshPacketCodec.meshManufacturerId];
    if (mfBytes != null && mfBytes.length == MeshPacketCodec.payloadByteLength) {
      return Uint8List.fromList(mfBytes);
    }

    final serviceGuid = Guid(MeshPacketCodec.meshServiceUuid);
    final svcBytes = adv.serviceData[serviceGuid];
    if (svcBytes != null && svcBytes.length == MeshPacketCodec.payloadByteLength) {
      return Uint8List.fromList(svcBytes);
    }
    return null;
  }

  Future<void> handleScanResults(List<ScanResult> results) async {
    for (final result in results) {
      final rawBytes = extractRawPayload(result.advertisementData);
      if (rawBytes == null) continue;

      final packet = MeshPacketCodec.tryDecode(rawBytes);
      if (packet == null) continue;

      if (ownPhoneId != null && packet.senderPhone == ownPhoneId) {
        continue;
      }

      if (!seenCache.markIfNew(packet)) {
        continue;
      }

      EmergencyContact? matchedContact;
      for (final contact in emergencyContacts) {
        if (contact.matchesSender(packet.senderPhone)) {
          matchedContact = contact;
          break;
        }
      }

      if (matchedContact == null) {
        // MODO PUENTE CIEGO (BLIND RELAY)
        final jitterMs = 60 + random.nextInt(260);
        unawaited(
          Future<void>.delayed(Duration(milliseconds: jitterMs), () async {
            await advertise18BytePayload(
              rawBytes,
              burstDuration: const Duration(seconds: 15),
            );
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
        // ALERTA ENTRANTE DE UNO DE LOS 4 CONTACTOS DE EMERGENCIA
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
        });

        unawaited(advertise18BytePayload(rawBytes, burstDuration: const Duration(seconds: 15)));
        unawaited(gprsGateway.tryForwardBinaryPacket(rawBytes));
      }
    }
  }

  Future<void> ensureScanningActive() async {
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) return;

    if (!FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.startScan(
        withServices: <Guid>[Guid(MeshPacketCodec.meshServiceUuid)],
        continuousUpdates: true,
        androidUsesFineLocation: true,
        removeIfGone: const Duration(seconds: 6),
      );
    }
  }

  final scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
    unawaited(handleScanResults(results));
  });

  service.on(MeshServiceEvents.reloadConfiguration).listen((_) async {
    ownPhoneId = await storage.getRegisteredPhoneUint64(reload: true);
    emergencyContacts = await storage.getEmergencyContacts(reload: true);
  });

  service.on(MeshServiceEvents.broadcastOwnSos).listen((payload) async {
    if (payload == null) return;
    final packet = EmergencyPacket.fromIsolateMap(payload);
    seenCache.markIfNew(packet);

    final raw18Bytes = MeshPacketCodec.encode(packet);
    await advertise18BytePayload(
      raw18Bytes,
      burstDuration: const Duration(seconds: 35),
    );
    unawaited(gprsGateway.tryForwardBinaryPacket(raw18Bytes));
  });

  await ensureScanningActive();
  scanWatchdogTimer = Timer.periodic(const Duration(seconds: 25), (_) {
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
