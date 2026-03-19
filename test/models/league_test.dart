import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/league.dart';

void main() {
  group('League', () {
    final testDate = DateTime(2024, 3, 20, 8, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'league1',
          'orgId': 'org1',
          'name': 'Premier League',
          'abbreviation': 'PL',
          'description': 'Top tier league',
          'createdAt': testDateStr,
        };

        final league = League.fromJson(json);

        expect(league.id, 'league1');
        expect(league.orgId, 'org1');
        expect(league.name, 'Premier League');
        expect(league.abbreviation, 'PL');
        expect(league.description, 'Top tier league');
        expect(league.createdAt, testDate);
      });

      test('description is null when not provided', () {
        final json = {
          'id': 'league1',
          'orgId': 'org1',
          'name': 'Premier League',
          'abbreviation': 'PL',
          'createdAt': testDateStr,
        };

        final league = League.fromJson(json);

        expect(league.description, isNull);
      });

      test('description is null when explicitly null', () {
        final json = {
          'id': 'league1',
          'orgId': 'org1',
          'name': 'Premier League',
          'abbreviation': 'PL',
          'description': null,
          'createdAt': testDateStr,
        };

        final league = League.fromJson(json);

        expect(league.description, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final league = League(
          id: 'league1',
          orgId: 'org1',
          name: 'Premier League',
          abbreviation: 'PL',
          description: 'Top tier league',
          createdAt: testDate,
        );

        final json = league.toJson();

        expect(json['id'], 'league1');
        expect(json['orgId'], 'org1');
        expect(json['name'], 'Premier League');
        expect(json['abbreviation'], 'PL');
        expect(json['description'], 'Top tier league');
        expect(json['createdAt'], testDateStr);
      });

      test('serializes null description', () {
        final league = League(
          id: 'league1',
          orgId: 'org1',
          name: 'Premier League',
          abbreviation: 'PL',
          createdAt: testDate,
        );

        final json = league.toJson();

        expect(json['description'], isNull);
      });
    });

    test('roundtrip preserves all data', () {
      final original = League(
        id: 'league1',
        orgId: 'org1',
        name: 'Championship',
        abbreviation: 'CHAMP',
        description: 'Second tier',
        createdAt: testDate,
      );

      final restored = League.fromJson({
        'id': original.id,
        ...original.toJson(),
      });

      expect(restored.id, original.id);
      expect(restored.orgId, original.orgId);
      expect(restored.name, original.name);
      expect(restored.abbreviation, original.abbreviation);
      expect(restored.description, original.description);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
