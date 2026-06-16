import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/data/repositories/robot_repository.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';

import '../../helpers/fakes.dart';

void main() {
  /// Builds a container over the given repository fake and freshly-read
  /// mocked prefs (call `SharedPreferences.setMockInitialValues` first).
  Future<ProviderContainer> makeContainer(RobotRepository repository) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        robotRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ConnectionViewModel', () {
    test('T1 — sync build yields the persisted-default state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer(FakeRobotRepository());

      // Plain sync read — no `.future`, no AsyncValue unwrap.
      final state = container.read(connectionViewModelProvider);

      expect(state.endpoint, 'tcp/localhost:7447');
      expect(state.status, ConnectionStatus.disconnected);
    });

    test('T2 — endpoint persists across a fresh container', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer(FakeRobotRepository());
      await container
          .read(connectionViewModelProvider.notifier)
          .setEndpoint('tcp/robot:7447');

      // A fresh container over the same mocked storage reads it back.
      final freshContainer = await makeContainer(FakeRobotRepository());
      final reloaded = freshContainer.read(connectionViewModelProvider);

      expect(reloaded.endpoint, 'tcp/robot:7447');
    });

    test(
      'T3 — connect goes through the repository and transitions to connected',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repository = FakeRobotRepository();
        final container = await makeContainer(repository);

        await container
            .read(connectionViewModelProvider.notifier)
            .connect('tcp/robot:7447');

        final state = container.read(connectionViewModelProvider);
        expect(repository.connectCalls, ['tcp/robot:7447']);
        expect(state.status, ConnectionStatus.connected);
        expect(state.endpoint, 'tcp/robot:7447');

        // The endpoint was persisted: a fresh container reads it back.
        final freshContainer = await makeContainer(FakeRobotRepository());
        expect(
          freshContainer.read(connectionViewModelProvider).endpoint,
          'tcp/robot:7447',
        );
      },
    );

    test('T4 — disconnect drives disconnected via the repository', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeRobotRepository();
      final container = await makeContainer(repository);
      final vm = container.read(connectionViewModelProvider.notifier);
      await vm.connect('tcp/robot:7447');

      vm.disconnect();

      expect(repository.disconnectCalls, 1);
      expect(
        container.read(connectionViewModelProvider).status,
        ConnectionStatus.disconnected,
      );
    });

    test('T8 (edge) — failed connect transitions to error with a message, '
        'no command issuable', () async {
      SharedPreferences.setMockInitialValues({});
      final container = await makeContainer(ThrowingFakeRobotRepository());

      await container
          .read(connectionViewModelProvider.notifier)
          .connect('tcp/robot:7447');

      final state = container.read(connectionViewModelProvider);
      expect(state.status, ConnectionStatus.error);
      expect(state.error, isNotNull);
      expect(container.read(controlViewModelProvider).canSend, isFalse);
    });
  });
}
