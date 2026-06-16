import 'package:flutter_test/flutter_test.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';

/// P1 Slice 6 — [PoseCommand] is a pure enum: only `wireName` remains.
/// `jsonPayload` is gone (never referenced here); the wire payload assertions
/// live in `test/data/codecs/message_codec_test.dart` since Slice 5.
void main() {
  group('PoseCommand', () {
    test('T4 — pure enum exposes its lowercase wire names', () {
      expect(PoseCommand.home.wireName, 'home');
      expect(PoseCommand.sleep.wireName, 'sleep');
    });

    test('T4b — every value wires as its lowercase enum name', () {
      for (final pose in PoseCommand.values) {
        expect(pose.wireName, pose.name);
      }
    });
  });
}
