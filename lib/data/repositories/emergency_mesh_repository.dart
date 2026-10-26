import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/models/alert_settings.dart';
import '../../domain/models/emergency_contact.dart';
import '../../domain/models/emergency_packet.dart';
import '../../domain/models/emergency_type.dart';
import '../services/ble_mesh_background_service.dart';
import '../services/contacts_adapter_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';
import '../services/mesh_packet_codec.dart';

/// Repositorio central para gestión de identidad, permisos y emisión Mesh.
class EmergencyMeshRepository {
  EmergencyMeshRepository({
    required LocalStorageService storageService,
    required LocationService locationService,
    required ContactsAdapterService contactsService,
  })  : _storage = storageService,
        _location = locationService,
        _contacts = contactsService;

  final LocalStorageService _storage;
  final LocationService _location;
  final ContactsAdapterService _contacts;

  Future<int?> getRegisteredPhoneId() => _storage.getRegisteredPhoneUint64();

  Future<String?> getRegisteredPhoneRaw() => _storage.getRegisteredPhoneRaw();

  /// Valida y registra o actualiza el número de teléfono (Node ID).
  Future<int> registerPhone(String rawInput) async {
    final parsedUint64 = EmergencyContact.parsePhoneToUint64(rawInput);
    if (parsedUint64 == null) {
      throw const FormatException(
        'Ingresa un número válido de 7 a 15 dígitos (ej. +58 412 5550199).',
      );
    }

    await _storage.saveRegisteredPhone(
      rawInput: rawInput,
      phoneUint64: parsedUint64,
    );
    BleMeshBackgroundService.notifyConfigChanged();
    return parsedUint64;
  }

  /// Permite modificar el número propio desde la pantalla de Configuración.
  Future<int> updateOwnPhone(String rawInput) => registerPhone(rawInput);

  Future<void> requestMeshHardwarePermissions() async {
    final permissions = <Permission>[
      Permission.notification,
      Permission.location,
      Permission.locationWhenInUse,
      if (Platform.isAndroid) ...<Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.ignoreBatteryOptimizations,
      ] else if (Platform.isIOS) ...<Permission>[
        Permission.bluetooth,
      ],
    ];

    await permissions.request();

    // Si el Bluetooth está apagado en Android, solicitar encendido
    if (Platform.isAndroid) {
      try {
        final state = await FlutterBluePlus.adapterState.first
            .timeout(const Duration(seconds: 2), onTimeout: () => FlutterBluePlus.adapterStateNow);
        if (state != BluetoothAdapterState.on) {
          await FlutterBluePlus.turnOn();
        }
      } catch (_) {}
    }

    // Notificar al Isolate en segundo plano que reactive sus antenas
    BleMeshBackgroundService.restartRadio();
  }

  /// Emite un pulso de prueba (Ping) de corto alcance para validar conectividad entre teléfonos.
  Future<EmergencyPacket> sendTestPing() async {
    final senderPhone = await _storage.getRegisteredPhoneUint64();
    if (senderPhone == null) {
      throw StateError('Registra tu número antes de emitir un ping.');
    }

    final messageId = await _storage.nextMessageIdUint8();
    final contacts = await _storage.getEmergencyContacts();
    final primaryPin = contacts.isNotEmpty ? contacts.first.verificationPin : '1234';

    final authTag = MeshPacketCodec.computeAuthTag(
      senderPhone: senderPhone,
      emergencyCode: EmergencyType.testPing.code,
      messageId: messageId,
      verificationPin: primaryPin,
    );

    final packet = EmergencyPacket(
      senderPhone: senderPhone,
      latitude: 0.0,
      longitude: 0.0,
      emergencyCode: EmergencyType.testPing.code,
      messageId: messageId,
      authTag: authTag,
    );

    BleMeshBackgroundService.dispatchOwnEmergency(packet);
    return packet;
  }

  /// Captura coordenadas GPS precisas, empaqueta con tag criptográfico y emite por Mesh.
  Future<EmergencyPacket> triggerEmergencyBroadcast(EmergencyType type) async {
    final senderPhone = await _storage.getRegisteredPhoneUint64();
    if (senderPhone == null) {
      throw StateError('Debes registrar tu número de teléfono antes de emitir una alerta.');
    }

    await requestMeshHardwarePermissions();
    final position = await _location.getCurrentEmergencyPosition();
    final messageId = await _storage.nextMessageIdUint8();

    final contacts = await _storage.getEmergencyContacts();
    final primaryPin = contacts.isNotEmpty ? contacts.first.verificationPin : '1234';

    final authTag = MeshPacketCodec.computeAuthTag(
      senderPhone: senderPhone,
      emergencyCode: type.code,
      messageId: messageId,
      verificationPin: primaryPin,
    );

    final packet = EmergencyPacket(
      senderPhone: senderPhone,
      latitude: position.latitude,
      longitude: position.longitude,
      emergencyCode: type.code,
      messageId: messageId,
      authTag: authTag,
    );

    BleMeshBackgroundService.dispatchOwnEmergency(packet);
    return packet;
  }

  Future<List<EmergencyContact>> getSavedEmergencyContacts() =>
      _storage.getEmergencyContacts();

  Future<List<EmergencyContact>> loadNativeAddressBook() =>
      _contacts.fetchDeviceContacts();

  Future<void> updateEmergencyContacts(List<EmergencyContact> contacts) async {
    await _storage.saveEmergencyContacts(contacts);
    BleMeshBackgroundService.notifyConfigChanged();
  }

  Future<AlertSettings> getAlertSettings() => _storage.getAlertSettings();

  Future<void> updateAlertSettings(AlertSettings settings) async {
    await _storage.saveAlertSettings(settings);
    BleMeshBackgroundService.notifyConfigChanged();
  }
}
