import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/bottom_nav_bar.dart';

void main() {
  group('BottomNavBar', () {
    testWidgets('renders all 5 navigation items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Docs'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('calls onTap with correct index when tapped', (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 0,
              onTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Chat'));
      expect(tappedIndex, 1);
    });

    testWidgets('calls onTap with index 0 when Home is tapped', (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 2,
              onTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Home'));
      expect(tappedIndex, 0);
    });

    testWidgets('calls onTap with index 4 when More is tapped', (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 0,
              onTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      await tester.tap(find.text('More'));
      expect(tappedIndex, 4);
    });

    testWidgets('renders BottomNavigationBar widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('current index is reflected in the navigation bar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 2,
              onTap: (_) {},
            ),
          ),
        ),
      );

      final navBar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );

      expect(navBar.currentIndex, 2);
    });

    testWidgets('wraps BottomNavigationBar in Container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsWidgets);
    });
  });
}
