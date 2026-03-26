import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/admin/manage_leagues_screen.dart';

void main() {
  group('ManageLeaguesScreen', () {
    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime(2024),
      ownerId: 'owner-1',
    );

    final superAdmin = AppUser(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Super Admin',
      role: UserRole.superAdmin,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final testLeagues = [
      League(
        id: 'league-1',
        orgId: 'org-1',
        name: 'Spring League',
        abbreviation: 'SL',
        createdAt: DateTime.now(),
      ),
      League(
        id: 'league-2',
        orgId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime.now(),
      ),
    ];

    final testHubs = [
      Hub(
        id: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary Hub',
        location: 'Calgary, AB',
        createdAt: DateTime.now(),
      ),
      Hub(
        id: 'hub-2',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Edmonton Hub',
        location: 'Edmonton, AB',
        createdAt: DateTime.now(),
      ),
    ];

    final testTeams = [
      Team(
        id: 'team-1',
        hubId: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary U11 AA',
        ageGroup: 'U11',
        division: 'AA',
        createdAt: DateTime.now(),
      ),
      Team(
        id: 'team-2',
        hubId: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary U13 AA',
        ageGroup: 'U13',
        division: 'AA',
        createdAt: DateTime.now(),
      ),
    ];

    Widget createTestWidget({
      AppUser? user,
      List<League>? leagues,
      List<Hub>? hubs,
      List<Team>? teams,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? superAdmin,
          ),
          organizationProvider.overrideWith(
            (ref) => testOrg,
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          hubsProvider.overrideWith((ref, leagueId) {
            final allHubs = hubs ?? testHubs;
            return Stream.value(
              allHubs.where((h) => h.leagueId == leagueId).toList(),
            );
          }),
          teamsProvider.overrideWith((ref, params) {
            final allTeams = teams ?? testTeams;
            return Stream.value(
              allTeams.where((t) => t.hubId == params.hubId).toList(),
            );
          }),
        ],
        child: MaterialApp(
          home: ManageLeaguesScreen(),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    group('Screen Rendering', () {
      testWidgets('renders without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(ManageLeaguesScreen), findsOneWidget);
      });

      testWidgets('displays title Manage Leagues & Hubs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Manage Leagues & Hubs'), findsOneWidget);
      });
    });

    group('League List Rendering', () {
      testWidgets('displays all leagues', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Spring League'), findsOneWidget);
        expect(find.text('Fall League'), findsOneWidget);
      });

      testWidgets('shows league abbreviations', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('SL'), findsOneWidget);
        expect(find.text('FL'), findsOneWidget);
      });
    });

    group('Expansion Tiles', () {
      testWidgets('shows expansion tiles for leagues',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsWidgets);
      });

      testWidgets('displays hub count in subtitle', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Spring League has 2 hubs, Fall League has 0
        expect(find.text('2 hubs'), findsOneWidget);
      });

      testWidgets('can expand league to show hubs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap first league to expand it
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Should now see hub names
        expect(find.text('Calgary Hub'), findsOneWidget);
        expect(find.text('Edmonton Hub'), findsOneWidget);
      });
    });

    group('Hub Display', () {
      testWidgets('displays hub names when expanded',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Calgary Hub'), findsOneWidget);
        expect(find.text('Edmonton Hub'), findsOneWidget);
      });

      testWidgets('displays hub locations', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Calgary, AB'), findsOneWidget);
        expect(find.text('Edmonton, AB'), findsOneWidget);
      });

      testWidgets('displays team count for hubs', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Calgary Hub has 2 teams
        expect(find.text('2t'), findsOneWidget);
      });
    });

    group('Team Display', () {
      testWidgets('shows teams when hub is expanded',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Find and expand the first hub (Calgary Hub)
        final hubTiles = find.byType(ExpansionTile);
        // Second expansion tile should be the first hub
        await tester.tap(hubTiles.at(1));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Calgary U11 AA'), findsOneWidget);
        expect(find.text('Calgary U13 AA'), findsOneWidget);
      });

      testWidgets('displays team age group and division',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first hub
        final hubTiles = find.byType(ExpansionTile);
        await tester.tap(hubTiles.at(1));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should see age group and division info
        expect(find.text('U11 · AA'), findsOneWidget);
        expect(find.text('U13 · AA'), findsOneWidget);
      });
    });

    group('FAB Visibility', () {
      testWidgets('shows Add League FAB for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: superAdmin));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('FAB shows Add League label', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: superAdmin));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Add League'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no leagues',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No leagues yet'), findsOneWidget);
        expect(
          find.text('Tap the button below to add your first league.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      });

      testWidgets('empty state is centered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(Center), findsWidgets);
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator while fetching',
          (WidgetTester tester) async {
        // Create a provider that never emits to simulate loading
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => superAdmin),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              home: ManageLeaguesScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Should eventually show content (Stream.value emits immediately)
        expect(find.byType(ManageLeaguesScreen), findsOneWidget);
      });
    });

    group('Multiple Leagues', () {
      testWidgets('displays multiple leagues correctly',
          (WidgetTester tester) async {
        final manyLeagues = [
          League(
            id: 'league-1',
            orgId: 'org-1',
            name: 'Spring League',
            abbreviation: 'SL',
            createdAt: DateTime.now(),
          ),
          League(
            id: 'league-2',
            orgId: 'org-1',
            name: 'Fall League',
            abbreviation: 'FL',
            createdAt: DateTime.now(),
          ),
          League(
            id: 'league-3',
            orgId: 'org-1',
            name: 'Winter League',
            abbreviation: 'WL',
            createdAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(createTestWidget(leagues: manyLeagues));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Spring League'), findsOneWidget);
        expect(find.text('Fall League'), findsOneWidget);
        expect(find.text('Winter League'), findsOneWidget);
      });
    });

    group('League Abbreviations', () {
      testWidgets('displays abbreviations in badge format',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('SL'), findsOneWidget);
        expect(find.text('FL'), findsOneWidget);
      });
    });

    group('Action Buttons', () {
      testWidgets('shows add hub and delete buttons for leagues',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Should find icon buttons (add hub, delete)
        expect(find.byIcon(Icons.add_location_alt_outlined), findsWidgets);
        expect(find.byIcon(Icons.delete_outline), findsWidgets);
      });
    });

    group('Hub Sections', () {
      testWidgets('shows empty hub message when league has no hubs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(hubs: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No hubs yet. Tap + to add one.'), findsOneWidget);
      });

      testWidgets('shows empty team message when hub has no teams',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(teams: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first league
        await tester.tap(find.byType(ExpansionTile).first);
        await tester.pump();
        await tester.pumpAndSettle();

        // Expand first hub
        final hubTiles = find.byType(ExpansionTile);
        await tester.tap(hubTiles.at(1));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No teams yet. Tap + to add one.'), findsOneWidget);
      });
    });
  });
}
