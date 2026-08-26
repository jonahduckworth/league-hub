import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/chat_room_functions_service.dart';

void main() {
  Team team(String id, String hubId) => Team(
        id: id,
        hubId: hubId,
        leagueId: 'league-1',
        orgId: 'org-1',
        name: id,
        createdAt: DateTime(2026),
      );

  test('multi-team callable request preserves every Team and Hub pair', () {
    expect(
      multiTeamEventRoomRequest(
        orgId: 'org-1',
        name: '  Provincial Showcase  ',
        leagueId: 'league-1',
        teams: [team('team-ab', 'hub-ab'), team('team-bc', 'hub-bc')],
        roomIconName: 'event',
      ),
      {
        'orgId': 'org-1',
        'name': 'Provincial Showcase',
        'leagueId': 'league-1',
        'teams': [
          {'hubId': 'hub-ab', 'teamId': 'team-ab'},
          {'hubId': 'hub-bc', 'teamId': 'team-bc'},
        ],
        'roomIconName': 'event',
      },
    );
  });

  test('multi-team callable request enforces the published limit', () {
    expect(
      () => multiTeamEventRoomRequest(
        orgId: 'org-1',
        name: 'Showcase',
        leagueId: 'league-1',
        teams: const [],
        roomIconName: 'event',
      ),
      throwsArgumentError,
    );
  });
}
