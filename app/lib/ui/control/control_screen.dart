import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zenoh_ros_poc/data/models/pose_command.dart';
import 'package:zenoh_ros_poc/providers/providers.dart';
import 'package:zenoh_ros_poc/ui/control/control_view_model.dart';
import 'package:zenoh_ros_poc/ui/core/widgets/status_text.dart';

/// Control screen: Home and Sleep pose buttons, enabled only when connected.
///
/// Each button forwards its pose through the control view model. The buttons
/// are disabled when disconnected AND while a send is in flight (the VM's
/// gate already no-ops a 2nd tap; the screen mirrors it visibly). The VM's
/// [SendResult] drives a sending indicator and a ✓ delivered / ✗ rejected /
/// error indication.
class ControlScreen extends ConsumerWidget {
  /// Creates a [ControlScreen].
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final control = ref.watch(controlViewModelProvider);
    final result = control.result;
    final sending = result is SendingResult;
    // Buttons fire only when connected AND no send is in flight.
    final canTap = control.canSend && !sending;
    final status = ref.watch(connectionViewModelProvider).status;

    void send(PoseCommand pose) {
      unawaited(ref.read(controlViewModelProvider.notifier).sendPose(pose));
    }

    void disconnect() {
      ref.read(connectionViewModelProvider.notifier).disconnect();
      context.go('/connect');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Disconnect',
            onPressed: disconnect,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: canTap ? () => send(PoseCommand.home) : null,
              child: const Text('Home'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: canTap ? () => send(PoseCommand.sleep) : null,
              child: const Text('Sleep'),
            ),
            const SizedBox(height: 24),
            StatusText(status: status, errorText: 'Error: not connected'),
            const SizedBox(height: 16),
            _SendResultText(result: result),
          ],
        ),
      ),
    );
  }
}

/// Renders the [SendResult] state machine: a sending indicator while in
/// flight, ✓ delivered on success, `✗ rejected: <reason>` on a business
/// reject, an error message on a transport error, and nothing when idle.
class _SendResultText extends StatelessWidget {
  const _SendResultText({required this.result});

  final SendResult result;

  @override
  Widget build(BuildContext context) {
    switch (result) {
      case IdleResult():
        return const SizedBox.shrink();
      case SendingResult():
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Sending…'),
          ],
        );
      case DeliveredResult():
        return const Text(
          '✓ delivered',
          style: TextStyle(color: Colors.green),
        );
      case RejectedResult(:final reason):
        return Text(
          '✗ rejected: $reason',
          style: const TextStyle(color: Colors.red),
        );
      case ErrorResult():
        return const Text(
          'Error: send failed',
          style: TextStyle(color: Colors.red),
        );
    }
  }
}
