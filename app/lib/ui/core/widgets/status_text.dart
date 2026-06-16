import 'package:flutter/material.dart';

import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';

/// Renders the connection status as text: `Connected` (green),
/// `Disconnected`, or the caller-provided [errorText] (red).
///
/// The error label is parameterized because the screens word it differently
/// (`Error` on the connection screen, `Error: not connected` on the control
/// screen).
class StatusText extends StatelessWidget {
  /// Creates a [StatusText] for [status], showing [errorText] on error.
  const StatusText({required this.status, required this.errorText, super.key});

  /// The connection status to render.
  final ConnectionStatus status;

  /// The label shown when [status] is [ConnectionStatus.error].
  final String errorText;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Text('Connected', style: TextStyle(color: Colors.green));
      case ConnectionStatus.error:
        return Text(errorText, style: const TextStyle(color: Colors.red));
      case ConnectionStatus.disconnected:
        return const Text('Disconnected');
    }
  }
}
