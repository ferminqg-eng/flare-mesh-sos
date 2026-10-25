import 'package:flutter/foundation.dart';

import '../../../../data/repositories/emergency_mesh_repository.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../domain/models/alert_settings.dart';
import '../../../../domain/models/emergency_contact.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required EmergencyMeshRepository repository})
      : _repository = repository;

  final EmergencyMeshRepository _repository;

  String? _registeredPhoneRaw;
  String? get registeredPhoneRaw => _registeredPhoneRaw;

  int? _registeredPhoneUint64;
  int? get registeredPhoneUint64 => _registeredPhoneUint64;

  List<EmergencyContact> _selectedContacts = const <EmergencyContact>[];
  List<EmergencyContact> get selectedContacts => _selectedContacts;

  AlertSettings _alertSettings = const AlertSettings();
  AlertSettings get alertSettings => _alertSettings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  bool get canAddMoreContacts =>
      _selectedContacts.length < LocalStorageService.maxEmergencyContacts;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _registeredPhoneRaw = await _repository.getRegisteredPhoneRaw();
      _registeredPhoneUint64 = await _repository.getRegisteredPhoneId();
      _selectedContacts = await _repository.getSavedEmergencyContacts();
      _alertSettings = await _repository.getAlertSettings();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateOwnPhone(String rawPhoneInput) async {
    try {
      final updatedUint64 = await _repository.updateOwnPhone(rawPhoneInput);
      _registeredPhoneUint64 = updatedUint64;
      _registeredPhoneRaw = rawPhoneInput;
      _statusMessage = 'Identificador actualizado exitosamente.';
      notifyListeners();
      return true;
    } on FormatException catch (e) {
      _statusMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _statusMessage = 'Error actualizando número: $e';
      notifyListeners();
      return false;
    }
  }

  Future<List<EmergencyContact>> fetchAddressBookContacts() async {
    return _repository.loadNativeAddressBook();
  }

  Future<void> addEmergencyContact(EmergencyContact contact) async {
    if (!canAddMoreContacts) {
      _statusMessage = 'Máximo ${LocalStorageService.maxEmergencyContacts} contactos permitidos.';
      notifyListeners();
      return;
    }

    final alreadyExists = _selectedContacts.any(
      (c) => c.matchesSender(contact.phoneUint64),
    );
    if (alreadyExists) {
      _statusMessage = '${contact.displayName} ya está en tu lista SOS.';
      notifyListeners();
      return;
    }

    final updated = List<EmergencyContact>.from(_selectedContacts)..add(contact);
    await _repository.updateEmergencyContacts(updated);
    _selectedContacts = updated;
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> removeEmergencyContact(EmergencyContact contact) async {
    final updated = _selectedContacts
        .where((c) => c.phoneUint64 != contact.phoneUint64)
        .toList(growable: false);
    await _repository.updateEmergencyContacts(updated);
    _selectedContacts = updated;
    notifyListeners();
  }

  Future<void> updateContactVerificationPin(EmergencyContact contact, String newPin) async {
    final cleaned = newPin.trim();
    if (cleaned.length < 4) {
      _statusMessage = 'El PIN de verificación debe tener al menos 4 dígitos.';
      notifyListeners();
      return;
    }

    final updated = _selectedContacts.map((c) {
      if (c.phoneUint64 == contact.phoneUint64) {
        return c.copyWith(verificationPin: cleaned);
      }
      return c;
    }).toList(growable: false);

    await _repository.updateEmergencyContacts(updated);
    _selectedContacts = updated;
    _statusMessage = 'PIN anti-usurpación actualizado para ${contact.displayName}.';
    notifyListeners();
  }

  Future<void> selectAlertTone(AlertTone tone) async {
    final updated = _alertSettings.copyWith(selectedTone: tone);
    await _repository.updateAlertSettings(updated);
    _alertSettings = updated;
    notifyListeners();
  }

  Future<void> toggleForcedVibration(bool enabled) async {
    final updated = _alertSettings.copyWith(forcedVibration: enabled);
    await _repository.updateAlertSettings(updated);
    _alertSettings = updated;
    notifyListeners();
  }
}
