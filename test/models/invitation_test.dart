import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/invitation.dart';

void main() {
  group('Invitation', () {
    final testDate = DateTime(2024, 10, 1, 8, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'inv1',
          'orgId': 'org1',
          'email': 'newuser@example.com',
          'displayName': 'New User',
          'role': 'managerAdmin',
          'hubIds': ['hub1', 'hub2'],
          'teamIds': ['team1'],
          'invitedBy': 'user1',
          'invitedByName': 'Admin',
          'createdAt': testDateStr,
          'status': 'pending',
          'token': 'abc123',
        };

        final inv = Invitation.fromJson(json);

        expect(inv.id, 'inv1');
        expect(inv.orgId, 'org1');
        expect(inv.email, 'newuser@example.com');
        expect(inv.displayName, 'New User');
        expect(inv.role, 'managerAdmin');
        expect(inv.hubIds, ['hub1', 'hub2']);
        expect(inv.teamIds, ['team1']);
        expect(inv.invitedBy, 'user1');
        expect(inv.invitedByName, 'Admin');
        expect(inv.createdAt, testDate);
        expect(inv.status, InvitationStatus.pending);
        expect(inv.token, 'abc123');
      });

      test('parses all InvitationStatus values', () {
        for (final status in InvitationStatus.values) {
          final json = {
            'id': 'inv1',
            'orgId': 'org1',
            'email': 'e@e.com',
            'role': 'staff',
            'hubIds': [],
            'teamIds': [],
            'invitedBy': 'u1',
            'invitedByName': 'N',
            'createdAt': testDateStr,
            'status': status.name,
            'token': 'tok',
          };
          expect(Invitation.fromJson(json).status, status);
        }
      });

      test('defaults status to pending for unknown status string', () {
        final json = {
          'id': 'inv1',
          'orgId': 'org1',
          'email': 'e@e.com',
          'role': 'staff',
          'hubIds': [],
          'teamIds': [],
          'invitedBy': 'u1',
          'invitedByName': 'N',
          'createdAt': testDateStr,
          'status': 'unknown',
          'token': 'tok',
        };

        expect(Invitation.fromJson(json).status, InvitationStatus.pending);
      });

      test('defaults hubIds and teamIds to empty lists', () {
        final json = {
          'id': 'inv1',
          'orgId': 'org1',
          'email': 'e@e.com',
          'role': 'staff',
          'invitedBy': 'u1',
          'invitedByName': 'N',
          'createdAt': testDateStr,
          'status': 'pending',
          'token': 'tok',
        };

        final inv = Invitation.fromJson(json);

        expect(inv.hubIds, isEmpty);
        expect(inv.teamIds, isEmpty);
      });

      test('defaults orgId to empty string', () {
        final json = {
          'id': 'inv1',
          'email': 'e@e.com',
          'role': 'staff',
          'hubIds': [],
          'teamIds': [],
          'invitedBy': 'u1',
          'invitedByName': 'N',
          'createdAt': testDateStr,
          'status': 'pending',
          'token': 'tok',
        };

        expect(Invitation.fromJson(json).orgId, '');
      });

      test('displayName is null when not provided', () {
        final json = {
          'id': 'inv1',
          'orgId': 'org1',
          'email': 'e@e.com',
          'role': 'staff',
          'hubIds': [],
          'teamIds': [],
          'invitedBy': 'u1',
          'invitedByName': 'N',
          'createdAt': testDateStr,
          'status': 'pending',
          'token': 'tok',
        };

        expect(Invitation.fromJson(json).displayName, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final inv = Invitation(
          id: 'inv1',
          orgId: 'org1',
          email: 'user@example.com',
          displayName: 'Test User',
          role: 'staff',
          hubIds: ['h1'],
          teamIds: ['t1', 't2'],
          invitedBy: 'admin1',
          invitedByName: 'Admin',
          createdAt: testDate,
          status: InvitationStatus.accepted,
          token: 'mytoken',
        );

        final json = inv.toJson();

        expect(json['orgId'], 'org1');
        expect(json['email'], 'user@example.com');
        expect(json['displayName'], 'Test User');
        expect(json['role'], 'staff');
        expect(json['hubIds'], ['h1']);
        expect(json['teamIds'], ['t1', 't2']);
        expect(json['invitedBy'], 'admin1');
        expect(json['invitedByName'], 'Admin');
        expect(json['createdAt'], testDateStr);
        expect(json['status'], 'accepted');
        expect(json['token'], 'mytoken');
      });

      test('id is NOT included in toJson', () {
        final inv = Invitation(
          id: 'inv1',
          orgId: 'org1',
          email: 'e@e.com',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'u1',
          invitedByName: 'N',
          createdAt: testDate,
          status: InvitationStatus.pending,
          token: 'tok',
        );

        expect(inv.toJson().containsKey('id'), false);
      });
    });

    group('roleLabel', () {
      test('returns correct labels', () {
        final labels = {
          'superAdmin': 'Super Admin',
          'managerAdmin': 'Manager Admin',
          'staff': 'Staff',
          'unknownRole': 'unknownRole',
        };

        for (final entry in labels.entries) {
          final inv = Invitation(
            id: 'inv1',
            orgId: 'org1',
            email: 'e@e.com',
            role: entry.key,
            hubIds: [],
            teamIds: [],
            invitedBy: 'u1',
            invitedByName: 'N',
            createdAt: testDate,
            status: InvitationStatus.pending,
            token: 'tok',
          );
          expect(inv.roleLabel, entry.value);
        }
      });
    });
  });
}
