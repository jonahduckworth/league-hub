import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/scope_defaults.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';

void main() {
  AppUser user({
    required UserRole role,
    List<String> leagueIds = const [],
  }) =>
      AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'Test User',
        role: role,
        orgId: 'org-1',
        hubIds: const [],
        leagueIds: leagueIds,
        teamIds: const [],
        createdAt: DateTime(2024),
        isActive: true,
      );

  final leagues = [
    League(
      id: 'league-1',
      orgId: 'org-1',
      name: 'Spring',
      abbreviation: 'SPR',
      createdAt: DateTime(2024),
    ),
    League(
      id: 'league-2',
      orgId: 'org-1',
      name: 'Winter',
      abbreviation: 'WIN',
      createdAt: DateTime(2024),
    ),
  ];

  test('superAdmin can manage all leagues', () {
    final result = manageableLeaguesForUser(
      user(role: UserRole.superAdmin),
      leagues,
    );

    expect(result.map((league) => league.id), ['league-1', 'league-2']);
  });

  test('manager with league assignments only sees assigned leagues', () {
    final result = manageableLeaguesForUser(
      user(role: UserRole.managerAdmin, leagueIds: ['league-2']),
      leagues,
    );

    expect(result.map((league) => league.id), ['league-2']);
  });

  test('singleManageableLeagueId returns the only manageable league id', () {
    final result = singleManageableLeagueId(
      user(role: UserRole.staff, leagueIds: ['league-1']),
      leagues,
    );

    expect(result, 'league-1');
  });

  test('singleManageableLeagueId returns null for multiple leagues', () {
    final result = singleManageableLeagueId(
      user(role: UserRole.superAdmin),
      leagues,
    );

    expect(result, isNull);
  });
}
