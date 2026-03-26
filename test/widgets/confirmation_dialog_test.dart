import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/confirmation_dialog.dart';

void main() {
  group('showConfirmationDialog', () {
    testWidgets('shows title and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmationDialog(
                context,
                title: 'Delete Item',
                message: 'Are you sure?',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Item'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('cancel returns false', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmationDialog(
                  context,
                  title: 'Test',
                  message: 'Test message',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, false);
    });

    testWidgets('confirm returns true', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmationDialog(
                  context,
                  title: 'Test',
                  message: 'Test message',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('custom labels work', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmationDialog(
                context,
                title: 'Remove',
                message: 'Remove this?',
                cancelLabel: 'No',
                confirmLabel: 'Yes, Remove',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('No'), findsOneWidget);
      expect(find.text('Yes, Remove'), findsOneWidget);
    });

    testWidgets('custom confirm color applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showConfirmationDialog(
                context,
                title: 'Delete',
                message: 'Delete this?',
                confirmLabel: 'Delete',
                confirmColor: Colors.red,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      final style = deleteButton.style;
      // The style should have foregroundColor set to red
      expect(style, isNotNull);
      final foregroundColor =
          style!.foregroundColor?.resolve(<WidgetState>{});
      expect(foregroundColor, Colors.red);
    });
  });
}
