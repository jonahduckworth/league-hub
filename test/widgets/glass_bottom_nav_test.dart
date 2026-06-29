import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/glass_bottom_nav.dart';

void main() {
  group('LeagueHubGlassBottomNav', () {
    Future<void> pumpNav(
      WidgetTester tester, {
      int currentIndex = 0,
      GlassNavBarItem? overrideLastItem,
      required ValueChanged<int> onTap,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: LeagueHubGlassBottomNav(
              currentIndex: currentIndex,
              onTap: onTap,
              overrideLastItem: overrideLastItem,
            ),
          ),
        ),
      );
    }

    testWidgets('shows announcements immediately after home', (tester) async {
      await pumpNav(tester, onTap: (_) {});

      final homeX = tester.getCenter(find.text('Home')).dx;
      final announcementsX = tester.getCenter(find.text('Announcements')).dx;
      final chatsX = tester.getCenter(find.text('Chats')).dx;
      final profileX = tester.getCenter(find.text('Profile')).dx;

      expect(homeX, lessThan(announcementsX));
      expect(announcementsX, lessThan(chatsX));
      expect(chatsX, lessThan(profileX));
    });

    testWidgets('reports announcements as nav index 1', (tester) async {
      final taps = <int>[];

      await pumpNav(tester, onTap: taps.add);
      await tester.tap(find.text('Announcements'));
      await tester.pump();

      expect(taps, [1]);
    });

    testWidgets('fits four nav items on a compact width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpNav(tester, currentIndex: 1, onTap: (_) {});

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports a compact bottom bar height', (tester) async {
      await pumpNav(tester, onTap: (_) {});

      final navSize = tester.getSize(find.byType(LeagueHubGlassBottomNav));

      expect(
        navSize.height,
        leagueHubGlassBottomNavBarHeight + 12,
      );
      expect(navSize.height, lessThan(120));
    });

    testWidgets('replaces profile with a dynamic last nav item',
        (tester) async {
      final taps = <int>[];

      await pumpNav(
        tester,
        currentIndex: 3,
        onTap: taps.add,
        overrideLastItem: const GlassNavBarItem(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings_rounded,
          label: 'Settings',
        ),
      );

      expect(find.text('Profile'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pump();

      expect(taps, [3]);
    });
  });
}
