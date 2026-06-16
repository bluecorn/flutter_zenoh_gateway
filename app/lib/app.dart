import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenoh_ros_poc/routing/app_router.dart';
import 'package:zenoh_ros_poc/ui/core/themes/app_theme.dart';

/// Root application widget wired to the [routerProvider].
class MainApp extends ConsumerWidget {
  /// Creates the root [MainApp] widget.
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'PincherX-100 Pose Control',
      theme: appTheme,
      routerConfig: router,
    );
  }
}
