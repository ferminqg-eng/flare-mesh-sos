import 'emergency_type.dart';

/// Modelo de dominio inmutable que representa el paquete binario de 18 bytes
/// que viaja por la red colaborativa BLE Mesh y la pasarela oportunista GPRS.
class EmergencyPacket {
  const EmergencyPacket({
    required this.senderPhone,
    required this.latitude,
    required this.longitude,
    required this.emergencyCode,
    required this.messageId,
  });

  /// ID único del emisor en la red (uint64: 8 bytes, solo dígitos E.164).
  final int senderPhone;

  /// Latitud GPS codificada como IEEE 754 float32 (4 bytes, precisión ~1.1 m).
  final double latitude;

  /// Longitud GPS codificada como IEEE 754 float32 (4 bytes, precisión ~1.1 m).
  final double longitude;

  /// Código de emergencia (uint8: 1 byte, valores 1..4).
  final int emergencyCode;

  /// Identificador secuencial/pseudoaleatorio del mensaje (uint8: 1 byte, 0..255).
  final int messageId;

  EmergencyType get emergencyType => EmergencyType.fromCode(emergencyCode);

  /// Clave compuesta en memoria RAM para evitar tormentas de retransmisión (Broadcast Storms).
  String get deduplicationKey => '$senderPhone:$messageId';

  Map<String, dynamic> toIsolateMap() => <String, dynamic>{
        'senderPhone': senderPhone,
        'latitude': latitude,
        'longitude': longitude,
        'emergencyCode': emergencyCode,
        'messageId': messageId,
      };

  factory EmergencyPacket.fromIsolateMap(Map<String, dynamic> map) {
    return EmergencyPacket(
      senderPhone: (map['senderPhone'] as num).toInt(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      emergencyCode: (map['emergencyCode'] as num).toInt(),
      messageId: (map['messageId'] as num).toInt(),
    );
  }
}
