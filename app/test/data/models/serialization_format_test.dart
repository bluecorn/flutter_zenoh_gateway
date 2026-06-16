import 'package:flutter_test/flutter_test.dart';
import 'package:zenoh_ros_poc/data/models/serialization_format.dart';

void main() {
  group('SerializationFormat', () {
    test('T1 — wire names are json / proto / fb', () {
      expect(SerializationFormat.json.wireName, 'json');
      expect(SerializationFormat.protobuf.wireName, 'proto');
      expect(SerializationFormat.flatbuffers.wireName, 'fb');
    });
  });
}
