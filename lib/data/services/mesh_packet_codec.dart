import 'dart:typed_data';

import '../../domain/models/emergency_packet.dart';

/// Codificador/Decodificador binario estricto de 18 bytes para BLE Mesh y GPRS.
///
/// Distribución exacta en memoria (Big-Endian / Network Byte Order):
/// ┌──────────────┬───────────────┬──────────────┬───────────┬────────────┐
/// │ Bytes 0..7   │ Bytes 8..11   │ Bytes 12..15 │ Byte 16   │ Byte 17    │
/// │ uint64 (8 B) │ float32 (4 B) │ float32 (4 B)│ uint8(1 B)│ uint8 (1 B)│
/// │ Teléfono ID  │ Latitud GPS   │ Longitud GPS │ Cód. SOS  │ ID Mensaje │
/// └──────────────┴───────────────┴──────────────┴───────────┴────────────┘
/// Total = 18 bytes exactos (Cabe holgadamente en los 31 bytes del PDU BLE 4.0 Legacy).
class MeshPacketCodec {
  const MeshPacketCodec._();

  /// Tamaño fijo inmutable del payload útil.
  static const int payloadByteLength = 18;

  /// UUID de servicio de 16 bits expandido (0xFD99) requerido por iOS CoreBluetooth
  /// para permitir el escaneo BLE en segundo plano (`bluetooth-central`).
  static const String meshServiceUuid = '0000fd99-0000-1000-8000-00805f9b34fb';

  /// Company Identifier reservado para pruebas/uso privado en Manufacturer Specific Data (0xFF45).
  static const int meshManufacturerId = 0xFF45;

  /// Offsets binarios exactos.
  static const int _phoneOffset = 0; // 8 bytes (0..7)
  static const int _latOffset = 8; // 4 bytes (8..11)
  static const int _lngOffset = 12; // 4 bytes (12..15)
  static const int _codeOffset = 16; // 1 byte  (16)
  static const int _msgIdOffset = 17; // 1 byte  (17)

  /// Serializa un [EmergencyPacket] en un [Uint8List] de exactamente 18 bytes sin usar Strings.
  static Uint8List encode(EmergencyPacket packet) {
    if (packet.senderPhone < 0) {
      throw ArgumentError.value(
        packet.senderPhone,
        'senderPhone',
        'El teléfono debe ser un entero positivo válido para uint64.',
      );
    }

    final byteData = ByteData(payloadByteLength);

    // 1. Teléfono emisor -> 8 bytes uint64
    byteData.setUint64(_phoneOffset, packet.senderPhone, Endian.big);

    // 2. Latitud -> 4 bytes IEEE 754 float32
    byteData.setFloat32(_latOffset, packet.latitude, Endian.big);

    // 3. Longitud -> 4 bytes IEEE 754 float32
    byteData.setFloat32(_lngOffset, packet.longitude, Endian.big);

    // 4. Código de emergencia -> 1 byte uint8 (máscara 0xFF)
    byteData.setUint8(_codeOffset, packet.emergencyCode & 0xFF);

    // 5. ID de mensaje -> 1 byte uint8 (máscara 0xFF: 0..255)
    byteData.setUint8(_msgIdOffset, packet.messageId & 0xFF);

    final bytes = byteData.buffer.asUint8List();
    assert(bytes.length == payloadByteLength, 'El payload debe medir exactamente 18 bytes');
    return bytes;
  }

  /// Deserializa un [Uint8List] de 18 bytes en un [EmergencyPacket].
  /// Retorna `null` si el tamaño es distinto de 18 bytes o las coordenadas están corruptas.
  static EmergencyPacket? tryDecode(Uint8List rawBytes) {
    if (rawBytes.length != payloadByteLength) {
      return null;
    }

    // Usamos sublistView para respetar offsetInBytes si rawBytes proviene de un slice mayor.
    final byteData = ByteData.sublistView(rawBytes);

    final senderPhone = byteData.getUint64(_phoneOffset, Endian.big);
    final latitude = byteData.getFloat32(_latOffset, Endian.big);
    final longitude = byteData.getFloat32(_lngOffset, Endian.big);
    final emergencyCode = byteData.getUint8(_codeOffset);
    final messageId = byteData.getUint8(_msgIdOffset);

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
    );
  }
}
