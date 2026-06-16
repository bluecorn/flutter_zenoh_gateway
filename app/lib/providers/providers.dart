import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenoh_ros_poc/data/codecs/message_codec.dart';
import 'package:zenoh_ros_poc/data/models/serialization_format.dart';
import 'package:zenoh_ros_poc/data/repositories/robot_repository.dart';
import 'package:zenoh_ros_poc/data/repositories/settings_repository.dart';
import 'package:zenoh_ros_poc/data/services/zenoh_service.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';
import 'package:zenoh_ros_poc/ui/control/control_view_model.dart';

// --- Infrastructure ---

/// Provides [SharedPreferences]. Must be overridden in `main()` (and in tests
/// via `SharedPreferences.setMockInitialValues`).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

/// Creates and owns the single [ZenohService] (the `package:zenoh` boundary),
/// disposing it on teardown. Overridden with a fake in view-model tests.
final zenohServiceProvider = Provider<ZenohService>((ref) {
  final service = ZenohService();
  ref.onDispose(service.dispose);
  return service;
});

// --- Repositories ---

/// Robot command boundary over the (mockable) [ZenohService] — the layer
/// the ViewModels talk to (and the override point in widget tests). Watches
/// the service AND the codec separately, so a format switch rebuilds this
/// stateless repository without ever touching the session (design doc §4.3).
final robotRepositoryProvider = Provider<RobotRepository>((ref) {
  return RobotRepositoryImpl(
    ref.watch(zenohServiceProvider),
    ref.watch(messageCodecProvider),
  );
});

/// Settings persistence backed by [SharedPreferences].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

// --- Serialization format ---

/// Holds the selected [SerializationFormat], loaded from and persisted via
/// the [SettingsRepository]. No UI reads this yet — the selector ships at P2.
final serializationFormatProvider =
    NotifierProvider<SerializationFormatNotifier, SerializationFormat>(
      SerializationFormatNotifier.new,
    );

/// Notifier behind [serializationFormatProvider]: sync load on build,
/// persist-then-update on [setFormat].
class SerializationFormatNotifier extends Notifier<SerializationFormat> {
  @override
  SerializationFormat build() =>
      ref.watch(settingsRepositoryProvider).loadFormat();

  /// Persists [format] and updates the state.
  Future<void> setFormat(SerializationFormat format) async {
    await ref.read(settingsRepositoryProvider).saveFormat(format);
    state = format;
  }
}

/// Resolves the [MessageCodec] for the selected format. Protobuf and
/// FlatBuffers are explicit P2/P3 placeholders — never a silent fallback.
final messageCodecProvider = Provider<MessageCodec>((ref) {
  switch (ref.watch(serializationFormatProvider)) {
    case SerializationFormat.json:
      return const JsonMessageCodec();
    case SerializationFormat.protobuf:
      throw UnsupportedError('Protobuf codec not implemented until P2');
    case SerializationFormat.flatbuffers:
      throw UnsupportedError('FlatBuffers codec not implemented until P3');
  }
});

// --- ViewModels ---

/// Connection lifecycle view model.
final connectionViewModelProvider =
    NotifierProvider<ConnectionViewModel, ConnectionState>(
      ConnectionViewModel.new,
    );

/// Pose-command view model, gated on the connection status.
final controlViewModelProvider =
    NotifierProvider<ControlViewModel, ControlState>(ControlViewModel.new);
