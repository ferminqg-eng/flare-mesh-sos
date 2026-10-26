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

    _pingSubscription = BleMeshBackgroundService.onMeshPingStream.listen((event) {
      if (event == null) return;
      _lastReceivedPing = Map<String, dynamic>.from(event);
      notifyListeners();
    });

    _diagSubscription = BleMeshBackgroundService.onDiagnosticsStream.listen((event) {
      if (event == null) return;
      _radioDiagnosticText = event['text'] as String? ?? _radioDiagnosticText;
      notifyListeners();
    });
  }

  final EmergencyMeshRepository _repository;
  StreamSubscription<Map<String, dynamic>?>? _statsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _pingSubscription;
  StreamSubscription<Map<String, dynamic>?>? _diagSubscription;

  String _radioDiagnosticText = 'Iniciando antenas Mesh...';
  String get radioDiagnosticText => _radioDiagnosticText;

  int? _ownPhoneUint64;
  int? get ownPhoneUint64 => _ownPhoneUint64;

  EmergencyType? _activeSendingType;
  EmergencyType? get activeSendingType => _activeSendingType;

  EmergencyPacket? _lastSentPacket;
  EmergencyPacket? get lastSentPacket => _lastSentPacket;

  int _relayedCount = 0;
  int get relayedCount => _relayedCount;

  bool _isSendingPing = false;
  bool get isSendingPing => _isSendingPing;

  Map<String, dynamic>? _lastReceivedPing;
  Map<String, dynamic>? get lastReceivedPing => _lastReceivedPing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadNodeIdentity() async {
    _ownPhoneUint64 = await _repository.getRegisteredPhoneId();
    notifyListeners();
  }

  Future<void> sendPing() async {
    if (_isSendingPing) return;
    _isSendingPing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.sendTestPing();
    } catch (e) {
      _errorMessage = 'Error enviando ping: $e';
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      _isSendingPing = false;
      notifyListeners();
    }
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

  Future<void> restartRadio() async {
    await _repository.requestMeshHardwarePermissions();
  }

  @override
  void dispose() {
    _statsSubscription?.cancel();
    _pingSubscription?.cancel();
    _diagSubscription?.cancel();
    super.dispose();
  }
}
