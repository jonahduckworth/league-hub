import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/status_badge.dart';

void main() {
  group('StatusBadge', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Admin', color: Colors.blue),
          ),
        ),
      );

      expect(find.text('Admin'), findsOneWidget);
    });

    testWidgets('applies color to text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Staff', color: Colors.green),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Staff'));
      final style = textWidget.style;
      expect(style?.color, Colors.green);
    });

    testWidgets('applies color to decoration', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Test', color: Colors.red),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container),
      );
      final decoration = container.decoration as BoxDecoration;
      // Background color should be red with alpha 0.12
      expect(decoration.color, Colors.red.withValues(alpha: 0.12));
      // Border should exist by default
      expect(decoration.border, isNotNull);
    });

    testWidgets('showBorder=false removes border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
                label: 'NoBorder', color: Colors.blue, showBorder: false),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isNull);
    });

    testWidgets('custom fontSize works', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(
                label: 'Custom', color: Colors.blue, fontSize: 14),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Custom'));
      expect(textWidget.style?.fontSize, 14);
    });

    testWidgets('default fontSize is 11', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Default', color: Colors.blue),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Default'));
      expect(textWidget.style?.fontSize, 11);
    });

    testWidgets('text has w600 fontWeight', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(label: 'Bold', color: Colors.blue),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Bold'));
      expect(textWidget.style?.fontWeight, FontWeight.w600);
    });
  });
}
