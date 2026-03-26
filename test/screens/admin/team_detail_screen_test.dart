import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/admin/team_detail_screen.dart';

AppUser _makeUser({
  String id = 'u1',
  UserRole role = UserRole.staff,
  List<String> hubIds = const [],
}) =>
    AppUser(
      id: id,
      email: '$id@test.com',
      displayName: 'User $id',
      role: role,
      orgId: 'org1',
      hubIds: hubIds,
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

final _testOrg = Organization(
  id: 'org1',
  name: 'Test Org',
  primaryColor: '#1A3A5C',
  secondaryColor: '#2E75B6',
  accentColor: '#4DA3FF',
  createdAt: DateTime.now(),
  ownerId: 'owner1',
);

final _testTeam = Team(
  id: 'team1',
  hubId: 'hub1',
  leagueId: 'league1',
  orgId: 'org1',
  name: 'Calgary U11 AA',
  ageGroup: 'U11',
  division: 'AA',
  chatRoomId: 'chat-team1',
  memberIds: ['u1', 'u2'],
  createdAt: DateTime(2024),
);

final _emptyTeam = Team(
  id: 'team2',
  hubId: 'hub1',
  leagueId: 'league1',
  orgId: 'org1',
  name: 'Empty Team',
  memberIds: [],
  createdAt: DateTime(2024),
);

Widget _buildWidget({
  required AppUser currentUser,
  required Team team,
  List<AppUser> orgUsers = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => currentUser),
      organizationProvider.overrideWith((ref) => _testOrg),
      teamsProvider((leagueId: team.leagueId, hubId: team.hubId))
          .overrideWith((ref) => Stream.value([team])),
      orgUsersProvider
          .overrideWith((ref) => Stream.value(orgUsers)),
    ],
    child: MaterialApp(
      home: TeamDetailScreen(
        teamId: team.id,
        leagueId: team.leagueId,
        hubId: team.hubId,
      ),
    ),
  );
}

void main() {
  group('TeamDetailScreen', () {
    group('All Roles - Basic Rendering', () {
      for (final role in UserRole.values) {
        testWidgets('${role.name} can view team details', (tester) async {
          await tester.pumpWidget(_buildWidget(
            currentUser: _makeUser(role: role, hubIds: ['hub1']),
            team: _testTeam,
            orgUsers: [
              _makeUser(id: 'u1'),
              _makeUser(id: 'u2'),
            ],
          ));
          await tester.pumpAndSettle();

          expect(find.text('Team Details'), findsOneWidget);
          expect(find.text('Calgary U11 AA'), findsOneWidget);
        });
      }
    });

    testWidgets('shows age group and division', (tester) async {
      await tester.pumpWidget(_buildWidget(
        currentUser: _makeUser(role: UserRole.superAdmin),
        team: _testTeam,
        orgUsers: [_makeUser(id: 'u1'), _makeUser(id: 'u2')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('U11 · AA'), findsOneWidget);
    });

    testWidgets('shows team chat link when chatRoomId exists', (tester) async {
      await tester.pumpWidget(_buildWidget(
        currentUser: _makeUser(role: UserRole.superAdmin),
        team: _testTeam,
        orgUsers: [_makeUser(id: 'u1'), _makeUser(id: 'u2')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Team Chat'), findsOneWidget);
      expect(find.text('Open the team chat room'), findsOneWidget);
    });

    testWidgets('hides team chat link when no chatRoomId', (tester) async {
      await tester.pumpWidget(_buildWidget(
        currentUser: _makeUser(role: UserRole.superAdmin),
        team: _emptyTeam,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Team Chat'), findsNothing);
    });

    testWidgets('shows roster section', (tester) async {
      await tester.pumpWidget(_buildWidget(
        currentUser: _makeUser(role: UserRole.superAdmin),
        team: _testTeam,
        orgUsers: [_makeUser(id: 'u1'), _makeUser(id: 'u2')],
      ));
      await tester.pumpAndSettle();

      expect(find.text('ROSTER'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);
    });

    testWidgets('shows "No members yet" for empty team', (tester) async {
      await tester.pumpWidget(_buildWidget(
        currentUser: _makeUser(role: UserRole.superAdmin),
        team: _emptyTeam,
        orgUsers: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('No members yet'), findsOneWidget);
    });

    testWidgets('shows member names in roster', (tester) async {
      await tester.pumpWidget(_buildWidget(
        currentUser: _makeUser(role: UserRole.superAdmin),
        team: _testTeam,
        orgUsers: [
          _makeUser(id: 'u1'),
          _makeUser(id: 'u2'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('User u1'), findsOneWidget);
      expect(find.text('User u2'), findsOneWidget);
    });

    testWidgets('shows Team not found for invalid teamId', (tester) async {
      final teamWithDifferentId = Team(
        id: 'other',
        hubId: 'hub1',
        leagueId: 'league1',
        orgId: 'org1',
        name: 'Other',
        memberIds: [],
        createdAt: DateTime(2024),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
              (ref) => _makeUser(role: UserRole.superAdmin)),
          organizationProvider.overrideWith((ref) => _testOrg),
          teamsProvider((leagueId: 'league1', hubId: 'hub1'))
              .overrideWith((ref) => Stream.value([teamWithDifferentId])),
          orgUsersProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: TeamDetailScreen(
            teamId: 'nonexistent',
            leagueId: 'league1',
            hubId: 'hub1',
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Team not found'), findsOneWidget);
    });

    group('Permission checks', () {
      testWidgets('managerAdmin+ sees add member button', (tester) async {
        await tester.pumpWidget(_buildWidget(
          currentUser:
              _makeUser(role: UserRole.managerAdmin, hubIds: ['hub1']),
          team: _emptyTeam,
          orgUsers: [],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
      });

      testWidgets('staff does not see add member button', (tester) async {
        await tester.pumpWidget(_buildWidget(
          currentUser: _makeUser(role: UserRole.staff),
          team: _emptyTeam,
          orgUsers: [],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.person_add_outlined), findsNothing);
      });

      testWidgets('managerAdmin+ sees remove member button', (tester) async {
        await tester.pumpWidget(_buildWidget(
          currentUser:
              _makeUser(role: UserRole.managerAdmin, hubIds: ['hub1']),
          team: _testTeam,
          orgUsers: [_makeUser(id: 'u1'), _makeUser(id: 'u2')],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.remove_circle_outline), findsWidgets);
      });

      testWidgets('staff does not see remove member button', (tester) async {
        await tester.pumpWidget(_buildWidget(
          currentUser: _makeUser(role: UserRole.staff),
          team: _testTeam,
          orgUsers: [_makeUser(id: 'u1'), _makeUser(id: 'u2')],
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.remove_circle_outline), findsNothing);
      });
    });
  });
}
