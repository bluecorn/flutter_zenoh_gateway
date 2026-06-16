import 'dart:async';

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';
import 'package:zenoh_ros_poc/ui/core/widgets/status_text.dart';

/// Connection / settings screen: an endpoint field plus a connect action that
/// reflects the live connection status (disconnected / connected / error).
class ConnectionScreen extends ConsumerStatefulWidget {
  /// Creates a [ConnectionScreen].
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final _endpointCtrl = TextEditingController();
  bool _populated = false;

  @override
  void dispose() {
    _endpointCtrl.dispose();
    super.dispose();
  }

  void _onConnect() {
    unawaited(
      ref
          .read(connectionViewModelProvider.notifier)
          .connect(_endpointCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionViewModelProvider);

    // On a successful connection, navigate to the control screen.
    ref.listen<ConnectionState>(connectionViewModelProvider, (previous, next) {
      if (next.status == ConnectionStatus.connected) {
        context.go('/control');
      }
    });

    // Seed the field with the persisted endpoint on the first build.
    if (!_populated) {
      _endpointCtrl.text = state.endpoint;
      _populated = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Connect')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _endpointCtrl,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                hintText: 'tcp/localhost:7447',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _onConnect, child: const Text('Connect')),
            const SizedBox(height: 16),
            StatusText(status: state.status, errorText: 'Error'),
          ],
        ),
      ),
    );
  }
}
