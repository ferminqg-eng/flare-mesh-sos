import 'dart:typed_data';

import 'package:flare_mesh_sos/data/services/mesh_packet_codec.dart';
import 'package:flare_mesh_sos/domain/models/emergency_packet.dart';
import 'package:flare_mesh_sos/domain/models/emergency_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeshPacketCodec (20-Byte Strict Authenticated Binary Protocol)', () {
    test('serializes and deserializes exact 20-byte payload with authTag without Strings', () {
      final authTag = MeshPacketCodec.computeAuthTag(
        senderPhone: 584125550199,
        emergencyCode: EmergencyType.robberyTrackMe.code,
        messageId: 173,
        verificationPin: '4321',
      );

      final original = EmergencyPacket(
        senderPhone: 584125550199,
        latitude: 10.4806,
        longitude: -66.9036,
        emergencyCode: EmergencyType.robberyTrackMe.code,
        messageId: 173,
        authTag: authTag,
      );

      final Uint8List encoded = MeshPacketCodec.encode(original);

      // Verificación estricta de tamaño de trama (20 bytes útiles <= 31 bytes límite PDU)
      expect(encoded.length, equals(20));

      final EmergencyPacket? decoded = MeshPacketCodec.tryDecode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.senderPhone, equals(584125550199));
      // Precisión float32 (~1e-4 grados -> ~1.1 metros)
      expect(decoded.latitude, closeTo(10.4806, 1e-4));
      expect(decoded.longitude, closeTo(-66.9036, 1e-4));
      expect(decoded.emergencyCode, equals(EmergencyType.robberyTrackMe.code));
      expect(decoded.messageId, equals(173));
      expect(decoded.authTag, equals(authTag));
    });

    test('rejects corrupted or wrong-length buffers', () {
      expect(MeshPacketCodec.tryDecode(Uint8List(18)), isNull);
      expect(MeshPacketCodec.tryDecode(Uint8List(19)), isNull);
      expect(MeshPacketCodec.tryDecode(Uint8List(21)), isNull);
    });

    test('verifies authTag matches when using identical PIN', () {
      final tag1 = MeshPacketCodec.computeAuthTag(
        senderPhone: 584141234567,
        emergencyCode: 1,
        messageId: 42,
        verificationPin: '8899',
      );
      final tag2 = MeshPacketCodec.computeAuthTag(
        senderPhone: 584141234567,
        emergencyCode: 1,
        messageId: 42,
        verificationPin: '8899',
      );
      final tagWrongPin = MeshPacketCodec.computeAuthTag(
        senderPhone: 584141234567,
        emergencyCode: 1,
        messageId: 42,
        verificationPin: '0000',
      );

      expect(tag1, equals(tag2));
      expect(tag1, isNot(equals(tagWrongPin)));
    });
  });
}
