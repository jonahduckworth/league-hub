import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/settings/notifications_screen.dart';

Widget _buildTestWidget() {
  return const ProviderScope(
    child: MaterialApp(
      home: NotificationsScreen(),
    ),
  );
}

void main() {
  group('NotificationsScreen', () {
    testWidgets('renders notification categories', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('PUSH NOTIFICATIONS'), findsOneWidget);
      expect(find.text('DELIVERY'), findsOneWidget);
    });

    testWidgets('shows all notification toggles', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Chat Messages'), findsOneWidget);
      expect(find.text('Document Uploads'), findsOneWidget);
      expect(find.text('Team Updates'), findsOneWidget);
      expect(find.text('Event Reminders'), findsOneWidget);
      expect(find.text('Admin Alerts'), findsOneWidget);
    });

    testWidgets('shows delivery options', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Vibration'), findsOneWidget);
      expect(find.text('Badge Count'), findsOneWidget);
    });

    testWidgets('all toggles default to on', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // All 9 Switch.adaptive widgets should be on (true)
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      for (final sw in switches) {
        expect(sw.value, isTrue);
      }
    });

    testWidgets('tapping a toggle changes its state', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Find and tap the first Switch
      final firstSwitch = find.byType(Switch).first;
      await tester.tap(firstSwitch);
      await tester.pump();
      await tester.pumpAndSettle();

      // At least one Switch should now be off
      final switches = tester.widgetList<Switch>(find.byType(Switch));
      expect(switches.any((sw) => !sw.value), isTrue);
    });

    testWidgets('shows FCM info note', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Scroll to bottom of ListView to ensure FCM note is built
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Notification preferences sync with FCM topics'),
          findsOneWidget);
    });

    testWidgets('shows subtitles for each notification type', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('New and pinned announcements'), findsOneWidget);
      expect(find.text('New messages in your chat rooms'), findsOneWidget);
      expect(find.text('New documents shared with you'), findsOneWidget);
    });

    testWidgets('renders 9 switches total', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNWidgets(9));
    });
  });
}
