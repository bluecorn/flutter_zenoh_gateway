import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/data/models/ack.dart';
import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/data/repositories/robot_repository.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/control/control_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  /// Builds a [ProviderScope] wrapping [ControlScreen] with [repository]
  /// injected, then drives the connection VM into the requested condition.
  ///
  /// - [connect] true over a [FakeRobotRepository] → connected.
  /// - [connect] true over a [ThrowingFakeRobotRepository] → error.
  /// - [connect] false → disconnected (the default after build()).
  Future<void> pumpScreen(
    WidgetTester tester,
    RobotRepository repository, {
    required bool connect,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          robotRepositoryProvider.overrideWithValue(repository),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const MaterialApp(home: ControlScreen());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (connect) {
      await container
          .read(connectionViewModelProvider.notifier)
          .connect('tcp/localhost:7447');
    }
    await tester.pumpAndSettle();
  }

  group('ControlScreen', () {
    testWidgets('T2 — Home tap publishes exactly one home pose', (
      tester,
    ) async {
      final repository = FakeRobotRepository();
      await pumpScreen(tester, repository, connect: true);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Home'));
      await tester.pumpAndSettle();

      expect(repository.sentPoses, [PoseCommand.home]);
    });

    testWidgets('T3 — Sleep tap publishes exactly one sleep pose', (
      tester,
    ) async {
      final repository = FakeRobotRepository();
      await pumpScreen(tester, repository, connect: true);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sleep'));
      await tester.pumpAndSettle();

      expect(repository.sentPoses, [PoseCommand.sleep]);
    });

    testWidgets('T4 — buttons disabled when disconnected, no publish', (
      tester,
    ) async {
      final repository = FakeRobotRepository();
      await pumpScreen(tester, repository, connect: false);

      final home = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Home'),
      );
      final sleep = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sleep'),
      );
      expect(home.onPressed, isNull);
      expect(sleep.onPressed, isNull);

      // Tapping a disabled button does nothing.
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Home'),
        warnIfMissed: false,
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Sleep'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(repository.sentPoses, isEmpty);
    });

    testWidgets('T9 (edge) — error state shown, buttons stay disabled', (
      tester,
    ) async {
      await pumpScreen(tester, ThrowingFakeRobotRepository(), connect: true);

      // An error / not-connected indication is shown.
      expect(find.textContaining('Error'), findsOneWidget);

      final home = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Home'),
      );
      final sleep = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sleep'),
      );
      expect(home.onPressed, isNull);
      expect(sleep.onPressed, isNull);
    });

    testWidgets('Slice9 T1 — Home tap → delivered after ok ack', (
      tester,
    ) async {
      final repository = FakeRobotRepository()
        ..sendPoseAck = const Ack(ok: true);
      await pumpScreen(tester, repository, connect: true);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Home'));
      await tester.pumpAndSettle();

      // A ✓ delivered indication shows.
      expect(find.textContaining('delivered'), findsOneWidget);
      expect(find.textContaining('✓'), findsOneWidget);
      // Exactly one pose reached the repo.
      expect(repository.sentPoses, [PoseCommand.home]);
    });

    testWidgets('Slice9 T2 — gateway reject → ✗ rejected: <reason>', (
      tester,
    ) async {
      final repository = FakeRobotRepository()
        ..sendPoseAck = const Ack(ok: false, error: 'unknown_pose');
      await pumpScreen(tester, repository, connect: true);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Home'));
      await tester.pumpAndSettle();

      // A ✗ rejected indication carrying the reason shows.
      final rejected = find.textContaining('rejected');
      expect(rejected, findsOneWidget);
      expect(find.textContaining('unknown_pose'), findsOneWidget);
      expect(find.textContaining('✗'), findsOneWidget);
    });

    testWidgets('Slice9 T3 — transport error → error indication, no hang', (
      tester,
    ) async {
      final repository = FakeRobotRepository()
        ..sendPoseError = StateError('boom');
      await pumpScreen(tester, repository, connect: true);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Home'));
      await tester.pumpAndSettle();

      // An error indication shows; the UI is responsive (pumpAndSettle
      // returning means no pending frames / hang).
      expect(find.textContaining('Error'), findsWidgets);
      expect(repository.sentPoses, [PoseCommand.home]);
    });

    testWidgets('Slice9 T5 — buttons disabled mid-send until settled', (
      tester,
    ) async {
      final repository = CompleterFakeRobotRepository();
      await pumpScreen(tester, repository, connect: true);

      // Tap Home — the send is in flight (the completer has not resolved).
      await tester.tap(find.widgetWithText(ElevatedButton, 'Home'));
      await tester.pump();

      final homeMid = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Home'),
      );
      final sleepMid = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sleep'),
      );
      expect(homeMid.onPressed, isNull);
      expect(sleepMid.onPressed, isNull);

      // A 2nd tap mid-send issues no further query.
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Home'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(repository.sentPoses, [PoseCommand.home]);

      // Resolve the in-flight send; buttons re-enable.
      repository.complete(const Ack(ok: true));
      await tester.pumpAndSettle();

      final homeAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Home'),
      );
      expect(homeAfter.onPressed, isNotNull);
      expect(repository.sentPoses, [PoseCommand.home]);
    });
  });
}
