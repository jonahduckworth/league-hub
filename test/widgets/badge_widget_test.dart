import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/badge_widget.dart';

void main() {
  group('BadgeWidget', () {
    testWidgets('returns child directly when count is 0 (no badge text)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 0,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      // No badge number text should appear
      expect(find.text('0'), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('returns child directly when count is negative (no badge text)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: -1,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      expect(find.text('-1'), findsNothing);
    });

    testWidgets('shows badge with count when count > 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 5,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows count 1 correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 1,
              child: Icon(Icons.chat),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows count 99 correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 99,
              child: Icon(Icons.chat),
            ),
          ),
        ),
      );

      expect(find.text('99'), findsOneWidget);
    });

    testWidgets('shows "99+" when count exceeds 99', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 100,
              child: Icon(Icons.chat),
            ),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('shows "99+" for large counts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 1000,
              child: Icon(Icons.chat),
            ),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('badge has danger color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 3,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      // Find all Containers that have BoxDecoration with danger color
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dangerContainers = containers.where((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration) {
          return decoration.color == const Color(0xFFEF4444);
        }
        return false;
      }).toList();

      expect(dangerContainers, isNotEmpty);
    });

    testWidgets('child widget is rendered', (tester) async {
      const testKey = Key('child-icon');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 2,
              child: Icon(Icons.notifications, key: testKey),
            ),
          ),
        ),
      );

      expect(find.byKey(testKey), findsOneWidget);
    });

    testWidgets('badge uses Positioned widget for overlay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 3,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      expect(find.byType(Positioned), findsOneWidget);
    });

    testWidgets('Positioned is NOT present when count is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BadgeWidget(
              count: 0,
              child: Icon(Icons.notifications),
            ),
          ),
        ),
      );

      expect(find.byType(Positioned), findsNothing);
    });
  });
}
