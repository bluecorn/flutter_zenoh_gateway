import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zenoh_ros_poc/ui/connection/connection_screen.dart';
import 'package:zenoh_ros_poc/ui/control/control_screen.dart';

/// Provides the app-wide [GoRouter]: the connection screen at `/connect` and
/// the pose-control screen at `/control`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
});
