import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/team.dart';

void main() {
  group('Team', () {
    final testDate = DateTime(2024, 2, 10, 9, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'team1',
          'hubId': 'hub1',
          'leagueId': 'league1',
          'orgId': 'org1',
          'name': 'Red Hawks',
          'ageGroup': 'U12',
          'division': 'Division A',
          'createdAt': testDateStr,
        };

        final team = Team.fromJson(json);

        expect(team.id, 'team1');
        expect(team.hubId, 'hub1');
        expect(team.leagueId, 'league1');
        expect(team.orgId, 'org1');
        expect(team.name, 'Red Hawks');
        expect(team.ageGroup, 'U12');
        expect(team.division, 'Division A');
        expect(team.createdAt, testDate);
      });

      test('ageGroup and division are null when not provided', () {
        final json = {
          'id': 'team1',
          'hubId': 'hub1',
          'leagueId': 'league1',
          'orgId': 'org1',
          'name': 'Red Hawks',
          'createdAt': testDateStr,
        };

        final team = Team.fromJson(json);

        expect(team.ageGroup, isNull);
        expect(team.division, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final team = Team(
          id: 'team1',
          hubId: 'hub1',
          leagueId: 'league1',
          orgId: 'org1',
          name: 'Blue Eagles',
          ageGroup: 'U14',
          division: 'Division B',
          createdAt: testDate,
        );

        final json = team.toJson();

        expect(json['id'], 'team1');
        expect(json['hubId'], 'hub1');
        expect(json['leagueId'], 'league1');
        expect(json['orgId'], 'org1');
        expect(json['name'], 'Blue Eagles');
        expect(json['ageGroup'], 'U14');
        expect(json['division'], 'Division B');
        expect(json['createdAt'], testDateStr);
      });

      test('serializes null optional fields', () {
        final team = Team(
          id: 'team1',
          hubId: 'hub1',
          leagueId: 'league1',
          orgId: 'org1',
          name: 'Blue Eagles',
          createdAt: testDate,
        );

        final json = team.toJson();

        expect(json['ageGroup'], isNull);
        expect(json['division'], isNull);
      });
    });

    test('roundtrip preserves all data', () {
      final original = Team(
        id: 'team1',
        hubId: 'hub1',
        leagueId: 'league1',
        orgId: 'org1',
        name: 'Green Wolves',
        ageGroup: 'U16',
        division: 'Premier',
        createdAt: testDate,
      );

      final restored = Team.fromJson({'id': original.id, ...original.toJson()});

      expect(restored.id, original.id);
      expect(restored.hubId, original.hubId);
      expect(restored.leagueId, original.leagueId);
      expect(restored.orgId, original.orgId);
      expect(restored.name, original.name);
      expect(restored.ageGroup, original.ageGroup);
      expect(restored.division, original.division);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
