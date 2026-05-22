import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/policy.dart';

void main() {
  group('PolicyVersion', () {
    final testDate = DateTime(2024, 8, 10, 11, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly using url key', () {
        final json = {
          'url': 'https://example.com/file.pdf',
          'version': 1,
          'uploadedAt': testDateStr,
          'uploadedBy': 'user1',
          'uploadedByName': 'Alice',
          'fileSize': 2048,
        };

        final version = PolicyVersion.fromJson(json);

        expect(version.fileUrl, 'https://example.com/file.pdf');
        expect(version.version, 1);
        expect(version.uploadedAt, testDate);
        expect(version.uploadedBy, 'user1');
        expect(version.uploadedByName, 'Alice');
        expect(version.fileSize, 2048);
      });

      test('falls back to fileUrl key if url is missing', () {
        final json = {
          'fileUrl': 'https://example.com/file-v2.pdf',
          'version': 2,
          'uploadedAt': testDateStr,
          'uploadedBy': 'user1',
          'uploadedByName': 'Alice',
          'fileSize': 4096,
        };

        final version = PolicyVersion.fromJson(json);

        expect(version.fileUrl, 'https://example.com/file-v2.pdf');
      });

      test('defaults version to 1 when not provided', () {
        final json = {
          'url': 'https://example.com/file.pdf',
          'uploadedAt': testDateStr,
          'uploadedBy': 'user1',
          'uploadedByName': 'Alice',
          'fileSize': 1024,
        };

        expect(PolicyVersion.fromJson(json).version, 1);
      });

      test('defaults uploadedBy/Name to empty string when not provided', () {
        final json = {
          'url': 'https://example.com/file.pdf',
          'version': 1,
          'uploadedAt': testDateStr,
          'fileSize': 1024,
        };

        final version = PolicyVersion.fromJson(json);

        expect(version.uploadedBy, '');
        expect(version.uploadedByName, '');
      });

      test('defaults fileSize to 0 when not provided', () {
        final json = {
          'url': 'https://example.com/file.pdf',
          'version': 1,
          'uploadedAt': testDateStr,
          'uploadedBy': 'user1',
          'uploadedByName': 'Alice',
        };

        expect(PolicyVersion.fromJson(json).fileSize, 0);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final version = PolicyVersion(
          fileUrl: 'https://example.com/policy.pdf',
          version: 3,
          uploadedAt: testDate,
          uploadedBy: 'user1',
          uploadedByName: 'Bob',
          fileSize: 8192,
        );

        final json = version.toJson();

        expect(json['url'], 'https://example.com/policy.pdf');
        expect(json['version'], 3);
        expect(json['uploadedAt'], testDateStr);
        expect(json['uploadedBy'], 'user1');
        expect(json['uploadedByName'], 'Bob');
        expect(json['fileSize'], 8192);
      });
    });
  });

  group('Policy', () {
    final testDate = DateTime(2024, 9, 5, 16, 0);
    final testDateStr = testDate.toIso8601String();
    final updateDate = DateTime(2024, 9, 10, 10, 0);
    final updateDateStr = updateDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'policy1',
          'orgId': 'org1',
          'leagueId': 'league1',
          'hubId': 'hub1',
          'name': 'Player Handbook',
          'fileUrl': 'https://example.com/handbook.pdf',
          'fileType': 'pdf',
          'fileSize': 102400,
          'category': 'Handbooks',
          'uploadedBy': 'user1',
          'uploadedByName': 'Admin',
          'versions': [
            {
              'url': 'https://example.com/handbook.pdf',
              'version': 1,
              'uploadedAt': testDateStr,
              'uploadedBy': 'user1',
              'uploadedByName': 'Admin',
              'fileSize': 102400,
            }
          ],
          'createdAt': testDateStr,
          'updatedAt': updateDateStr,
        };

        final policy = Policy.fromJson(json);

        expect(policy.id, 'policy1');
        expect(policy.orgId, 'org1');
        expect(policy.leagueId, 'league1');
        expect(policy.hubId, 'hub1');
        expect(policy.name, 'Player Handbook');
        expect(policy.fileUrl, 'https://example.com/handbook.pdf');
        expect(policy.fileType, 'pdf');
        expect(policy.fileSize, 102400);
        expect(policy.category, 'Handbooks');
        expect(policy.uploadedBy, 'user1');
        expect(policy.uploadedByName, 'Admin');
        expect(policy.versions.length, 1);
        expect(policy.createdAt, testDate);
        expect(policy.updatedAt, updateDate);
      });

      test('leagueId and hubId are null when not provided', () {
        final json = {
          'id': 'policy1',
          'orgId': 'org1',
          'name': 'Rules',
          'fileUrl': 'https://example.com/rules.pdf',
          'fileType': 'pdf',
          'fileSize': 1024,
          'category': 'Rules',
          'uploadedBy': 'user1',
          'uploadedByName': 'Admin',
          'versions': [],
          'createdAt': testDateStr,
          'updatedAt': updateDateStr,
        };

        final policy = Policy.fromJson(json);

        expect(policy.leagueId, isNull);
        expect(policy.hubId, isNull);
      });

      test('defaults versions to empty list', () {
        final json = {
          'id': 'policy1',
          'orgId': 'org1',
          'name': 'Rules',
          'fileUrl': 'https://example.com/rules.pdf',
          'fileType': 'pdf',
          'fileSize': 1024,
          'category': 'Rules',
          'uploadedBy': 'user1',
          'uploadedByName': 'Admin',
          'createdAt': testDateStr,
          'updatedAt': updateDateStr,
        };

        expect(Policy.fromJson(json).versions, isEmpty);
      });

      test('defaults orgId to empty string', () {
        final json = {
          'id': 'policy1',
          'name': 'Rules',
          'fileUrl': 'https://example.com/rules.pdf',
          'fileType': 'pdf',
          'fileSize': 1024,
          'category': 'Rules',
          'uploadedBy': 'user1',
          'uploadedByName': 'Admin',
          'versions': [],
          'createdAt': testDateStr,
          'updatedAt': updateDateStr,
        };

        expect(Policy.fromJson(json).orgId, '');
      });

      test('defaults fileSize to 0', () {
        final json = {
          'id': 'policy1',
          'orgId': 'org1',
          'name': 'Rules',
          'fileUrl': 'https://example.com/rules.pdf',
          'fileType': 'pdf',
          'category': 'Rules',
          'uploadedBy': 'user1',
          'uploadedByName': 'Admin',
          'versions': [],
          'createdAt': testDateStr,
          'updatedAt': updateDateStr,
        };

        expect(Policy.fromJson(json).fileSize, 0);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final version = PolicyVersion(
          fileUrl: 'https://example.com/file.pdf',
          version: 1,
          uploadedAt: testDate,
          uploadedBy: 'user1',
          uploadedByName: 'Alice',
          fileSize: 512,
        );
        final policy = Policy(
          id: 'policy1',
          orgId: 'org1',
          leagueId: 'l1',
          hubId: 'h1',
          name: 'Test Policy',
          fileUrl: 'https://example.com/file.pdf',
          fileType: 'pdf',
          fileSize: 512,
          category: 'Policy',
          uploadedBy: 'user1',
          uploadedByName: 'Alice',
          versions: [version],
          createdAt: testDate,
          updatedAt: updateDate,
        );

        final json = policy.toJson();

        expect(json['orgId'], 'org1');
        expect(json['leagueId'], 'l1');
        expect(json['hubId'], 'h1');
        expect(json['name'], 'Test Policy');
        expect(json['fileUrl'], 'https://example.com/file.pdf');
        expect(json['fileType'], 'pdf');
        expect(json['fileSize'], 512);
        expect(json['category'], 'Policy');
        expect(json['uploadedBy'], 'user1');
        expect(json['uploadedByName'], 'Alice');
        expect(json['versions'].length, 1);
        expect(json['createdAt'], testDateStr);
        expect(json['updatedAt'], updateDateStr);
      });

      test('id is NOT included in toJson (Firestore stores it separately)', () {
        final policy = Policy(
          id: 'policy1',
          orgId: 'org1',
          name: 'Test',
          fileUrl: 'https://example.com/f.pdf',
          fileType: 'pdf',
          fileSize: 100,
          category: 'General',
          uploadedBy: 'u1',
          uploadedByName: 'U',
          versions: [],
          createdAt: testDate,
          updatedAt: updateDate,
        );

        expect(policy.toJson().containsKey('id'), false);
      });
    });
  });
}
