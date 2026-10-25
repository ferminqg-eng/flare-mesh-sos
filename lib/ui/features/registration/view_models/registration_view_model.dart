import 'package:flutter/foundation.dart';

import '../../../../data/repositories/emergency_mesh_repository.dart';
import '../../../../data/services/ble_mesh_background_service.dart';

class RegistrationViewModel extends ChangeNotifier {
  RegistrationViewModel({required EmergencyMeshRepository repository})
      : _repository = repository;

  final EmergencyMeshRepository _repository;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> submitPhoneRegistration(String rawPhoneInput) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.registerPhone(rawPhoneInput);
      await _repository.requestMeshHardwarePermissions();
      await BleMeshBackgroundService.initializeAndStart();
      return true;
    } on FormatException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Error al activar el nodo Mesh: $e';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
