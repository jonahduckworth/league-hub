import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/schedule_event.dart';

void main() {
  final json = <String, dynamic>{
    'id': 'game-1',
    'orgId': 'org-1',
    'sourceUid': 'leaguegame-1@rampinteractive.com',
    'sourceSeasonId': '12322',
    'firstTeamId': 'wolves',
    'secondTeamId': 'rockies',
    'teamIds': ['wolves', 'rockies'],
    'hubIds': ['hub-1', 'hub-2'],
    'leagueIds': ['jphl'],
    'division': '17U AAA',
    'title': '17U AAA - Wolves HC vs 17U AAA - Calgary Rockies',
    'firstTeamName': '17U AAA - Wolves HC',
    'secondTeamName': '17U AAA - Calgary Rockies',
    'startsAt': '2026-09-10T01:00:00.000Z',
    'endsAt': '2026-09-10T03:00:00.000Z',
    'timezone': 'America/Edmonton',
    'location': 'Great Plains Arena',
    'description': 'Final: 2 - 1',
    'status': 'final',
    'firstScore': 2,
    'secondScore': 1,
    'isActive': true,
  };

  test('parses schedule data and presents clean team names', () {
    final event = ScheduleEvent.fromJson(json);

    expect(event.status, ScheduleEventStatus.finalGame);
    expect(event.sourceSeasonId, '12322');
    expect(event.firstTeamId, 'wolves');
    expect(event.secondTeamId, 'rockies');
    expect(event.cleanFirstTeamName, 'Wolves HC');
    expect(event.cleanSecondTeamName, 'Calgary Rockies');
    expect(event.firstScore, 2);
    expect(event.toJson()['status'], 'final');
    expect(event.toJson()['sourceSeasonId'], '12322');
    expect(event.toJson()['firstTeamId'], 'wolves');
    expect(event.toJson()['secondTeamId'], 'rockies');
  });

  test('accepts legacy schedule data without season metadata', () {
    final legacy = ScheduleEvent.fromJson({...json}
      ..remove('sourceSeasonId')
      ..remove('firstTeamId')
      ..remove('secondTeamId'));

    expect(legacy.sourceSeasonId, isNull);
    expect(legacy.firstTeamId, isNull);
    expect(legacy.secondTeamId, isNull);
  });

  test('identifies only active future games as upcoming', () {
    final event = ScheduleEvent.fromJson(json);

    expect(event.isUpcomingAt(DateTime.utc(2026, 9, 1)), isTrue);
    expect(event.isUpcomingAt(DateTime.utc(2026, 9, 11)), isFalse);
    expect(
      ScheduleEvent.fromJson({...json, 'isActive': false})
          .isUpcomingAt(DateTime.utc(2026, 9, 1)),
      isFalse,
    );
  });
}
