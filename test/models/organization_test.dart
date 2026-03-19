import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/organization.dart';

void main() {
  group('Organization', () {
    final testDate = DateTime(2024, 1, 15, 10, 30);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'org123',
          'name': 'Test Org',
          'logoUrl': 'https://example.com/logo.png',
          'primaryColor': '#FF0000',
          'secondaryColor': '#00FF00',
          'accentColor': '#0000FF',
          'createdAt': testDateStr,
          'ownerId': 'user456',
        };

        final org = Organization.fromJson(json);

        expect(org.id, 'org123');
        expect(org.name, 'Test Org');
        expect(org.logoUrl, 'https://example.com/logo.png');
        expect(org.primaryColor, '#FF0000');
        expect(org.secondaryColor, '#00FF00');
        expect(org.accentColor, '#0000FF');
        expect(org.createdAt, testDate);
        expect(org.ownerId, 'user456');
      });

      test('uses default colors when not provided', () {
        final json = {
          'id': 'org123',
          'name': 'Test Org',
          'createdAt': testDateStr,
          'ownerId': 'user456',
        };

        final org = Organization.fromJson(json);

        expect(org.primaryColor, '#1A3A5C');
        expect(org.secondaryColor, '#2E75B6');
        expect(org.accentColor, '#4DA3FF');
      });

      test('logoUrl is null when not provided', () {
        final json = {
          'id': 'org123',
          'name': 'Test Org',
          'createdAt': testDateStr,
          'ownerId': 'user456',
        };

        final org = Organization.fromJson(json);

        expect(org.logoUrl, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final org = Organization(
          id: 'org123',
          name: 'Test Org',
          logoUrl: 'https://example.com/logo.png',
          primaryColor: '#FF0000',
          secondaryColor: '#00FF00',
          accentColor: '#0000FF',
          createdAt: testDate,
          ownerId: 'user456',
        );

        final json = org.toJson();

        expect(json['id'], 'org123');
        expect(json['name'], 'Test Org');
        expect(json['logoUrl'], 'https://example.com/logo.png');
        expect(json['primaryColor'], '#FF0000');
        expect(json['secondaryColor'], '#00FF00');
        expect(json['accentColor'], '#0000FF');
        expect(json['createdAt'], testDateStr);
        expect(json['ownerId'], 'user456');
      });

      test('serializes null logoUrl', () {
        final org = Organization(
          id: 'org123',
          name: 'Test Org',
          primaryColor: '#FF0000',
          secondaryColor: '#00FF00',
          accentColor: '#0000FF',
          createdAt: testDate,
          ownerId: 'user456',
        );

        final json = org.toJson();

        expect(json['logoUrl'], isNull);
      });
    });

    test('roundtrip: toJson then fromJson preserves all data', () {
      final original = Organization(
        id: 'org123',
        name: 'Roundtrip Org',
        logoUrl: 'https://example.com/logo.png',
        primaryColor: '#AABBCC',
        secondaryColor: '#DDEEFF',
        accentColor: '#112233',
        createdAt: testDate,
        ownerId: 'owner789',
      );

      final restored = Organization.fromJson({
        'id': original.id,
        ...original.toJson(),
      });

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.logoUrl, original.logoUrl);
      expect(restored.primaryColor, original.primaryColor);
      expect(restored.secondaryColor, original.secondaryColor);
      expect(restored.accentColor, original.accentColor);
      expect(restored.createdAt, original.createdAt);
      expect(restored.ownerId, original.ownerId);
    });
  });
}
