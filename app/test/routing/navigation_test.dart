import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/routing/app_router.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_screen.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';
import 'package:zenoh_ros_poc/ui/control/control_screen.dart';

import '../helpers/fakes.dart';

/// A consumer widget that reads the REAL [routerProvider] and builds a
/// [MaterialApp.router] from it — exercising the app's actual route table.
class _RouterApp extends ConsumerWidget {
  const _RouterApp({this.initialLocation});

  final String? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    if (initialLocation != null) {
      router.go(initialLocation!);
    }
    return MaterialApp.router(routerConfig: router);
  }
}

void main() {
  late FakeRobotRepository fakeRepository;

  setUp(() {
    fakeRepository = FakeRobotRepository();
  });

  /// Pumps the full app through the real [routerProvider] with the fake
  /// repository and the given persisted prefs injected.
  Future<ProviderScope> pumpApp(
    WidgetTester tester,
    SharedPreferences prefs, {
    String? initialLocation,
  }) async {
    final scope = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        robotRepositoryProvider.overrideWithValue(fakeRepository),
      ],
      child: _RouterApp(initialLocation: initialLocation),
    );
    await tester.pumpWidget(scope);
    await tester.pumpAndSettle();
    return scope;
  }

  group('Connect → Control navigation', () {
    testWidgets('T1 — tapping Connect navigates to the control screen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await pumpApp(tester, prefs);

      // We start on the connection screen.
      expect(find.byType(ConnectionScreen), findsOneWidget);
      expect(find.byType(ControlScreen), findsNothing);

      // Tapping Connect (fake succeeds) navigates to /control.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Connect'));
      await tester.pumpAndSettle();

      expect(find.byType(ControlScreen), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Home'), findsOneWidget);
    });

    testWidgets('T2 — Disconnect returns to Connect with status disconnected '
        '(no nav loop)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await pumpApp(tester, prefs);

      // Get to the control screen connected.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Connect'));
      await tester.pumpAndSettle();
      expect(find.byType(ControlScreen), findsOneWidget);

      // Tap the Disconnect action.
      await tester.tap(find.byTooltip('Disconnect'));
      await tester.pumpAndSettle();

      // We are back on the connection screen and the connect→control
      // listener did NOT re-fire (status is disconnected).
      expect(find.byType(ConnectionScreen), findsOneWidget);
      expect(find.byType(ControlScreen), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConnectionScreen)),
      );
      final status = container.read(connectionViewModelProvider).status;
      expect(status, ConnectionStatus.disconnected);
    });
  });
}
