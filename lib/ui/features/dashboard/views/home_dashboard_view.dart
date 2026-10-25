import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/emergency_type.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/flaming_bell_envelope_logo.dart';
import '../view_models/dashboard_view_model.dart';

/// Pantalla 3: Home (Dashboard) con los 4 botones grandes y accesibles para disparar emergencias.
class HomeDashboardView extends StatefulWidget {
  const HomeDashboardView({
    super.key,
    required this.viewModel,
    required this.onOpenSettings,
  });

  final DashboardViewModel viewModel;
  final VoidCallback onOpenSettings;

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.loadNodeIdentity();
  }

  Future<void> _handleEmergencyTap(EmergencyType type) async {
    await HapticFeedback.heavyImpact();
    final packet = await widget.viewModel.fireEmergency(type);
    if (!mounted) return;

    if (packet != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.relayGreen,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Baliza de 18 bytes emitida (Msg #${packet.messageId}) • '
            'GPS: ${packet.latitude.toStringAsFixed(4)}, ${packet.longitude.toStringAsFixed(4)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    } else if (widget.viewModel.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.flameRed,
          behavior: SnackBarBehavior.floating,
          content: Text(widget.viewModel.errorMessage!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 58,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: FlamingBellEnvelopeLogo(size: 40),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'FlareMesh SOS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              'Malla Colaborativa BLE + GPRS',
              style: TextStyle(fontSize: 11.5, color: Colors.white60),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Configuración SOS',
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Banner de telemetría del Nodo Puente
                  _MeshNodeStatusCard(
                    ownNodeId: widget.viewModel.ownPhoneUint64,
                    relayedPackets: widget.viewModel.relayedCount,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'TOCA UN BOTÓN PARA EMITIR COORDENADAS Y ALERTA',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cuadrícula expandida con los 4 botones grandes y accesibles
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          child: _EmergencyActionButton(
                            type: EmergencyType.urgentHelp,
                            icon: Icons.sos_rounded,
                            accentColor: const Color(0xFFFF2D20),
                            isBusy: widget.viewModel.activeSendingType == EmergencyType.urgentHelp,
                            onPressed: () => _handleEmergencyTap(EmergencyType.urgentHelp),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _EmergencyActionButton(
                            type: EmergencyType.outOfCredit,
                            icon: Icons.phonelink_erase_rounded,
                            accentColor: const Color(0xFFFF9F0A),
                            isBusy: widget.viewModel.activeSendingType == EmergencyType.outOfCredit,
                            onPressed: () => _handleEmergencyTap(EmergencyType.outOfCredit),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _EmergencyActionButton(
                            type: EmergencyType.carBreakdown,
                            icon: Icons.car_crash_rounded,
                            accentColor: const Color(0xFF0A84FF),
                            isBusy: widget.viewModel.activeSendingType == EmergencyType.carBreakdown,
                            onPressed: () => _handleEmergencyTap(EmergencyType.carBreakdown),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _EmergencyActionButton(
                            type: EmergencyType.robberyTrackMe,
                            icon: Icons.my_location_rounded,
                            accentColor: const Color(0xFFBF5AF2),
                            isBusy:
                                widget.viewModel.activeSendingType == EmergencyType.robberyTrackMe,
                            onPressed: () => _handleEmergencyTap(EmergencyType.robberyTrackMe),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MeshNodeStatusCard extends StatelessWidget {
  const _MeshNodeStatusCard({
    required this.ownNodeId,
    required this.relayedPackets,
  });

  final int? ownNodeId;
  final int relayedPackets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSlate,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.relayGreen.withOpacity(0.45)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 11,
            height: 11,
            decoration: const BoxDecoration(
              color: AppTheme.relayGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Nodo Puente BLE Activo (18-Byte Binary Protocol)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  'ID: ${ownNodeId ?? "---"}  •  Puenteados: $relayedPackets paq.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.bluetooth_searching_rounded, color: AppTheme.signalCyan),
        ],
      ),
    );
  }
}

class _EmergencyActionButton extends StatelessWidget {
  const _EmergencyActionButton({
    required this.type,
    required this.icon,
    required this.accentColor,
    required this.isBusy,
    required this.onPressed,
  });

  final EmergencyType type;
  final IconData icon;
  final Color accentColor;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: type.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onPressed,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accentColor.withOpacity(0.26),
                  AppTheme.surfaceSlate,
                ],
              ),
              border: Border.all(color: accentColor.withOpacity(0.75), width: 1.8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: isBusy
                          ? CircularProgressIndicator(strokeWidth: 3, color: accentColor)
                          : Icon(icon, size: 32, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          type.title,
                          style: const TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.sensors_rounded, color: accentColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
