import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/emergency_contact.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/flaming_bell_envelope_logo.dart';
import '../view_models/registration_view_model.dart';

/// Pantalla 1: Registro manual del número de teléfono como ID único uint64 en la red Mesh.
class RegistrationView extends StatefulWidget {
  const RegistrationView({
    super.key,
    required this.viewModel,
    required this.onRegistered,
  });

  final RegistrationViewModel viewModel;
  final VoidCallback onRegistered;

  @override
  State<RegistrationView> createState() => _RegistrationViewState();
}

class _RegistrationViewState extends State<RegistrationView> {
  final TextEditingController _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onActivatePressed() async {
    final ok = await widget.viewModel.submitPhoneRegistration(_phoneController.text);
    if (ok && mounted) {
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            final previewUint64 = EmergencyContact.parsePhoneToUint64(_phoneController.text);

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Center(child: FlamingBellEnvelopeLogo(size: 96)),
                      const SizedBox(height: 24),
                      Text(
                        'FlareMesh SOS',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Red colaborativa de emergencias Off-Grid vía BLE Mesh + GPRS. '
                        'Tu número telefónico será tu identificador binario único (8 bytes uint64).',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'NÚMERO DE TELÉFONO (ID DE NODO)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.flameAmber,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '+58 412 5550199',
                          prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppTheme.flameAmber),
                          errorText: widget.viewModel.errorMessage,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSlate,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.memory_rounded, size: 18, color: AppTheme.signalCyan),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                previewUint64 != null
                                    ? 'uint64 Node ID: $previewUint64 (8 bytes)'
                                    : 'Ingresa de 7 a 15 dígitos numéricos (estándar E.164)',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: widget.viewModel.isSubmitting ? null : _onActivatePressed,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.flameRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: widget.viewModel.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Icon(Icons.radar_rounded),
                        label: Text(
                          widget.viewModel.isSubmitting
                              ? 'INICIANDO NODO MESH...'
                              : 'REGISTRAR Y ACTIVAR NODO',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
