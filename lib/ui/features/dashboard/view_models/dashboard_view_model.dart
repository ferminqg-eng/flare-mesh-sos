import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/emergency_mesh_repository.dart';
import '../../../../data/services/ble_mesh_background_service.dart';
import '../../../../domain/models/emergency_packet.dart';
import '../../../../domain/models/emergency_type.dart';

class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({required EmergencyMeshRepository repository})
      : _repository = repository {
    _statsSubscription = BleMeshBackgroundService.onMeshStatsStream.listen((event) {
      if (event == null) return;
      _relayedCount = (event['relayedCount'] as num?)?.toInt() ?? _relayedCount;
      notifyListeners();
    });
  }

  final EmergencyMeshRepository _repository;
  StreamSubscription<Map<String, dynamic>?>? _statsSubscription;

  int? _ownPhoneUint64;
  int? get ownPhoneUint64 => _ownPhoneUint64;

  EmergencyType? _activeSendingType;
  EmergencyType? get activeSendingType => _activeSendingType;

  EmergencyPacket? _lastSentPacket;
  EmergencyPacket? get lastSentPacket => _lastSentPacket;

  int _relayedCount = 0;
  int get relayedCount => _relayedCount;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadNodeIdentity() async {
    _ownPhoneUint64 = await _repository.getRegisteredPhoneId();
    notifyListeners();
  }

  Future<EmergencyPacket?> fireEmergency(EmergencyType type) async {
    if (_activeSendingType != null) return null;
    _activeSendingType = type;
    _errorMessage = null;
    notifyListeners();

    try {
      final packet = await _repository.triggerEmergencyBroadcast(type);
      _lastSentPacket = packet;
      return packet;
    } catch (e) {
      _errorMessage = '$e';
      return null;
    } finally {
      _activeSendingType = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    super.dispose();
  }
}
