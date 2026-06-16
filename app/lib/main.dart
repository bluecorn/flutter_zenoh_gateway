import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenoh_ros_poc/app.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';

/// Application entry point: initialises [SharedPreferences] and launches the
/// app inside a [ProviderScope] with the required overrides.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MainApp(),
    ),
  );
}
