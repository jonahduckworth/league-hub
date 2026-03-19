import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/hub.dart';

void main() {
  group('Hub', () {
    final testDate = DateTime(2024, 5, 1, 12, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'hub1',
          'leagueId': 'league1',
          'orgId': 'org1',
          'name': 'North Hub',
          'location': 'City Park',
          'createdAt': testDateStr,
        };

        final hub = Hub.fromJson(json);

        expect(hub.id, 'hub1');
        expect(hub.leagueId, 'league1');
        expect(hub.orgId, 'org1');
        expect(hub.name, 'North Hub');
        expect(hub.location, 'City Park');
        expect(hub.createdAt, testDate);
      });

      test('location is null when not provided', () {
        final json = {
          'id': 'hub1',
          'leagueId': 'league1',
          'orgId': 'org1',
          'name': 'North Hub',
          'createdAt': testDateStr,
        };

        final hub = Hub.fromJson(json);

        expect(hub.location, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final hub = Hub(
          id: 'hub1',
          leagueId: 'league1',
          orgId: 'org1',
          name: 'North Hub',
          location: 'City Park',
          createdAt: testDate,
        );

        final json = hub.toJson();

        expect(json['id'], 'hub1');
        expect(json['leagueId'], 'league1');
        expect(json['orgId'], 'org1');
        expect(json['name'], 'North Hub');
        expect(json['location'], 'City Park');
        expect(json['createdAt'], testDateStr);
      });

      test('serializes null location', () {
        final hub = Hub(
          id: 'hub1',
          leagueId: 'league1',
          orgId: 'org1',
          name: 'North Hub',
          createdAt: testDate,
        );

        expect(hub.toJson()['location'], isNull);
      });
    });

    test('roundtrip preserves all data', () {
      final original = Hub(
        id: 'hub1',
        leagueId: 'league1',
        orgId: 'org1',
        name: 'South Hub',
        location: 'Sports Complex',
        createdAt: testDate,
      );

      final restored = Hub.fromJson({'id': original.id, ...original.toJson()});

      expect(restored.id, original.id);
      expect(restored.leagueId, original.leagueId);
      expect(restored.orgId, original.orgId);
      expect(restored.name, original.name);
      expect(restored.location, original.location);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
