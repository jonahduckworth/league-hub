import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';

void main() {
  group('Announcement', () {
    final testDate = DateTime(2024, 4, 1, 9, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'ann1',
          'orgId': 'org1',
          'scope': 'league',
          'leagueId': 'league1',
          'hubId': null,
          'title': 'Season Start',
          'body': 'The season begins next Monday.',
          'authorId': 'user1',
          'authorName': 'Coach Smith',
          'authorRole': 'Manager',
          'attachments': [
            {'name': 'schedule.pdf', 'url': 'https://example.com/s.pdf'}
          ],
          'isPinned': true,
          'createdAt': testDateStr,
        };

        final ann = Announcement.fromJson(json);

        expect(ann.id, 'ann1');
        expect(ann.orgId, 'org1');
        expect(ann.scope, AnnouncementScope.league);
        expect(ann.leagueId, 'league1');
        expect(ann.hubId, isNull);
        expect(ann.title, 'Season Start');
        expect(ann.body, 'The season begins next Monday.');
        expect(ann.authorId, 'user1');
        expect(ann.authorName, 'Coach Smith');
        expect(ann.authorRole, 'Manager');
        expect(ann.attachments.length, 1);
        expect(ann.isPinned, true);
        expect(ann.createdAt, testDate);
      });

      test('parses all AnnouncementScope values', () {
        for (final scope in AnnouncementScope.values) {
          final json = {
            'id': 'a1',
            'orgId': 'o1',
            'scope': scope.name,
            'title': 'T',
            'body': 'B',
            'authorId': 'u1',
            'authorName': 'N',
            'authorRole': 'Staff',
            'attachments': [],
            'isPinned': false,
            'createdAt': testDateStr,
          };
          expect(Announcement.fromJson(json).scope, scope);
        }
      });

      test('defaults scope to orgWide for unknown scope string', () {
        final json = {
          'id': 'ann1',
          'orgId': 'org1',
          'scope': 'unknown',
          'title': 'T',
          'body': 'B',
          'authorId': 'u1',
          'authorName': 'N',
          'authorRole': 'Staff',
          'attachments': [],
          'isPinned': false,
          'createdAt': testDateStr,
        };

        expect(Announcement.fromJson(json).scope, AnnouncementScope.orgWide);
      });

      test('defaults attachments to empty list when not provided', () {
        final json = {
          'id': 'ann1',
          'orgId': 'org1',
          'scope': 'orgWide',
          'title': 'T',
          'body': 'B',
          'authorId': 'u1',
          'authorName': 'N',
          'authorRole': 'Staff',
          'isPinned': false,
          'createdAt': testDateStr,
        };

        expect(Announcement.fromJson(json).attachments, isEmpty);
      });

      test('defaults isPinned to false when not provided', () {
        final json = {
          'id': 'ann1',
          'orgId': 'org1',
          'scope': 'orgWide',
          'title': 'T',
          'body': 'B',
          'authorId': 'u1',
          'authorName': 'N',
          'authorRole': 'Staff',
          'attachments': [],
          'createdAt': testDateStr,
        };

        expect(Announcement.fromJson(json).isPinned, false);
      });

      test('uses DateTime.now() when createdAt is null', () {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        final json = {
          'id': 'ann1',
          'orgId': 'org1',
          'scope': 'orgWide',
          'title': 'T',
          'body': 'B',
          'authorId': 'u1',
          'authorName': 'N',
          'authorRole': 'Staff',
          'attachments': [],
          'isPinned': false,
          'createdAt': null,
        };
        final after = DateTime.now().add(const Duration(seconds: 1));

        final ann = Announcement.fromJson(json);

        expect(ann.createdAt.isAfter(before), true);
        expect(ann.createdAt.isBefore(after), true);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final ann = Announcement(
          id: 'ann1',
          orgId: 'org1',
          scope: AnnouncementScope.hub,
          leagueId: 'l1',
          hubId: 'h1',
          title: 'Test',
          body: 'Body text',
          authorId: 'u1',
          authorName: 'Admin',
          authorRole: 'Super Admin',
          attachments: [
            {'name': 'file.pdf', 'url': 'https://example.com/f.pdf'}
          ],
          isPinned: false,
          createdAt: testDate,
        );

        final json = ann.toJson();

        expect(json['id'], 'ann1');
        expect(json['orgId'], 'org1');
        expect(json['scope'], 'hub');
        expect(json['leagueId'], 'l1');
        expect(json['hubId'], 'h1');
        expect(json['title'], 'Test');
        expect(json['body'], 'Body text');
        expect(json['authorId'], 'u1');
        expect(json['authorName'], 'Admin');
        expect(json['authorRole'], 'Super Admin');
        expect(json['attachments'].length, 1);
        expect(json['isPinned'], false);
        expect(json['createdAt'], testDateStr);
      });
    });

    group('scopeLabel', () {
      test('returns correct label for each scope', () {
        final labels = {
          AnnouncementScope.orgWide: 'Org-Wide',
          AnnouncementScope.league: 'League',
          AnnouncementScope.hub: 'Hub',
        };

        for (final entry in labels.entries) {
          final ann = Announcement(
            id: 'a1',
            orgId: 'o1',
            scope: entry.key,
            title: 'T',
            body: 'B',
            authorId: 'u1',
            authorName: 'N',
            authorRole: 'Staff',
            attachments: [],
            isPinned: false,
            createdAt: testDate,
          );
          expect(ann.scopeLabel, entry.value);
        }
      });
    });

    test('roundtrip preserves all data', () {
      final original = Announcement(
        id: 'ann1',
        orgId: 'org1',
        scope: AnnouncementScope.league,
        leagueId: 'l1',
        title: 'Big News',
        body: 'Something important happened',
        authorId: 'u1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        attachments: [],
        isPinned: true,
        createdAt: testDate,
      );

      final restored = Announcement.fromJson({'id': original.id, ...original.toJson()});

      expect(restored.id, original.id);
      expect(restored.orgId, original.orgId);
      expect(restored.scope, original.scope);
      expect(restored.leagueId, original.leagueId);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.authorId, original.authorId);
      expect(restored.authorName, original.authorName);
      expect(restored.authorRole, original.authorRole);
      expect(restored.isPinned, original.isPinned);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
