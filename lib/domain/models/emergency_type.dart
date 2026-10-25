/// Códigos de emergencia de 1 byte (uint8) transmitidos en el payload binario BLE/GPRS.
/// Jamás se envían Strings por aire; la traducción ocurre localmente en el receptor.
enum EmergencyType {
  urgentHelp(
    code: 1,
    title: 'Ayúdame Urgente',
    shortTag: 'SOS CRÍTICO',
    description: 'Solicita asistencia inmediata en las coordenadas indicadas.',
  ),
  outOfCredit(
    code: 2,
    title: 'Me quedé sin Saldo, Recárgame',
    shortTag: 'SIN SALDO',
    description: 'Sin datos ni saldo móvil; solicita recarga o llamada entrante.',
  ),
  carBreakdown(
    code: 3,
    title: 'Carro dañado en vía',
    shortTag: 'AVERÍA VIAL',
    description: 'Vehículo inmovilizado en ruta sin cobertura; requiere auxilio vial.',
  ),
  robberyTrackMe(
    code: 4,
    title: 'Me robaron, encuéntrame',
    shortTag: 'ROBO / RASTREO',
    description: 'Alerta de seguridad crítica; rastrea las últimas coordenadas emitidas.',
  );

  const EmergencyType({
    required this.code,
    required this.title,
    required this.shortTag,
    required this.description,
  });

  /// Valor uint8 (1..4) codificado en el byte 16 del paquete de 18 bytes.
  final int code;
  final String title;
  final String shortTag;
  final String description;

  static EmergencyType fromCode(int code) {
    for (final type in EmergencyType.values) {
      if (type.code == code) return type;
    }
    return EmergencyType.urgentHelp;
  }
}
