import 'dart:typed_data';

import '../../domain/models/emergency_packet.dart';

/// Codificador/Decodificador binario estricto de 20 bytes autenticados para BLE Mesh.
///
/// Distribución exacta en memoria (Big-Endian):
/// ┌──────────────┬───────────────┬──────────────┬───────────┬────────────┬─────────────┐
/// │ Bytes 0..7   │ Bytes 8..11   │ Bytes 12..15 │ Byte 16   │ Byte 17    │ Bytes 18..19│
/// │ uint64 (8 B) │ float32 (4 B) │ float32 (4 B)│ uint8(1 B)│ uint8 (1 B)│ uint16(2 B) │
/// │ Teléfono ID  │ Latitud GPS   │ Longitud GPS │ Cód. SOS  │ ID Mensaje │ Auth Tag MAC│
/// └──────────────┴───────────────┴──────────────┴───────────┴────────────┴─────────────┘
/// Total = 20 bytes útiles + 4 bytes header Manufacturer Data = 24 bytes <= 31 bytes PDU.
class MeshPacketCodec {
  const MeshPacketCodec._();

  static const int payloadByteLength = 20;
  static const int meshManufacturerId = 0xFF45;

  static const int _phoneOffset = 0; // 8 bytes (0..7)
  static const int _latOffset = 8; // 4 bytes (8..11)
  static const int _lngOffset = 12; // 4 bytes (12..15)
  static const int _codeOffset = 16; // 1 byte  (16)
  static const int _msgIdOffset = 17; // 1 byte  (17)
  static const int _authTagOffset = 18; // 2 bytes (18..19)

  /// Calcula un tag de autenticación (MAC de 16 bits) a partir del PIN acordado.
  static int computeAuthTag({
    required int senderPhone,
    required int emergencyCode,
    required int messageId,
    required String verificationPin,
  }) {
    final pinInt = int.tryParse(verificationPin) ?? 1234;
    var hash = 0x811C;
    hash = (hash ^ (senderPhone & 0xFFFF)) * 0x0103;
    hash = (hash ^ ((senderPhone >> 16) & 0xFFFF)) * 0x0103;
    hash = (hash ^ emergencyCode) * 0x0103;
    hash = (hash ^ messageId) * 0x0103;
    hash = (hash ^ pinInt) * 0x0103;
    return hash & 0xFFFF;
  }

  /// Serializa un [EmergencyPacket] en un [Uint8List] de exactamente 20 bytes.
  static Uint8List encode(EmergencyPacket packet) {
    if (packet.senderPhone < 0) {
      throw ArgumentError.value(
        packet.senderPhone,
        'senderPhone',
        'El teléfono debe ser un entero positivo válido para uint64.',
      );
    }

    final byteData = ByteData(payloadByteLength);

    byteData.setUint64(_phoneOffset, packet.senderPhone, Endian.big);
    byteData.setFloat32(_latOffset, packet.latitude, Endian.big);
    byteData.setFloat32(_lngOffset, packet.longitude, Endian.big);
    byteData.setUint8(_codeOffset, packet.emergencyCode & 0xFF);
    byteData.setUint8(_msgIdOffset, packet.messageId & 0xFF);
    byteData.setUint16(_authTagOffset, packet.authTag & 0xFFFF, Endian.big);

    final bytes = byteData.buffer.asUint8List();
    assert(bytes.length == payloadByteLength, 'El payload debe medir exactamente 20 bytes');
    return bytes;
  }

  /// Deserializa un [Uint8List] de 20 bytes en un [EmergencyPacket].
  static EmergencyPacket? tryDecode(Uint8List rawBytes) {
    if (rawBytes.length != payloadByteLength) {
      return null;
    }

    final byteData = ByteData.sublistView(rawBytes);

    final senderPhone = byteData.getUint64(_phoneOffset, Endian.big);
    final latitude = byteData.getFloat32(_latOffset, Endian.big);
    final longitude = byteData.getFloat32(_lngOffset, Endian.big);
    final emergencyCode = byteData.getUint8(_codeOffset);
    final messageId = byteData.getUint8(_msgIdOffset);
    final authTag = byteData.getUint16(_authTagOffset, Endian.big);

    if (senderPhone <= 0 ||
        latitude.isNaN ||
        longitude.isNaN ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {
      return null;
    }

    return EmergencyPacket(
      senderPhone: senderPhone,
      latitude: latitude,
      longitude: longitude,
      emergencyCode: emergencyCode,
      messageId: messageId,
      authTag: authTag,
    );
  }
}
