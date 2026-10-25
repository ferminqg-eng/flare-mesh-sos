import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/alert_settings.dart';
import '../../domain/models/emergency_contact.dart';

/// Persistencia local compartida entre el Isolate de UI y el Isolate de Background BLE.
class LocalStorageService {
  static const int maxEmergencyContacts = 4;

  static const String _keyUserPhoneUint64 = 'user_phone_uint64';
  static const String _keyUserPhoneRaw = 'user_phone_raw';
  static const String _keyEmergencyContacts = 'emergency_contacts_v1';
  static const String _keyAlertToneId = 'alert_tone_id';
  static const String _keyForcedVibration = 'forced_vibration';
  static const String _keyLastMessageId = 'last_message_id_uint8';

  Future<SharedPreferences> _prefs({bool reloadFromDisk = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (reloadFromDisk) {
      // Crítico cuando se lee desde el Isolate del Foreground Service en Android
      await prefs.reload();
    }
    return prefs;
  }

  Future<int?> getRegisteredPhoneUint64({bool reload = false}) async {
    final prefs = await _prefs(reloadFromDisk: reload);
    return prefs.getInt(_keyUserPhoneUint64);
  }

  Future<String?> getRegisteredPhoneRaw() async {
    final prefs = await _prefs();
    return prefs.getString(_keyUserPhoneRaw);
  }

  Future<void> saveRegisteredPhone({
    required String rawInput,
    required int phoneUint64,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(_keyUserPhoneRaw, rawInput.trim());
    await prefs.setInt(_keyUserPhoneUint64, phoneUint64);
  }

  Future<List<EmergencyContact>> getEmergencyContacts({bool reload = false}) async {
    final prefs = await _prefs(reloadFromDisk: reload);
    final rawList = prefs.getStringList(_keyEmergencyContacts) ?? const <String>[];
    return rawList
        .map((item) => EmergencyContact.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .take(maxEmergencyContacts)
        .toList(growable: false);
  }

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) async {
    if (contacts.length > maxEmergencyContacts) {
      throw StateError('Solo se permiten máximo $maxEmergencyContacts contactos de emergencia.');
    }
    final prefs = await _prefs();
    final encoded = contacts.map((c) => jsonEncode(c.toJson())).toList(growable: false);
    await prefs.setStringList(_keyEmergencyContacts, encoded);
  }

  Future<AlertSettings> getAlertSettings({bool reload = false}) async {
    final prefs = await _prefs(reloadFromDisk: reload);
    final toneId = prefs.getString(_keyAlertToneId);
    final forcedVibration = prefs.getBool(_keyForcedVibration) ?? true;
    return AlertSettings(
      selectedTone: AlertTone.fromId(toneId),
      forcedVibration: forcedVibration,
    );
  }

  Future<void> saveAlertSettings(AlertSettings settings) async {
    final prefs = await _prefs();
    await prefs.setString(_keyAlertToneId, settings.selectedTone.id);
    await prefs.setBool(_keyForcedVibration, settings.forcedVibration);
  }

  /// Genera el siguiente ID de mensaje de 1 byte (0..255) en aritmética modular uint8.
  Future<int> nextMessageIdUint8() async {
    final prefs = await _prefs(reloadFromDisk: true);
    final current = prefs.getInt(_keyLastMessageId) ?? 0;
    final nextId = (current + 1) & 0xFF;
    await prefs.setInt(_keyLastMessageId, nextId);
    return nextId;
  }
}
