import 'emergency_type.dart';

/// Modelo de dominio inmutable del paquete binario autenticado de 20 bytes
/// para la red Mesh BLE y pasarela GPRS.
class EmergencyPacket {
  const EmergencyPacket({
    required this.senderPhone,
    required this.latitude,
    required this.longitude,
    required this.emergencyCode,
    required this.messageId,
    this.authTag = 0,
  });

  /// ID único del emisor en la red (uint64: 8 bytes, solo dígitos E.164).
  final int senderPhone;

  /// Latitud GPS codificada como IEEE 754 float32 (4 bytes).
  final double latitude;

  /// Longitud GPS codificada como IEEE 754 float32 (4 bytes).
  final double longitude;

  /// Código de emergencia (uint8: 1 byte, 0 = Ping de prueba, 1..4 = Emergencias).
  final int emergencyCode;

  /// Identificador secuencial/pseudoaleatorio del mensaje (uint8: 1 byte, 0..255).
  final int messageId;

  /// Token criptográfico de verificación anti-usurpación (uint16: 2 bytes).
  final int authTag;

  EmergencyType get emergencyType => EmergencyType.fromCode(emergencyCode);

  bool get isTestPing => emergencyCode == EmergencyType.testPing.code;

  /// Clave compuesta en memoria RAM para deduplicación.
  String get deduplicationKey => '$senderPhone:$messageId';

  Map<String, dynamic> toIsolateMap() => <String, dynamic>{
        'senderPhone': senderPhone,
        'latitude': latitude,
        'longitude': longitude,
        'emergencyCode': emergencyCode,
        'messageId': messageId,
        'authTag': authTag,
      };

  factory EmergencyPacket.fromIsolateMap(Map<String, dynamic> map) {
    return EmergencyPacket(
      senderPhone: (map['senderPhone'] as num).toInt(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      emergencyCode: (map['emergencyCode'] as num).toInt(),
      messageId: (map['messageId'] as num).toInt(),
      authTag: ((map['authTag'] as num?) ?? 0).toInt(),
    );
  }
}
