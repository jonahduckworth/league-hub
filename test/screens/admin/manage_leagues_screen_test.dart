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
      displayName: 'Admin',
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
        createdAt: DateTime(2024),
      ),
      League(
        id: 'league-2',
        orgId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime(2024),
      ),
    ];

    final testHubs = [
      Hub(
        id: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary Hub',
        location: 'Calgary, AB',
        createdAt: DateTime(2024),
      ),
      Hub(
        id: 'hub-2',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Edmonton Hub',
        location: 'Edmonton, AB',
        createdAt: DateTime(2024),
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
        createdAt: DateTime(2024),
      ),
      Team(
        id: 'team-2',
        hubId: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'Calgary U13 AA',
        ageGroup: 'U13',
        division: 'AA',
        createdAt: DateTime(2024),
      ),
    ];

    Widget wrap({
      required Widget child,
      AppUser? user,
      List<League>? leagues,
      List<Hub>? hubs,
      List<Team>? teams,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user ?? superAdmin),
          organizationProvider.overrideWith((ref) => testOrg),
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
          home: child,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
        ),
      );
    }

    Widget createManageWidget({List<League>? leagues}) {
      return wrap(
        leagues: leagues,
        child: const ManageLeaguesScreen(),
      );
    }

    Widget createEditLeagueWidget({League? league}) {
      final selectedLeague = league ??
          League(
            id: 'league-1',
            orgId: 'org-1',
            name: 'Spring League',
            abbreviation: 'SL',
            websiteUrl: 'https://spring.example',
            instagramUrl: 'https://instagram.com/spring',
            xUrl: 'https://x.com/spring',
            createdAt: DateTime(2024),
          );

      return wrap(
        leagues: [selectedLeague],
        child: EditLeagueScreen(
          leagueId: selectedLeague.id,
          initialLeague: selectedLeague,
        ),
      );
    }

    Widget createLeagueDetailWidget() {
      return wrap(
        child: LeagueDetailScreen(
          leagueId: testLeagues.first.id,
          initialLeague: testLeagues.first,
        ),
      );
    }

    Widget createHubDetailWidget() {
      return wrap(
        child: HubDetailScreen(
          leagueId: testLeagues.first.id,
          hubId: testHubs.first.id,
          initialLeague: testLeagues.first,
          initialHub: testHubs.first,
        ),
      );
    }

    group('League List', () {
      testWidgets('renders leagues as navigation rows',
          (WidgetTester tester) async {
        await tester.pumpWidget(createManageWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ManageLeaguesScreen), findsOneWidget);
        expect(find.text('Manage Leagues & Hubs'), findsOneWidget);
        expect(find.text('Spring League'), findsOneWidget);
        expect(find.text('Fall League'), findsOneWidget);
        expect(find.text('2 hubs'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      });

      testWidgets('uses a header add action instead of a low add button',
          (WidgetTester tester) async {
        await tester.pumpWidget(createManageWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.text('Add League'), findsNothing);
      });

      testWidgets('shows empty state when no leagues',
          (WidgetTester tester) async {
        await tester.pumpWidget(createManageWidget(leagues: []));
        await tester.pumpAndSettle();

        expect(find.text('No leagues yet'), findsOneWidget);
        expect(
          find.text('Use + in the header to add your first league.'),
          findsOneWidget,
        );
      });
    });

    group('League Detail', () {
      testWidgets('shows league actions and hubs as rows',
          (WidgetTester tester) async {
        await tester.pumpWidget(createLeagueDetailWidget());
        await tester.pumpAndSettle();

        expect(find.text('League Details'), findsOneWidget);
        expect(find.text('Spring League'), findsWidgets);
        expect(find.text('Edit League'), findsOneWidget);
        expect(find.text('Add Hub'), findsOneWidget);
        expect(find.text('Delete League'), findsOneWidget);
        expect(find.text('Calgary Hub'), findsOneWidget);
        expect(find.text('Edmonton Hub'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
      });
    });

    group('Hub Detail', () {
      testWidgets('shows hub actions and teams as rows',
          (WidgetTester tester) async {
        await tester.pumpWidget(createHubDetailWidget());
        await tester.pumpAndSettle();

        expect(find.text('Hub Details'), findsOneWidget);
        expect(find.text('Calgary Hub'), findsWidgets);
        expect(find.text('Edit Hub'), findsOneWidget);
        expect(find.text('Add Team'), findsOneWidget);
        expect(find.text('Delete Hub'), findsOneWidget);
        expect(find.text('Calgary U11 AA'), findsOneWidget);
        expect(find.text('Calgary U13 AA'), findsOneWidget);
        expect(find.text('U11 · AA'), findsOneWidget);
        expect(find.text('U13 · AA'), findsOneWidget);
        expect(find.byType(ExpansionTile), findsNothing);
      });
    });

    group('League Form', () {
      testWidgets('edit league includes quick link URL fields',
          (WidgetTester tester) async {
        await tester.pumpWidget(createEditLeagueWidget());
        await tester.pumpAndSettle();

        expect(find.text('QUICK LINKS'), findsOneWidget);
        expect(find.text('League Website URL'), findsOneWidget);
        expect(find.text('https://spring.example'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('X URL'),
          300,
          scrollable: find.byType(Scrollable).last,
        );

        expect(find.text('Instagram URL'), findsOneWidget);
        expect(find.text('https://instagram.com/spring'), findsOneWidget);
        expect(find.text('X URL'), findsOneWidget);
        expect(find.text('https://x.com/spring'), findsOneWidget);
      });
    });
  });
}
