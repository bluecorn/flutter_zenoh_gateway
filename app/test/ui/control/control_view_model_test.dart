import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/data/models/ack.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/control/control_view_model.dart';

import '../../helpers/fakes.dart';

void main() {
  /// Builds a container over [repository], optionally connected via the
  /// connection VM (so the control VM sees the connected status).
  Future<ProviderContainer> makeContainer(
    FakeRobotRepository repository, {
    required bool connected,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        robotRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    if (connected) {
      await container
          .read(connectionViewModelProvider.notifier)
          .connect('tcp/robot:7447');
    }
    return container;
  }

  group('ControlViewModel', () {
    test(
      'T5 — poses forward through the repository in order when connected',
      () async {
        final repository = FakeRobotRepository();
        final container = await makeContainer(repository, connected: true);
        final vm = container.read(controlViewModelProvider.notifier);

        // Await each send so the first completes before the next is issued
        // (decision 4 ignores a 2nd tap while a send is in flight).
        await vm.sendPose(PoseCommand.home);
        await vm.sendPose(PoseCommand.sleep);

        expect(repository.sentPoses, [PoseCommand.home, PoseCommand.sleep]);
      },
    );

    test('T1 — ok ack maps to delivered (sending → delivered)', () async {
      final repository = FakeRobotRepository()
        ..sendPoseAck = const Ack(ok: true);
      final container = await makeContainer(repository, connected: true);
      final vm = container.read(controlViewModelProvider.notifier);

      // Mid-flight (synchronously after invoking, before the await settles)
      // the result is sending.
      final future = vm.sendPose(PoseCommand.home);
      expect(
        container.read(controlViewModelProvider).result,
        isA<SendingResult>(),
      );

      await future;

      expect(
        container.read(controlViewModelProvider).result,
        isA<DeliveredResult>(),
      );
      expect(repository.sentPoses, [PoseCommand.home]);
    });

    test('T2 — business reject maps to rejected:<reason>', () async {
      final repository = FakeRobotRepository()
        ..sendPoseAck = const Ack(ok: false, error: 'unknown_pose');
      final container = await makeContainer(repository, connected: true);
      final vm = container.read(controlViewModelProvider.notifier);

      await vm.sendPose(PoseCommand.home);

      final result = container.read(controlViewModelProvider).result;
      expect(result, isA<RejectedResult>());
      expect((result as RejectedResult).reason, 'unknown_pose');
    });

    test('T3 — any thrown transport-error maps to error (one catch '
        'path)', () async {
      final repository = FakeRobotRepository()
        ..sendPoseError = StateError('query timeout');
      final container = await makeContainer(repository, connected: true);
      final vm = container.read(controlViewModelProvider.notifier);

      // Must not throw out of sendPose — the catch path absorbs it.
      await vm.sendPose(PoseCommand.home);

      expect(
        container.read(controlViewModelProvider).result,
        isA<ErrorResult>(),
      );
    });

    test(
      'T6 — gated when disconnected: no repository call, canSend false',
      () async {
        final repository = FakeRobotRepository();
        final container = await makeContainer(repository, connected: false);

        await container
            .read(controlViewModelProvider.notifier)
            .sendPose(PoseCommand.home);

        expect(repository.sentPoses, isEmpty);
        expect(container.read(controlViewModelProvider).canSend, isFalse);
      },
    );

    test('T7 — in-flight tap ignored (decision 4): exactly one query for '
        'the first', () async {
      final repository = FakeRobotRepository();
      final container = await makeContainer(repository, connected: true);
      final vm = container.read(controlViewModelProvider.notifier);

      // First send is in flight (result == sending) when the 2nd is invoked.
      final first = vm.sendPose(PoseCommand.home);
      expect(
        container.read(controlViewModelProvider).result,
        isA<SendingResult>(),
      );

      // Second tap before the first settles — a no-op.
      await vm.sendPose(PoseCommand.sleep);
      await first;

      expect(repository.sentPoses, [PoseCommand.home]);
    });
  });
}
