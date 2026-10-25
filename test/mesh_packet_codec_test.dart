import 'dart:typed_data';

import 'package:flare_mesh_sos/data/services/mesh_packet_codec.dart';
import 'package:flare_mesh_sos/domain/models/emergency_packet.dart';
import 'package:flare_mesh_sos/domain/models/emergency_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeshPacketCodec (18-Byte Strict Binary Protocol)', () {
    test('serializes and deserializes exact 18-byte payload without Strings', () {
      const original = EmergencyPacket(
        senderPhone: 584125550199,
        latitude: 10.4806,
        longitude: -66.9036,
        emergencyCode: 4, // Me robaron, encuéntrame
        messageId: 173,
      );

      final Uint8List encoded = MeshPacketCodec.encode(original);

      // Verificación estricta de tamaño de trama
      expect(encoded.length, equals(18));

      final EmergencyPacket? decoded = MeshPacketCodec.tryDecode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.senderPhone, equals(584125550199));
      // Precisión float32 (~1e-4 grados -> ~1.1 metros)
      expect(decoded.latitude, closeTo(10.4806, 1e-4));
      expect(decoded.longitude, closeTo(-66.9036, 1e-4));
      expect(decoded.emergencyCode, equals(EmergencyType.robberyTrackMe.code));
      expect(decoded.messageId, equals(173));
    });

    test('rejects corrupted or wrong-length buffers', () {
      expect(MeshPacketCodec.tryDecode(Uint8List(17)), isNull);
      expect(MeshPacketCodec.tryDecode(Uint8List(19)), isNull);
    });
  });
}
