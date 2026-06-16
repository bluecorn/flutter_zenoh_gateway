import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_screen.dart';
import 'package:zenoh_ros_poc/ui/control/control_screen.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeRobotRepository fakeRepository;

  setUp(() {
    fakeRepository = FakeRobotRepository();
  });

  /// Pumps [ConnectionScreen] within a [go_router] that registers both
  /// `/connect` and `/control` (so the connect→control navigation has a
  /// destination), wrapped in a [ProviderScope] with the fake repository and
  /// the given persisted prefs injected.
  Future<void> pumpScreen(WidgetTester tester, SharedPreferences prefs) async {
    final router = GoRouter(
      initialLocation: '/connect',
      routes: [
        GoRoute(
          path: '/connect',
          builder: (context, state) => const ConnectionScreen(),
        ),
        GoRoute(
          path: '/control',
          builder: (context, state) => const ControlScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          robotRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('ConnectionScreen', () {
    testWidgets(
      'T1 — default endpoint shown + connect updates UI to connected',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await pumpScreen(tester, prefs);

        // The endpoint field shows the persisted default.
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller?.text, 'tcp/localhost:7447');

        // Tap connect; the fake reports a successful connection.
        await tester.tap(find.widgetWithText(ElevatedButton, 'Connect'));
        await tester.pumpAndSettle();

        expect(fakeRepository.connectCalls, ['tcp/localhost:7447']);
        // A successful connect navigates to the control screen.
        expect(find.byType(ControlScreen), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Home'), findsOneWidget);
      },
    );
  });
}
