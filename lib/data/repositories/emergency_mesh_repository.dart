import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../domain/models/alert_settings.dart';
import '../../domain/models/emergency_contact.dart';
import '../../domain/models/emergency_packet.dart';
import '../../domain/models/emergency_type.dart';
import '../services/ble_mesh_background_service.dart';
import '../services/contacts_adapter_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_service.dart';

/// Repositorio central (Single Source of Truth) para configuración de red, contactos y despacho SOS.
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

  /// Valida y registra el número telefónico manual como ID único uint64 en la red Mesh.
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

  /// Solicita permisos de radio BLE, GPS y exención de batería antes de iniciar el nodo puente.
  Future<void> requestMeshHardwarePermissions() async {
    final permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.notification,
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
  }

  /// Captura coordenadas GPS precisas, empaqueta en 18 bytes y emite por BLE Mesh + GPRS.
  Future<EmergencyPacket> triggerEmergencyBroadcast(EmergencyType type) async {
    final senderPhone = await _storage.getRegisteredPhoneUint64();
    if (senderPhone == null) {
      throw StateError('Debes registrar tu número de teléfono antes de emitir una alerta.');
    }

    await requestMeshHardwarePermissions();
    final position = await _location.getCurrentEmergencyPosition();
    final messageId = await _storage.nextMessageIdUint8();

    final packet = EmergencyPacket(
      senderPhone: senderPhone,
      latitude: position.latitude,
      longitude: position.longitude,
      emergencyCode: type.code,
      messageId: messageId,
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
