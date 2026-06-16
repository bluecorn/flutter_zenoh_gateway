import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenoh_ros_poc/data/models/serialization_format.dart';

/// Persists the app settings — the Zenoh endpoint and the serialization
/// format — over [SharedPreferences].
///
/// Plain Dart only — no `package:zenoh`. The connection view model loads the
/// endpoint at startup (defaulting to [defaultEndpoint] when none is saved)
/// and saves it back when the user changes it.
class SettingsRepository {
  /// Creates a repository backed by the given [SharedPreferences].
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _endpointKey = 'connect_endpoint';
  static const String _formatKey = 'serialization_format';

  /// The endpoint used when nothing has been persisted yet.
  static const String defaultEndpoint = 'tcp/localhost:7447';

  /// Loads the saved endpoint, or [defaultEndpoint] if none is stored.
  ///
  /// [SharedPreferences] reads are synchronous, so this is sync — no
  /// decorative `Future` (saves stay `Future`: writes really are async).
  String loadEndpoint() {
    return _prefs.getString(_endpointKey) ?? defaultEndpoint;
  }

  /// Persists [endpoint] as the endpoint to connect to.
  Future<void> saveEndpoint(String endpoint) async {
    await _prefs.setString(_endpointKey, endpoint);
  }

  /// Loads the saved serialization format, defaulting to
  /// [SerializationFormat.json] when nothing is stored — or when the stored
  /// string is unknown (e.g. written by a newer app version): never throws.
  SerializationFormat loadFormat() {
    final stored = _prefs.getString(_formatKey);
    return SerializationFormat.values.firstWhere(
      (format) => format.wireName == stored,
      orElse: () => SerializationFormat.json,
    );
  }

  /// Persists [format] (as its `wireName`) as the serialization format.
  Future<void> saveFormat(SerializationFormat format) async {
    await _prefs.setString(_formatKey, format.wireName);
  }
}
