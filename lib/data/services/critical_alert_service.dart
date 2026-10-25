import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../../domain/models/alert_settings.dart';
import '../../domain/models/emergency_packet.dart';

/// Callback invocado cuando el usuario toca la notificación crítica o despierta desde bloqueo.
typedef EmergencyNotificationTapCallback = void Function(
  EmergencyPacket packet,
  String senderDisplayName,
);

/// Gestiona alertas locales de prioridad máxima:
/// - Android: Canal Importance.max + AudioAttributesUsage.alarm + fullScreenIntent + bypassDnd.
/// - iOS: Critical Alerts Entitlement (`InterruptionLevel.critical`, volumen 100% aún en silencio).
/// - Hardware háptico: Vibración forzada en bucle hasta que el usuario atienda el modal.
class CriticalAlertService {
  CriticalAlertService._();

  static final CriticalAlertService instance = CriticalAlertService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  EmergencyNotificationTapCallback? _onNotificationTap;

  Future<void> initialize({
    EmergencyNotificationTapCallback? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap ?? _onNotificationTap;
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    await _notifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestFullScreenIntentPermission();

      for (final tone in AlertTone.values) {
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelIdForTone(tone),
            'Emergencia Mesh (${tone.label})',
            description: 'Alertas SOS off-grid entrantes de tus 4 contactos de emergencia.',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            bypassDnd: true,
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
      }
    } else if (Platform.isIOS) {
      final iosPlugin =
          _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
        critical: true,
      );
    }

    _initialized = true;
  }

  String _channelIdForTone(AlertTone tone) => 'flare_mesh_critical_${tone.id}';

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final packet = EmergencyPacket.fromIsolateMap(
        decoded['packet'] as Map<String, dynamic>,
      );
      final senderName = decoded['senderName'] as String? ?? '+${packet.senderPhone}';
      _onNotificationTap?.call(packet, senderName);
    } catch (_) {
      // Payload malformado ignorado de forma segura
    }
  }

  /// Dispara notificación Full-Screen + Critical Alert + Vibración Forzada.
  Future<void> triggerIncomingEmergencyAlert({
    required EmergencyPacket packet,
    required String senderDisplayName,
    required AlertSettings settings,
  }) async {
    await initialize();

    final tone = settings.selectedTone;
    final androidDetails = AndroidNotificationDetails(
      _channelIdForTone(tone),
      'Emergencia Mesh (${tone.label})',
      channelDescription: 'Canal crítico que despierta la pantalla ante emergencias cercanas.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
      criticalSoundVolume: 1.0,
    );

    final payloadJson = jsonEncode(<String, dynamic>{
      'packet': packet.toIsolateMap(),
      'senderName': senderDisplayName,
    });

    await _notifications.show(
      id: packet.deduplicationKey.hashCode & 0x7FFFFFFF,
      title: '🚨 ${packet.emergencyType.shortTag}: $senderDisplayName',
      body:
          '${packet.emergencyType.title} (${packet.latitude.toStringAsFixed(4)}, ${packet.longitude.toStringAsFixed(4)})',
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payloadJson,
    );

    if (settings.forcedVibration) {
      await startForcedVibration();
    }
  }

  /// Activa un patrón háptico de máxima intensidad en bucle (índice repeat: 0).
  Future<void> startForcedVibration() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;

    await Vibration.vibrate(
      pattern: const <int>[0, 900, 220, 900, 220, 1400, 350],
      intensities: const <int>[0, 255, 0, 255, 0, 255, 0],
      repeat: 0,
    );
  }

  /// Detiene la vibración forzada y limpia notificaciones cuando el usuario atiende el modal.
  Future<void> stopForcedVibrationAndDismiss() async {
    await Vibration.cancel();
    await _notifications.cancelAll();
  }
}
