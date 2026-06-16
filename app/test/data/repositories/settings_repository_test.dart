import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/data/models/serialization_format.dart';
import 'package:zenoh_ros_poc/data/repositories/settings_repository.dart';

void main() {
  group('SettingsRepository format setting', () {
    test('T2 — defaults to json with empty storage', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      expect(repository.loadFormat(), SerializationFormat.json);
    });

    test('T3 — round-trips through persistence as the wire name', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await SettingsRepository(prefs).saveFormat(SerializationFormat.protobuf);

      // A fresh repository over the same storage reads it back.
      final fresh = SettingsRepository(prefs);
      expect(fresh.loadFormat(), SerializationFormat.protobuf);

      // The stored preference string is the wire name, not the enum name.
      expect(prefs.getString('serialization_format'), 'proto');
    });

    test('T7 (edge) — unknown stored format falls back to json '
        'without throwing', () async {
      SharedPreferences.setMockInitialValues({'serialization_format': 'xml'});
      final repository = SettingsRepository(
        await SharedPreferences.getInstance(),
      );

      expect(repository.loadFormat(), SerializationFormat.json);
    });
  });
}
