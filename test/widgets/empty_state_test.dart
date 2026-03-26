import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/empty_state.dart';

void main() {
  group('EmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.campaign_outlined,
              title: 'No announcements yet',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.text('No announcements yet'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.forum_outlined,
              title: 'No chat rooms yet',
              subtitle: 'Tap + to start a conversation',
            ),
          ),
        ),
      );

      expect(find.text('No chat rooms yet'), findsOneWidget);
      expect(find.text('Tap + to start a conversation'), findsOneWidget);
    });

    testWidgets('does not render subtitle when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.people_outline,
              title: 'No users found',
            ),
          ),
        ),
      );

      expect(find.text('No users found'), findsOneWidget);
      // Only the icon and title text widgets should exist
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.length, 1);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.folder_open,
              title: 'No documents found',
              action: ElevatedButton(
                onPressed: () {},
                child: const Text('Upload Document'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No documents found'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Upload Document'), findsOneWidget);
    });

    testWidgets('does not render action when null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.people_outline,
              title: 'No users found',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('is centered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: Icons.campaign_outlined,
              title: 'Test',
            ),
          ),
        ),
      );

      // The EmptyState widget builds a Center as its root
      expect(find.descendant(
        of: find.byType(EmptyState),
        matching: find.byType(Center),
      ), findsAtLeastNWidgets(1));
    });
  });
}
