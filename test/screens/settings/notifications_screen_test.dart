import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/settings/notifications_screen.dart';

Widget _buildTestWidget({List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
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
      expect(find.text('Roster changes and team news'), findsOneWidget);
      expect(find.text('Upcoming games and practices'), findsOneWidget);
      expect(find.text('User management and system alerts'), findsOneWidget);
    });

    testWidgets('renders 9 switches total', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(Switch), findsNWidgets(9));
    });

    testWidgets('renders correct icons for notification types', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify icons exist
      expect(find.byIcon(Icons.campaign), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsOneWidget);
    });

    testWidgets('renders delivery icons', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.vibration), findsOneWidget);
      expect(find.byIcon(Icons.looks_one_outlined), findsOneWidget);
    });

    testWidgets('tapping chat messages toggle changes only that toggle',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Find "Chat Messages" tile and tap its Switch
      final chatTile = find.ancestor(
        of: find.text('Chat Messages'),
        matching: find.byType(ListTile),
      );
      final chatSwitch = find.descendant(
        of: chatTile,
        matching: find.byType(Switch),
      );
      await tester.tap(chatSwitch);
      await tester.pumpAndSettle();

      // Verify the chat switch is now off
      final updatedSwitch =
          tester.widget<Switch>(chatSwitch);
      expect(updatedSwitch.value, isFalse);
    });

    testWidgets('delivery section shows sound subtitle', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Play sound for notifications'), findsOneWidget);
      expect(find.text('Vibrate for notifications'), findsOneWidget);
      expect(find.text('Show unread count on app icon'), findsOneWidget);
    });

    testWidgets('has a scrollable ListView', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('info box contains info icon', (tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });

  group('NotificationPrefsNotifier', () {
    test('initial state has all preferences enabled', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = container.read(notificationPrefsProvider);

      expect(prefs['announcements'], isTrue);
      expect(prefs['chat_messages'], isTrue);
      expect(prefs['document_uploads'], isTrue);
      expect(prefs['team_updates'], isTrue);
      expect(prefs['event_reminders'], isTrue);
      expect(prefs['admin_alerts'], isTrue);
      expect(prefs['sound'], isTrue);
      expect(prefs['vibration'], isTrue);
      expect(prefs['badge_count'], isTrue);
    });

    test('initial state has 9 keys', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final prefs = container.read(notificationPrefsProvider);
      expect(prefs.length, 9);
    });

    test('toggle flips a preference value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationPrefsProvider.notifier);
      expect(container.read(notificationPrefsProvider)['announcements'], isTrue);

      notifier.toggle('announcements');
      expect(
          container.read(notificationPrefsProvider)['announcements'], isFalse);
    });

    test('toggle twice returns to original value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationPrefsProvider.notifier);
      notifier.toggle('chat_messages');
      notifier.toggle('chat_messages');

      expect(
          container.read(notificationPrefsProvider)['chat_messages'], isTrue);
    });

    test('toggling one key does not affect others', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationPrefsProvider.notifier);
      notifier.toggle('sound');

      final prefs = container.read(notificationPrefsProvider);
      expect(prefs['sound'], isFalse);
      expect(prefs['announcements'], isTrue);
      expect(prefs['chat_messages'], isTrue);
      expect(prefs['vibration'], isTrue);
    });

    test('toggle with unknown key defaults missing value to true then false',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationPrefsProvider.notifier);
      // Toggling a key not in initial state: (state[key] ?? true) → false
      notifier.toggle('unknown_key');
      expect(
          container.read(notificationPrefsProvider)['unknown_key'], isFalse);
    });

    test('multiple different keys can be toggled independently', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(notificationPrefsProvider.notifier);
      notifier.toggle('announcements');
      notifier.toggle('team_updates');
      notifier.toggle('badge_count');

      final prefs = container.read(notificationPrefsProvider);
      expect(prefs['announcements'], isFalse);
      expect(prefs['team_updates'], isFalse);
      expect(prefs['badge_count'], isFalse);
      // Untouched remain true
      expect(prefs['chat_messages'], isTrue);
      expect(prefs['document_uploads'], isTrue);
      expect(prefs['sound'], isTrue);
    });
  });
}
