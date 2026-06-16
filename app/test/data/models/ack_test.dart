import 'package:flutter_test/flutter_test.dart';
import 'package:zenoh_ros_poc/data/models/ack.dart';

/// Slice 5 — [Ack] is a pure Dart value type mirroring the gateway ack
/// contract shape. No zenoh, no JSON; the codec (Slice 6) constructs it and
/// the repository/VM (Slices 7–8) read its fields.
void main() {
  group('Ack', () {
    test('ok ack holds ok=true and no error', () {
      const ack = Ack(ok: true);

      expect(ack.ok, isTrue);
      expect(ack.error, isNull);
      expect(ack.detail, isNull);
    });

    test('reject ack holds ok=false and the reason', () {
      const ack = Ack(ok: false, error: 'unknown_pose', detail: 'banana');

      expect(ack.ok, isFalse);
      expect(ack.error, 'unknown_pose');
      expect(ack.detail, 'banana');
    });
  });
}
