import 'dart:async';

import 'package:flutter/material.dart';

import 'data/repositories/emergency_mesh_repository.dart';
import 'data/services/ble_mesh_background_service.dart';
import 'data/services/contacts_adapter_service.dart';
import 'data/services/critical_alert_service.dart';
import 'data/services/local_storage_service.dart';
import 'data/services/location_service.dart';
import 'domain/models/emergency_packet.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'ui/features/dashboard/views/home_dashboard_view.dart';
import 'ui/features/incoming_alert/views/incoming_alert_modal_view.dart';
import 'ui/features/registration/view_models/registration_view_model.dart';
import 'ui/features/registration/views/registration_view.dart';
import 'ui/features/settings/view_models/settings_view_model.dart';
import 'ui/features/settings/views/settings_view.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = LocalStorageService();
  final repository = EmergencyMeshRepository(
    storageService: storageService,
    locationService: LocationService(),
    contactsService: ContactsAdapterService(),
  );

  await CriticalAlertService.instance.initialize(
    onNotificationTap: (packet, senderName) {
      _presentFullScreenAlertModal(packet: packet, senderName: senderName);
    },
  );

  final registeredPhone = await repository.getRegisteredPhoneId();
  if (registeredPhone != null) {
    await BleMeshBackgroundService.initializeAndStart();
  }

  runApp(
    FlareMeshSosApp(
      repository: repository,
      isInitiallyRegistered: registeredPhone != null,
    ),
  );
}

void _presentFullScreenAlertModal({
  required EmergencyPacket packet,
  required String senderName,
  String? senderRawPhone,
}) {
  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;

  navigator.push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => IncomingAlertModalView(
        packet: packet,
        senderDisplayName: senderName,
        senderRawPhone: senderRawPhone,
      ),
    ),
  );
}

class FlareMeshSosApp extends StatefulWidget {
  const FlareMeshSosApp({
    super.key,
    required this.repository,
    required this.isInitiallyRegistered,
  });

  final EmergencyMeshRepository repository;
  final bool isInitiallyRegistered;

  @override
  State<FlareMeshSosApp> createState() => _FlareMeshSosAppState();
}

class _FlareMeshSosAppState extends State<FlareMeshSosApp> {
  late bool _isRegistered = widget.isInitiallyRegistered;
  late final DashboardViewModel _dashboardViewModel =
      DashboardViewModel(repository: widget.repository);
  StreamSubscription<Map<String, dynamic>?>? _incomingAlertSub;

  @override
  void initState() {
    super.initState();
    // Escucha alertas críticas enviadas en caliente desde el Isolate BLE Background
    _incomingAlertSub = BleMeshBackgroundService.onIncomingAlertStream.listen((payload) {
      if (payload == null) return;
      final packetMap = payload['packet'] as Map<String, dynamic>?;
      if (packetMap == null) return;

      final packet = EmergencyPacket.fromIsolateMap(packetMap);
      final senderName = payload['senderName'] as String? ?? '+${packet.senderPhone}';
      final senderRawPhone = payload['senderRawPhone'] as String?;

      _presentFullScreenAlertModal(
        packet: packet,
        senderName: senderName,
        senderRawPhone: senderRawPhone,
      );
    });
  }

  @override
  void dispose() {
    _incomingAlertSub?.cancel();
    _dashboardViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlareMesh SOS',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: AppTheme.darkEmergencyTheme,
      home: _isRegistered
          ? HomeDashboardView(
              viewModel: _dashboardViewModel,
              onOpenSettings: () {
                rootNavigatorKey.currentState?.push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsView(
                      viewModel: SettingsViewModel(repository: widget.repository),
                    ),
                  ),
                );
              },
            )
          : RegistrationView(
              viewModel: RegistrationViewModel(repository: widget.repository),
              onRegistered: () => setState(() => _isRegistered = true),
            ),
    );
  }
}
