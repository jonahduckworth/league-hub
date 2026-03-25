import 'dart:math' show log;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/services/firestore_service.dart';

void main() {
  group('Edge Case Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late FirestoreService fs;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      fs = FirestoreService(firestore: fakeDb);
    });

    test('1. Invitation expiry: old date returns null', () async {
      final orgId = 'org1';
      final oldDate = DateTime.now().subtract(Duration(days: 10));

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: 'owner1',
      );
      await fs.createOrganization(org);

      // Create old invitation
      final invitation = Invitation(
        id: 'inv1',
        orgId: orgId,
        email: 'test@example.com',
        role: 'staff',
        hubIds: [],
        teamIds: [],
        invitedBy: 'admin1',
        invitedByName: 'Admin',
        createdAt: oldDate,
        status: InvitationStatus.pending,
        token: '',
      );
      final token = await fs.createInvitation(orgId, invitation);

      // Try to retrieve expired invitation
      final fetchedInvite = await fs.getInvitationByToken(token, expiryDays: 7);
      expect(fetchedInvite, isNull);

      // Verify status updated to expired — invitation has auto-generated ID,
      // query by token instead of hardcoded ID
      final inviteSnap = await fakeDb
          .collection('organizations')
          .doc(orgId)
          .collection('invitations')
          .where('token', isEqualTo: token)
          .get();
      expect(inviteSnap.docs, isNotEmpty);
      expect(inviteSnap.docs.first['status'], 'expired');
    });

    test('2. Duplicate invitation to same email: both stored', () async {
      final orgId = 'org2';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: 'owner2',
      );
      await fs.createOrganization(org);

      // Create two invitations to same email
      final invitation = Invitation(
        id: '',
        orgId: orgId,
        email: 'user@example.com',
        role: 'staff',
        hubIds: [],
        teamIds: [],
        invitedBy: 'admin2',
        invitedByName: 'Admin',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        token: '',
      );
      final token1 = await fs.createInvitation(orgId, invitation);
      final token2 = await fs.createInvitation(orgId, invitation);

      expect(token1, isNotEmpty);
      expect(token2, isNotEmpty);
      expect(token1, isNot(token2));

      // Both should be retrievable
      final inv1 = await fs.getInvitationByToken(token1);
      final inv2 = await fs.getInvitationByToken(token2);
      expect(inv1, isNotNull);
      expect(inv2, isNotNull);
      expect(inv1!.email, inv2!.email);
    });

    test('3. Cascade delete empty league (no hubs): should not error', () async {
      final orgId = 'org3';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: 'owner3',
      );
      await fs.createOrganization(org);

      // Create empty league
      final leagueId = fs.newLeagueId(orgId);
      final league = League(
        id: leagueId,
        orgId: orgId,
        name: 'Empty League',
        abbreviation: 'EL',
        createdAt: DateTime.now(),
      );
      await fs.createLeague(orgId, league);

      // Cascade delete should not error
      await fs.deleteLeagueCascade(orgId, leagueId);

      // Verify league deleted
      final leagues = await fs.getLeagues(orgId).first;
      expect(leagues, isEmpty);
    });

    test('4. Cascade delete hub with no teams: should not error', () async {
      final orgId = 'org4';

      // Create organization, league, hub
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: 'owner4',
      );
      await fs.createOrganization(org);

      final leagueId = fs.newLeagueId(orgId);
      final league = League(
        id: leagueId,
        orgId: orgId,
        name: 'League',
        abbreviation: 'L',
        createdAt: DateTime.now(),
      );
      await fs.createLeague(orgId, league);

      final hubId = fs.newHubId(orgId, leagueId);
      final hub = Hub(
        id: hubId,
        leagueId: leagueId,
        orgId: orgId,
        name: 'Empty Hub',
        createdAt: DateTime.now(),
      );
      await fs.createHub(orgId, leagueId, hub);

      // Cascade delete should not error
      await fs.deleteHubCascade(orgId, leagueId, hubId);

      // Verify hub deleted
      final hubs = await fs.getHubs(orgId, leagueId).first;
      expect(hubs, isEmpty);
    });

    test('5. User with no orgId: getOrgUsers returns empty', () async {
      final userId = 'user5';

      // Create user with no orgId
      final user = AppUser(
        id: userId,
        email: 'user@example.com',
        displayName: 'User',
        role: UserRole.staff,
        orgId: null,
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now(),
        isActive: true,
      );
      await fs.updateUser(user);

      // getOrgUsers should return empty for any orgId
      final users = await fs.getOrgUsers('org5').first;
      expect(users, isEmpty);
    });

    test('6. sendMessage with empty text: still stored', () async {
      final orgId = 'org6';
      final userId = 'user6';
      // ignore: unused_local_variable
      final roomId = 'room6';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: userId,
      );
      await fs.createOrganization(org);

      // Create room
      final actualRoomId = await fs.createChatRoom(orgId, 'Test Room', ChatRoomType.league);

      // Send message with empty text
      await fs.sendMessage(
        orgId,
        actualRoomId,
        senderId: userId,
        senderName: 'User',
        text: '',
      );

      // Verify room's lastMessage is empty string
      final room = await fs.getChatRoom(orgId, actualRoomId).first;
      expect(room, isNotNull);
      expect(room!.lastMessage, '');
    });

    test('7. DM room lookup with sorted participant order: order-independent', () async {
      final orgId = 'org7';
      final uid1 = 'user1';
      const uid2 = 'user2';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: uid1,
      );
      await fs.createOrganization(org);

      // Create DM room with uid1, uid2
      final room1 = await fs.getOrCreateDMRoom(orgId, uid1, uid2, 'User1', 'User2');

      // Try to get same room with reversed order
      final room2 = await fs.getOrCreateDMRoom(orgId, uid2, uid1, 'User2', 'User1');

      // Should be same room
      expect(room1.id, room2.id);
      expect(room2.participants.contains(uid1), isTrue);
      expect(room2.participants.contains(uid2), isTrue);
    });

    test('8. getOrCreateDMRoom called twice with same users: returns same room', () async {
      final orgId = 'org8';
      const uid1 = 'user1';
      const uid2 = 'user2';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: uid1,
      );
      await fs.createOrganization(org);

      // Create DM room twice
      final room1 = await fs.getOrCreateDMRoom(orgId, uid1, uid2, 'User1', 'User2');
      final room2 = await fs.getOrCreateDMRoom(orgId, uid1, uid2, 'User1', 'User2');

      // Should return exact same room
      expect(room1.id, room2.id);
      expect(room1.createdAt, room2.createdAt);
    });

    test('9. markMessagesAsRead when no unread messages: should not error', () async {
      final orgId = 'org9';
      const userId = 'user9';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: userId,
      );
      await fs.createOrganization(org);

      // Create room
      final roomId = await fs.createChatRoom(orgId, 'Test Room', ChatRoomType.league);

      // Send message already read by user
      await fs.sendMessage(
        orgId,
        roomId,
        senderId: userId,
        senderName: 'User',
        text: 'Hello',
      );

      // Mark as read should not error
      expect(
        () => fs.markMessagesAsRead(orgId, roomId, userId),
        returnsNormally,
      );
    });

    test('10. unreadCountStream for room with no messages: returns 0', () async {
      final orgId = 'org10';
      const userId = 'user10';

      // Create organization
      final org = Organization(
        id: orgId,
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: userId,
      );
      await fs.createOrganization(org);

      // Create empty room
      final roomId = await fs.createChatRoom(orgId, 'Empty Room', ChatRoomType.league);

      // Unread count should be 0
      final unreadCount = await fs.unreadCountStream(orgId, roomId, userId).first;
      expect(unreadCount, 0);
    });

    test('11. formatFileSize with 0 bytes', () {
      const size = 0;
      final formatted = _formatFileSize(size);
      expect(formatted, '0 B');
    });

    test('12. formatDateTime with future date', () {
      final futureDate = DateTime.now().add(Duration(days: 30));
      final formatted = _formatDateTime(futureDate);
      expect(formatted, isNotEmpty);
      // Should be formatted correctly without error
    });

    test('13. getInitials with unicode characters', () {
      const name = 'François José';
      final initials = _getInitials(name);
      expect(initials.length, 2);
      expect(initials, 'FJ');
    });
  });
}

// Helper functions (typically in utils)
String _formatFileSize(int bytes) {
  if (bytes == 0) return '0 B';
  const sizes = ['B', 'KB', 'MB', 'GB'];
  final i = (log(bytes.toDouble()) / log(1024.0)).floor();
  return '${(bytes / (1 << (i * 10))).toStringAsFixed(2)} ${sizes[i]}';
}

String _formatDateTime(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(Duration(days: 1));
  final dateToCheck = DateTime(date.year, date.month, date.day);

  if (dateToCheck == today) {
    return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } else if (dateToCheck == yesterday) {
    return 'Yesterday';
  } else {
    return '${date.month}/${date.day}/${date.year}';
  }
}

String _getInitials(String name) {
  final parts = name.split(' ');
  if (parts.isEmpty) return '';
  if (parts.length == 1) {
    return parts[0].substring(0, 1).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[parts.length - 1].substring(0, 1))
      .toUpperCase();
}
