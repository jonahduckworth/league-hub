import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';

void main() {
  group('AppUser', () {
    final testDate = DateTime(2024, 1, 1, 0, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'user1',
          'email': 'user@example.com',
          'displayName': 'John Doe',
          'avatarUrl': 'https://example.com/avatar.png',
          'role': 'superAdmin',
          'orgId': 'org1',
          'hubIds': ['hub1', 'hub2'],
          'teamIds': ['team1'],
          'createdAt': testDateStr,
          'isActive': true,
        };

        final user = AppUser.fromJson(json);

        expect(user.id, 'user1');
        expect(user.email, 'user@example.com');
        expect(user.displayName, 'John Doe');
        expect(user.avatarUrl, 'https://example.com/avatar.png');
        expect(user.role, UserRole.superAdmin);
        expect(user.orgId, 'org1');
        expect(user.hubIds, ['hub1', 'hub2']);
        expect(user.teamIds, ['team1']);
        expect(user.createdAt, testDate);
        expect(user.isActive, true);
      });

      test('parses all UserRole values', () {
        for (final role in UserRole.values) {
          final json = {
            'id': 'u1',
            'email': 'e@e.com',
            'displayName': 'N',
            'role': role.name,
            'hubIds': [],
            'teamIds': [],
            'createdAt': testDateStr,
            'isActive': true,
          };
          expect(AppUser.fromJson(json).role, role);
        }
      });

      test('defaults role to staff for unknown role string', () {
        final json = {
          'id': 'user1',
          'email': 'user@example.com',
          'displayName': 'John',
          'role': 'unknownRole',
          'hubIds': [],
          'teamIds': [],
          'createdAt': testDateStr,
          'isActive': true,
        };

        expect(AppUser.fromJson(json).role, UserRole.staff);
      });

      test('defaults hubIds and teamIds to empty lists', () {
        final json = {
          'id': 'user1',
          'email': 'user@example.com',
          'displayName': 'John',
          'role': 'staff',
          'createdAt': testDateStr,
          'isActive': true,
        };

        final user = AppUser.fromJson(json);

        expect(user.hubIds, isEmpty);
        expect(user.teamIds, isEmpty);
      });

      test('defaults isActive to true when not provided', () {
        final json = {
          'id': 'user1',
          'email': 'user@example.com',
          'displayName': 'John',
          'role': 'staff',
          'hubIds': [],
          'teamIds': [],
          'createdAt': testDateStr,
        };

        expect(AppUser.fromJson(json).isActive, true);
      });

      test('avatarUrl and orgId are null when not provided', () {
        final json = {
          'id': 'user1',
          'email': 'user@example.com',
          'displayName': 'John',
          'role': 'staff',
          'hubIds': [],
          'teamIds': [],
          'createdAt': testDateStr,
          'isActive': true,
        };

        final user = AppUser.fromJson(json);

        expect(user.avatarUrl, isNull);
        expect(user.orgId, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final user = AppUser(
          id: 'user1',
          email: 'user@example.com',
          displayName: 'Jane Doe',
          avatarUrl: 'https://example.com/avatar.png',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: ['hub1'],
          teamIds: ['team1', 'team2'],
          createdAt: testDate,
          isActive: false,
        );

        final json = user.toJson();

        expect(json['id'], 'user1');
        expect(json['email'], 'user@example.com');
        expect(json['displayName'], 'Jane Doe');
        expect(json['avatarUrl'], 'https://example.com/avatar.png');
        expect(json['role'], 'managerAdmin');
        expect(json['orgId'], 'org1');
        expect(json['hubIds'], ['hub1']);
        expect(json['teamIds'], ['team1', 'team2']);
        expect(json['createdAt'], testDateStr);
        expect(json['isActive'], false);
      });
    });

    group('roleLabel', () {
      test('returns correct label for each role', () {
        final labels = {
          UserRole.platformOwner: 'Platform Owner',
          UserRole.superAdmin: 'Super Admin',
          UserRole.managerAdmin: 'Manager Admin',
          UserRole.staff: 'Staff',
        };

        for (final entry in labels.entries) {
          final user = AppUser(
            id: 'u',
            email: 'e@e.com',
            displayName: 'N',
            role: entry.key,
            hubIds: [],
            teamIds: [],
            createdAt: testDate,
            isActive: true,
          );
          expect(user.roleLabel, entry.value);
        }
      });
    });

    test('roundtrip preserves all data', () {
      final original = AppUser(
        id: 'user1',
        email: 'test@test.com',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/pic.jpg',
        role: UserRole.superAdmin,
        orgId: 'org42',
        hubIds: ['h1', 'h2'],
        teamIds: ['t1'],
        createdAt: testDate,
        isActive: true,
      );

      final restored = AppUser.fromJson({'id': original.id, ...original.toJson()});

      expect(restored.id, original.id);
      expect(restored.email, original.email);
      expect(restored.displayName, original.displayName);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.role, original.role);
      expect(restored.orgId, original.orgId);
      expect(restored.hubIds, original.hubIds);
      expect(restored.teamIds, original.teamIds);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isActive, original.isActive);
    });
  });
}
