import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/contact_assignment_visibility.dart';

void main() {
  final leagues = [
    League(
      id: 'league-north',
      orgId: 'org-1',
      name: 'North League',
      abbreviation: 'NL',
      createdAt: DateTime(2026),
    ),
    League(
      id: 'league-south',
      orgId: 'org-1',
      name: 'South League',
      abbreviation: 'SL',
      createdAt: DateTime(2026),
    ),
  ];
  final hubs = [
    Hub(
      id: 'hub-north',
      leagueId: 'league-north',
      orgId: 'org-1',
      name: 'North Hub',
      createdAt: DateTime(2026),
    ),
    Hub(
      id: 'hub-south',
      leagueId: 'league-south',
      orgId: 'org-1',
      name: 'South Hub',
      createdAt: DateTime(2026),
    ),
  ];
  final teams = [
    Team(
      id: 'team-north-a',
      hubId: 'hub-north',
      leagueId: 'league-north',
      orgId: 'org-1',
      name: 'North A',
      createdAt: DateTime(2026),
    ),
    Team(
      id: 'team-north-b',
      hubId: 'hub-north',
      leagueId: 'league-north',
      orgId: 'org-1',
      name: 'North B',
      createdAt: DateTime(2026),
    ),
    Team(
      id: 'team-south',
      hubId: 'hub-south',
      leagueId: 'league-south',
      orgId: 'org-1',
      name: 'South',
      createdAt: DateTime(2026),
    ),
  ];

  AppUser user({
    required String id,
    required UserRole role,
    List<String> leagueIds = const [],
    List<String> hubIds = const [],
    List<String> teamIds = const [],
  }) {
    return AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      role: role,
      orgId: 'org-1',
      leagueIds: leagueIds,
      hubIds: hubIds,
      teamIds: teamIds,
      createdAt: DateTime(2026),
      isActive: true,
    );
  }

  final multiAssignmentContact = user(
    id: 'contact',
    role: UserRole.staff,
    teamIds: const ['team-north-a', 'team-south'],
  );

  group('visibleContactAssignments', () {
    for (final role in [UserRole.platformOwner, UserRole.superAdmin]) {
      test('$role sees all contact assignments', () {
        final visible = visibleContactAssignments(
          viewer: user(id: 'viewer', role: role),
          contact: multiAssignmentContact,
          leagues: leagues,
          hubs: hubs,
          teams: teams,
        );

        expect(visible.hubs.map((hub) => hub.id), ['hub-north', 'hub-south']);
        expect(visible.teams.map((team) => team.id),
            ['team-north-a', 'team-south']);
        expect(visible.hasHiddenHubs, isFalse);
      });
    }

    test('manager sees contact assignments within a managed hub', () {
      final visible = visibleContactAssignments(
        viewer: user(
          id: 'manager',
          role: UserRole.managerAdmin,
          hubIds: const ['hub-north'],
        ),
        contact: multiAssignmentContact,
        leagues: leagues,
        hubs: hubs,
        teams: teams,
      );

      expect(visible.hubs.map((hub) => hub.id), ['hub-north']);
      expect(visible.teams.map((team) => team.id), ['team-north-a']);
      expect(visible.hasHiddenHubs, isTrue);
      expect(visible.hasHiddenTeams, isTrue);
    });

    test('staff sees only shared teams and their parent hubs', () {
      final visible = visibleContactAssignments(
        viewer: user(
          id: 'staff',
          role: UserRole.staff,
          teamIds: const ['team-north-a'],
        ),
        contact: multiAssignmentContact,
        leagues: leagues,
        hubs: hubs,
        teams: teams,
      );

      expect(visible.hubs.map((hub) => hub.id), ['hub-north']);
      expect(visible.teams.map((team) => team.id), ['team-north-a']);
      expect(visible.leagues.map((league) => league.id), ['league-north']);
    });

    test('staff does not see another team merely because it shares a hub', () {
      final contact = user(
        id: 'contact',
        role: UserRole.staff,
        teamIds: const ['team-north-b'],
      );
      final visible = visibleContactAssignments(
        viewer: user(
          id: 'staff',
          role: UserRole.staff,
          teamIds: const ['team-north-a'],
        ),
        contact: contact,
        leagues: leagues,
        hubs: hubs,
        teams: teams,
      );

      expect(visible.hubs.map((hub) => hub.id), ['hub-north']);
      expect(visible.teams, isEmpty);
      expect(visible.hasHiddenTeams, isTrue);
    });
  });

  group('contactDirectoryScope', () {
    test('manager filters include every team in a managed hub', () {
      final scope = contactDirectoryScope(
        viewer: user(
          id: 'manager',
          role: UserRole.managerAdmin,
          hubIds: const ['hub-north'],
        ),
        hubs: hubs,
        teams: teams,
      );

      expect(scope.hubs.map((hub) => hub.id), ['hub-north']);
      expect(
          scope.teams.map((team) => team.id), ['team-north-a', 'team-north-b']);
    });

    test('staff filters include only assigned teams', () {
      final scope = contactDirectoryScope(
        viewer: user(
          id: 'staff',
          role: UserRole.staff,
          teamIds: const ['team-north-a'],
        ),
        hubs: hubs,
        teams: teams,
      );

      expect(scope.hubs.map((hub) => hub.id), ['hub-north']);
      expect(scope.teams.map((team) => team.id), ['team-north-a']);
    });
  });
}
