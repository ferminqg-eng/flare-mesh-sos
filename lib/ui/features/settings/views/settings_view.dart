import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import '../../../../data/services/local_storage_service.dart';
import '../../../../domain/models/alert_settings.dart';
import '../../../../domain/models/emergency_contact.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/settings_view_model.dart';

/// Pantalla 2: Configuración (Edición de número propio, Contactos con Anti-Usurpación, Tonos y Vibración).
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.viewModel,
  });

  final SettingsViewModel viewModel;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.initialize();
  }

  Future<void> _openEditOwnPhoneDialog() async {
    final controller = TextEditingController(
      text: widget.viewModel.registeredPhoneRaw ?? '',
    );

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceSlate,
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: AppTheme.flameAmber),
            SizedBox(width: 10),
            Text('Editar Mi Número (Nodo)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este número es tu identificador binario (uint64) en la red Mesh.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: const InputDecoration(
                hintText: '+58 412 5550199',
                prefixIcon: Icon(Icons.phone_rounded, color: AppTheme.flameAmber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.flameRed),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (updated != null && updated.trim().isNotEmpty) {
      await widget.viewModel.updateOwnPhone(updated);
    }
  }

  Future<void> _openEditPinDialog(EmergencyContact contact) async {
    final controller = TextEditingController(text: contact.verificationPin);

    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceSlate,
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppTheme.signalCyan),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'PIN Anti-Usurpación (${contact.displayName})',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acuerda un PIN de 4 dígitos con este contacto. Las alertas solo se considerarán legítimas si vienen firmadas con este PIN secreto.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w900),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '1234',
                prefixIcon: Icon(Icons.key_rounded, color: AppTheme.signalCyan),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.signalCyan, foregroundColor: Colors.black),
            child: const Text('Guardar PIN'),
          ),
        ],
      ),
    );

    if (newPin != null && newPin.trim().isNotEmpty) {
      await widget.viewModel.updateContactVerificationPin(contact, newPin);
    }
  }

  Future<void> _openNativeContactPickerSheet() async {
    try {
      final allContacts = await widget.viewModel.fetchAddressBookContacts();
      if (!mounted) return;

      final selected = await showModalBottomSheet<EmergencyContact>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.surfaceSlate,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _AddressBookPickerSheet(contacts: allContacts),
      );

      if (selected != null) {
        await widget.viewModel.addEmergencyContact(selected);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.flameRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración SOS',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          if (widget.viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final contacts = widget.viewModel.selectedContacts;
          final settings = widget.viewModel.alertSettings;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              // ==================== SECCIÓN 0: MI NÚMERO (NODO) ====================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSlate,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppTheme.backgroundObsidian,
                      child: Icon(Icons.phone_iphone_rounded, color: AppTheme.flameAmber),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MI NÚMERO EN LA RED (NODE ID)',
                            style: TextStyle(
                              color: AppTheme.flameAmber,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.9,
                            ),
                          ),
                          Text(
                            widget.viewModel.registeredPhoneRaw ?? 'No configurado',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'ID uint64: ${widget.viewModel.registeredPhoneUint64 ?? "---"}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white54,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openEditOwnPhoneDialog,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Editar'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================== SECCIÓN 1: 4 CONTACTOS DE EMERGENCIA ====================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'CONTACTOS DE EMERGENCIA (${contacts.length}/${LocalStorageService.maxEmergencyContacts})',
                    style: const TextStyle(
                      color: AppTheme.flameAmber,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.viewModel.canAddMoreContacts
                        ? _openNativeContactPickerSheet
                        : null,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('Agenda'),
                  ),
                ],
              ),
              const Text(
                'Solo las alertas de estos contactos despertarán tu teléfono. '
                'Configura un PIN secreto por contacto para validar autenticidad (Anti-Usurpación).',
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 14),
              if (contacts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: <Widget>[
                        const Icon(Icons.contacts_rounded, size: 36, color: Colors.white38),
                        const SizedBox(height: 10),
                        const Text(
                          'Aún no has elegido contactos de confianza.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _openNativeContactPickerSheet,
                          icon: const Icon(Icons.import_contacts_rounded),
                          label: const Text('Elegir desde mi Agenda'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...contacts.map(
                  (contact) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.flameRed.withValues(alpha: 0.18),
                                foregroundColor: AppTheme.flameAmber,
                                child: Text(
                                  contact.displayName.characters.first.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              title: Text(
                                contact.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${contact.rawPhone}  •  ID: ${contact.phoneUint64}',
                                style: const TextStyle(fontSize: 12, color: Colors.white60),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                onPressed: () => widget.viewModel.removeEmergencyContact(contact),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundObsidian,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.signalCyan.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.lock_rounded, size: 14, color: AppTheme.signalCyan),
                                        const SizedBox(width: 6),
                                        Text(
                                          'PIN Verificación: ${contact.verificationPin}',
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.signalCyan,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => _openEditPinDialog(contact),
                                    icon: const Icon(Icons.vpn_key_rounded, size: 15),
                                    label: const Text('Cambiar PIN', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (widget.viewModel.statusMessage != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  widget.viewModel.statusMessage!,
                  style: const TextStyle(color: AppTheme.flameAmber, fontSize: 12.5),
                ),
              ],

              const SizedBox(height: 28),

              // ==================== SECCIÓN 2: SELECTOR DE TONOS DE ALERTA ====================
              const Text(
                'TONO DE ALERTA CRÍTICA',
                style: TextStyle(
                  color: AppTheme.flameAmber,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: AlertTone.values.map((tone) {
                    final isSelected = settings.selectedTone == tone;
                    return RadioListTile<AlertTone>(
                      value: tone,
                      groupValue: settings.selectedTone,
                      activeColor: AppTheme.flameRed,
                      onChanged: (val) {
                        if (val != null) widget.viewModel.selectAlertTone(val);
                      },
                      title: Text(
                        tone.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Recurso nativo: ${tone.iosSoundFile}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),

              const SizedBox(height: 24),

              // ==================== SECCIÓN 3: VIBRACIÓN FORZADA ====================
              const Text(
                'RESPUESTA HÁPTICA DE EMERGENCIA',
                style: TextStyle(
                  color: AppTheme.flameAmber,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: SwitchListTile(
                  value: settings.forcedVibration,
                  activeColor: AppTheme.flameRed,
                  onChanged: (enabled) async {
                    await widget.viewModel.toggleForcedVibration(enabled);
                    if (enabled && await Vibration.hasVibrator()) {
                      await Vibration.vibrate(duration: 350, amplitude: 255);
                    }
                  },
                  secondary: const Icon(Icons.vibration_rounded, color: AppTheme.flameAmber),
                  title: const Text(
                    'Vibración forzada',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Vibra en bucle a máxima amplitud junto con Critical Alerts hasta descartar el SOS.',
                    style: TextStyle(fontSize: 12.5, color: Colors.white60),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddressBookPickerSheet extends StatefulWidget {
  const _AddressBookPickerSheet({required this.contacts});

  final List<EmergencyContact> contacts;

  @override
  State<_AddressBookPickerSheet> createState() => _AddressBookPickerSheetState();
}

class _AddressBookPickerSheetState extends State<_AddressBookPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.contacts.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.displayName.toLowerCase().contains(q) || c.rawPhone.contains(q);
    }).toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar nombre o teléfono en agenda...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No se encontraron contactos con número válido.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.backgroundObsidian,
                              child: Text(item.displayName.characters.first.toUpperCase()),
                            ),
                            title: Text(item.displayName),
                            subtitle: Text(item.rawPhone),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
