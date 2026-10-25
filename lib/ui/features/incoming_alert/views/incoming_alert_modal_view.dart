import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../data/services/critical_alert_service.dart';
import '../../../../domain/models/emergency_packet.dart';
import '../../../core/theme/app_theme.dart';

/// Pantalla 4: Modal de pantalla completa que despierta el teléfono cuando se recibe
/// un paquete BLE/GPRS de uno de los 4 contactos de emergencia.
///
/// Muestra:
/// 1) Quién envía (resuelto desde la agenda local).
/// 2) El mensaje traducido a partir del código uint8.
/// 3) Un mini-mapa interactivo (`google_maps_flutter`) con las coordenadas float32.
class IncomingAlertModalView extends StatefulWidget {
  const IncomingAlertModalView({
    super.key,
    required this.packet,
    required this.senderDisplayName,
    this.senderRawPhone,
  });

  final EmergencyPacket packet;
  final String senderDisplayName;
  final String? senderRawPhone;

  @override
  State<IncomingAlertModalView> createState() => _IncomingAlertModalViewState();
}

class _IncomingAlertModalViewState extends State<IncomingAlertModalView> {
  @override
  void initState() {
    super.initState();
    // Mantiene la pantalla encendida con brillo activo mientras la emergencia esté en curso
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _acknowledgeAndSilence() async {
    await CriticalAlertService.instance.stopForcedVibrationAndDismiss();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentLocation = LatLng(widget.packet.latitude, widget.packet.longitude);
    final emergencyType = widget.packet.emergencyType;

    return Scaffold(
      backgroundColor: const Color(0xFF1A0707),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Cabecera pulsante de alerta crítica
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.flameRed,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'ALERTA MESH ENTRANTE • ${emergencyType.shortTag}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tarjeta del Contacto Emisor (Directorio Local) + Mensaje Traducido
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSlate,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.flameRed.withOpacity(0.65), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'ENVIADO POR CONTACTO DE EMERGENCIA',
                      style: TextStyle(
                        color: AppTheme.flameAmber,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.flameRed,
                          child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.senderDisplayName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                widget.senderRawPhone ?? '+${widget.packet.senderPhone}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: AppTheme.cardBorder),
                    const Text(
                      'MENSAJE TRADUCIDO (CÓDIGO BINARIO)',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      emergencyType.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      emergencyType.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mini-mapa interactivo con Google Maps Flutter
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: <Widget>[
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: incidentLocation,
                          zoom: 16.2,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: true,
                        markers: <Marker>{
                          Marker(
                            markerId: MarkerId(widget.packet.deduplicationKey),
                            position: incidentLocation,
                            infoWindow: InfoWindow(
                              title: widget.senderDisplayName,
                              snippet: emergencyType.title,
                            ),
                          ),
                        },
                        circles: <Circle>{
                          Circle(
                            circleId: const CircleId('sos_radius'),
                            center: incidentLocation,
                            radius: 35,
                            fillColor: AppTheme.flameRed.withOpacity(0.22),
                            strokeColor: AppTheme.flameRed,
                            strokeWidth: 2,
                          ),
                        },
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundObsidian.withOpacity(0.88),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'LAT ${widget.packet.latitude.toStringAsFixed(5)}  •  '
                            'LNG ${widget.packet.longitude.toStringAsFixed(5)}  •  '
                            'ID #${widget.packet.messageId}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Acción para silenciar alarma y confirmar lectura
              FilledButton.icon(
                onPressed: _acknowledgeAndSilence,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.backgroundObsidian,
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.volume_off_rounded),
                label: const Text(
                  'ATENDER Y DETENER ALARMA',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
