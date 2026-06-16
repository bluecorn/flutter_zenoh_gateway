import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenoh_ros_poc/ui/connection/connection_view_model.dart';
import 'package:zenoh_ros_poc/ui/core/widgets/status_text.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('StatusText', () {
    testWidgets('shows Connected for the connected status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const StatusText(
            status: ConnectionStatus.connected,
            errorText: 'Error',
          ),
        ),
      );

      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('shows Disconnected for the disconnected status', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatusText(
            status: ConnectionStatus.disconnected,
            errorText: 'Error',
          ),
        ),
      );

      expect(find.text('Disconnected'), findsOneWidget);
    });

    testWidgets('error label is parameterized — shows exactly the provided '
        'label for each instance', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              StatusText(status: ConnectionStatus.error, errorText: 'Error'),
              StatusText(
                status: ConnectionStatus.error,
                errorText: 'Error: not connected',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Error: not connected'), findsOneWidget);
    });
  });
}
