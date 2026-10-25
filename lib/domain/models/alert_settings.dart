/// Tonos de alerta disponibles para notificaciones críticas en Android (res/raw) e iOS (.caf).
enum AlertTone {
  flamingBell(
    id: 'flaming_bell',
    label: 'Campana en Llamas (SOS Principal)',
    androidRawResource: 'flaming_bell',
    iosSoundFile: 'flaming_bell.caf',
  ),
  tacticalSiren(
    id: 'tactical_siren',
    label: 'Sirena Táctica de Alta Frecuencia',
    androidRawResource: 'tactical_siren',
    iosSoundFile: 'tactical_siren.caf',
  ),
  pulseBeacon(
    id: 'pulse_beacon',
    label: 'Pulso Sonar Intermitente',
    androidRawResource: 'pulse_beacon',
    iosSoundFile: 'pulse_beacon.caf',
  ),
  continuousAlarm(
    id: 'continuous_alarm',
    label: 'Alarma Industrial Continua',
    androidRawResource: 'continuous_alarm',
    iosSoundFile: 'continuous_alarm.caf',
  );

  const AlertTone({
    required this.id,
    required this.label,
    required this.androidRawResource,
    required this.iosSoundFile,
  });

  final String id;
  final String label;
  final String androidRawResource;
  final String iosSoundFile;

  static AlertTone fromId(String? id) {
    for (final tone in AlertTone.values) {
      if (tone.id == id) return tone;
    }
    return AlertTone.flamingBell;
  }
}

/// Preferencias locales de alerta del usuario receptor.
class AlertSettings {
  const AlertSettings({
    this.selectedTone = AlertTone.flamingBell,
    this.forcedVibration = true,
  });

  final AlertTone selectedTone;
  final bool forcedVibration;

  AlertSettings copyWith({
    AlertTone? selectedTone,
    bool? forcedVibration,
  }) {
    return AlertSettings(
      selectedTone: selectedTone ?? this.selectedTone,
      forcedVibration: forcedVibration ?? this.forcedVibration,
    );
  }
}
