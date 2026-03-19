import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/league_filter.dart';
import 'package:league_hub/models/league.dart';

void main() {
  final testDate = DateTime(2024, 1, 1);

  League makeLeague(String id, String name, String abbr) => League(
        id: id,
        orgId: 'org1',
        name: name,
        abbreviation: abbr,
        createdAt: testDate,
      );

  group('LeagueFilter', () {
    testWidgets('always shows "All" pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeagueFilter(
              leagues: [],
              selectedLeagueId: null,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows abbreviations for each league', (tester) async {
      final leagues = [
        makeLeague('l1', 'Premier League', 'PL'),
        makeLeague('l2', 'Championship', 'CHAMP'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeagueFilter(
              leagues: leagues,
              selectedLeagueId: null,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('PL'), findsOneWidget);
      expect(find.text('CHAMP'), findsOneWidget);
    });

    testWidgets('calls onSelected(null) when All is tapped', (tester) async {
      String? selected = 'l1';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeagueFilter(
              leagues: [makeLeague('l1', 'Premier', 'PL')],
              selectedLeagueId: 'l1',
              onSelected: (id) => selected = id,
            ),
          ),
        ),
      );

      await tester.tap(find.text('All'));
      expect(selected, isNull);
    });

    testWidgets('calls onSelected with league id when pill tapped', (tester) async {
      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeagueFilter(
              leagues: [makeLeague('l1', 'Premier', 'PL')],
              selectedLeagueId: null,
              onSelected: (id) => selected = id,
            ),
          ),
        ),
      );

      await tester.tap(find.text('PL'));
      expect(selected, 'l1');
    });

    testWidgets('renders only All pill when leagues list is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeagueFilter(
              leagues: [],
              selectedLeagueId: null,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      // No league abbreviation pills
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('renders in horizontal scrollable list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeagueFilter(
              leagues: [],
              selectedLeagueId: null,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows multiple league pills', (tester) async {
      final leagues = List.generate(
        5,
        (i) => makeLeague('l$i', 'League $i', 'L$i'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LeagueFilter(
                leagues: leagues,
                selectedLeagueId: null,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      // All pills render (All + 5 leagues = 6 GestureDetectors)
      expect(find.byType(GestureDetector), findsNWidgets(6));
    });
  });
}
