/// Códigos de emergencia transmitidos en el payload binario BLE/GPRS.
enum EmergencyType {
  testPing(
    code: 0,
    title: 'Prueba de Enlace Mesh',
    shortTag: 'PING MESH',
    description: 'Pulso de prueba para verificar conectividad y señal con nodos cercanos.',
  ),
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
