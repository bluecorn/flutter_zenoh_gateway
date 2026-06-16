import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenoh_ros_poc/data/codecs/message_codec.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';

void main() {
  group('JsonMessageCodec', () {
    test('T1 — home encodes to the contract bytes', () {
      final bytes = const JsonMessageCodec().encodePose(PoseCommand.home);
      expect(bytes, utf8.encode('{"pose":"home"}'));
    });

    test('T2 — sleep encodes to the contract bytes', () {
      final bytes = const JsonMessageCodec().encodePose(PoseCommand.sleep);
      expect(bytes, utf8.encode('{"pose":"sleep"}'));
    });

    test('T3 — codec is assignable to the MessageCodec seam interface', () {
      const MessageCodec codec = JsonMessageCodec();
      expect(
        codec.encodePose(PoseCommand.home),
        utf8.encode('{"pose":"home"}'),
      );
      expect(
        codec.encodePose(PoseCommand.sleep),
        utf8.encode('{"pose":"sleep"}'),
      );
    });

    test('T4 (edge) — round-trip guards quoting/escaping for every pose', () {
      const codec = JsonMessageCodec();
      for (final pose in PoseCommand.values) {
        final decoded = jsonDecode(utf8.decode(codec.encodePose(pose)));
        expect(decoded, isA<Map<String, dynamic>>());
        final map = decoded as Map<String, dynamic>;
        expect(map.keys, ['pose']);
        expect(map['pose'], pose.wireName);
      }
    });
  });

  group('JsonMessageCodec.decodeAck', () {
    const codec = JsonMessageCodec();

    test('T1 — decodes an ok ack', () {
      final ack = codec.decodeAck(
        Uint8List.fromList(utf8.encode('{"ok":true}')),
      );
      expect(ack, isNotNull);
      expect(ack!.ok, isTrue);
      expect(ack.error, isNull);
      expect(ack.detail, isNull);
    });

    test('T2 — decodes a business reject ack', () {
      final ack = codec.decodeAck(
        Uint8List.fromList(
          utf8.encode('{"ok":false,"error":"unknown_pose","detail":"banana"}'),
        ),
      );
      expect(ack, isNotNull);
      expect(ack!.ok, isFalse);
      expect(ack.error, 'unknown_pose');
      expect(ack.detail, 'banana');
    });

    test('T3 (edge) — malformed bytes never throw, return null', () {
      expect(
        () => codec.decodeAck(Uint8List.fromList(utf8.encode('not json'))),
        returnsNormally,
      );
      expect(
        codec.decodeAck(Uint8List.fromList(utf8.encode('not json'))),
        isNull,
      );
    });

    test('T4 (edge) — empty bytes never throw, return null', () {
      expect(() => codec.decodeAck(Uint8List(0)), returnsNormally);
      expect(codec.decodeAck(Uint8List(0)), isNull);
    });

    test('T5 (edge) — JSON missing ok field never throws, returns null', () {
      expect(
        () => codec.decodeAck(Uint8List.fromList(utf8.encode('{"error":"x"}'))),
        returnsNormally,
      );
      expect(
        codec.decodeAck(Uint8List.fromList(utf8.encode('{"error":"x"}'))),
        isNull,
      );
    });
  });
}
