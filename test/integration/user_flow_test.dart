import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/auth_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/permission_service.dart';

void main() {
  group('User Flow Integration Tests', () {
    late FakeFirebaseFirestore fakeDb;
    late MockFirebaseAuth fakeAuth;
    late FirestoreService fs;
    late AuthService auth;

    setUp(() {
      fakeDb = FakeFirebaseFirestore();
      fakeAuth = MockFirebaseAuth();
      fs = FirestoreService(firestore: fakeDb);
      auth = AuthService(auth: fakeAuth, firestore: fakeDb);
    });

    group('Flow 1: Full sign-up → org creation → first login', () {
      test('Create account → org → leagues → hubs → teams → verify all exist', () async {
        // Create account
        final cred = await auth.createAccount(
          'alice@example.com',
          'password123',
          'Alice Admin',
        );
        final uid = cred.user!.uid;
        expect(uid, isNotEmpty);

        // Create organization
        final orgId = 'org1';
        final org = Organization(
          id: orgId,
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: uid,
        );
        await fs.createOrganization(org);

        // Update user as superAdmin with orgId
        final user = AppUser(
          id: uid,
          email: 'alice@example.com',
          displayName: 'Alice Admin',
          role: UserRole.superAdmin,
          orgId: orgId,
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        await fs.updateUser(user);

        // Create league
        final leagueId = fs.newLeagueId(orgId);
        final league = League(
          id: leagueId,
          orgId: orgId,
          name: 'Premier League',
          abbreviation: 'PL',
          createdAt: DateTime.now(),
        );
        await fs.createLeague(orgId, league);

        // Create hub
        final hubId = fs.newHubId(orgId, leagueId);
        final hub = Hub(
          id: hubId,
          leagueId: leagueId,
          orgId: orgId,
          name: 'Central Hub',
          createdAt: DateTime.now(),
        );
        await fs.createHub(orgId, leagueId, hub);

        // Create team
        final teamId = fs.newTeamId(orgId, leagueId, hubId);
        final team = Team(
          id: teamId,
          hubId: hubId,
          leagueId: leagueId,
          orgId: orgId,
          name: 'Team A',
          createdAt: DateTime.now(),
        );
        await fs.createTeam(orgId, leagueId, hubId, team);

        // Verify organization exists
        final fetchedOrg = await fs.getOrganization(orgId);
        expect(fetchedOrg, isNotNull);
        expect(fetchedOrg!.name, 'Test Org');

        // Verify league exists
        final leagues = await fs.getLeagues(orgId).first;
        expect(leagues, hasLength(1));
        expect(leagues.first.name, 'Premier League');

        // Verify hub exists
        final hubs = await fs.getHubs(orgId, leagueId).first;
        expect(hubs, hasLength(1));
        expect(hubs.first.name, 'Central Hub');

        // Verify team exists
        final teams = await fs.getTeams(orgId, leagueId, hubId).first;
        expect(teams, hasLength(1));
        expect(teams.first.name, 'Team A');

        // Verify user doc
        final fetchedUser = await fs.getUser(uid);
        expect(fetchedUser!.role, UserRole.superAdmin);
        expect(fetchedUser.orgId, orgId);
      });
    });

    group('Flow 2: Invite → accept → first login as Staff', () {
      test('Create invitation → retrieve by token → create account → verify role and assignments',
          () async {
        final orgId = 'org2';
        final superAdminId = 'admin1';

        // Create organization
        final org = Organization(
          id: orgId,
          name: 'Test Org 2',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: superAdminId,
        );
        await fs.createOrganization(org);

        // Create league and hub for assignment
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
          name: 'Hub',
          createdAt: DateTime.now(),
        );
        await fs.createHub(orgId, leagueId, hub);

        // Create invitation
        final invitation = Invitation(
          id: 'inv1',
          orgId: orgId,
          email: 'staff@example.com',
          displayName: 'Staff Member',
          role: 'staff',
          hubIds: [hubId],
          teamIds: [],
          invitedBy: superAdminId,
          invitedByName: 'Admin',
          createdAt: DateTime.now(),
          status: InvitationStatus.pending,
          token: '',
        );
        final token = await fs.createInvitation(orgId, invitation);
        expect(token, isNotEmpty);

        // Retrieve by token
        final fetchedInvite = await fs.getInvitationByToken(token);
        expect(fetchedInvite, isNotNull);
        expect(fetchedInvite!.email, 'staff@example.com');
        expect(fetchedInvite.role, 'staff');
        expect(fetchedInvite.hubIds, contains(hubId));

        // Create account from invite
        await auth.createAccountFromInvite(
          'staff@example.com',
          'password123',
          'Staff Member',
          fetchedInvite,
        );
        final uid = fakeAuth.currentUser!.uid;

        // Verify user doc
        final user = await fs.getUser(uid);
        expect(user, isNotNull);
        expect(user!.role, UserRole.staff);
        expect(user.orgId, orgId);
        expect(user.hubIds, [hubId]);

        // Accept invitation using the fetched invitation's ID
        await fs.acceptInvitation(orgId, fetchedInvite.id);
        final acceptedInvite = await fakeDb
            .collection('organizations')
            .doc(orgId)
            .collection('invitations')
            .doc(fetchedInvite.id)
            .get();
        expect(acceptedInvite['status'], 'accepted');
      });
    });

    group('Flow 3: Create league → auto-create chat room → post message', () {
      test('Create league, auto-create chat rooms, send message, verify lastMessage updated',
          () async {
        final orgId = 'org3';
        final userId = 'user3';

        // Create org and league
        final org = Organization(
          id: orgId,
          name: 'Test Org 3',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: userId,
        );
        await fs.createOrganization(org);

        final leagueId = fs.newLeagueId(orgId);
        final league = League(
          id: leagueId,
          orgId: orgId,
          name: 'Soccer League',
          abbreviation: 'SL',
          createdAt: DateTime.now(),
        );
        await fs.createLeague(orgId, league);

        // Auto-create chat rooms
        await fs.createLeagueChatRooms(orgId, [
          {'id': leagueId, 'name': 'Soccer League'}
        ]);

        // Verify room created
        final rooms = await fs.getChatRooms(orgId).first;
        expect(rooms, hasLength(1));
        final room = rooms.first;
        expect(room.type, ChatRoomType.league);
        expect(room.leagueId, leagueId);
        expect(room.lastMessage, isNull);

        // Send message
        await fs.sendMessage(
          orgId,
          room.id,
          senderId: userId,
          senderName: 'User',
          text: 'Hello everyone!',
        );

        // Verify lastMessage updated
        final updatedRoom = await fs.getChatRoom(orgId, room.id).first;
        expect(updatedRoom, isNotNull);
        expect(updatedRoom!.lastMessage, 'Hello everyone!');
        expect(updatedRoom.lastMessageBy, 'User');
        expect(updatedRoom.lastMessageAt, isNotNull);
      });
    });

    group('Flow 4: Upload document → view in list → add version', () {
      test('Create document, verify in stream, add version, verify versions grow', () async {
        final orgId = 'org4';
        final userId = 'user4';
        final leagueId = 'league4';

        // Create org
        final org = Organization(
          id: orgId,
          name: 'Test Org 4',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: userId,
        );
        await fs.createOrganization(org);

        // Create document
        final docData = {
          'name': 'Rules.pdf',
          'fileUrl': 'https://example.com/rules.pdf',
          'fileType': 'pdf',
          'fileSize': 1024,
          'category': 'Rules',
          'leagueId': leagueId,
          'uploadedBy': userId,
          'uploadedByName': 'User',
          'versions': [],
        };
        final docId = await fs.createDocument(orgId, docData);
        expect(docId, isNotEmpty);

        // Verify in stream - use a short timeout to wait for snapshot
        final docStream = fs.getDocuments(orgId);
        final docs = await docStream
            .timeout(const Duration(seconds: 5))
            .firstWhere((list) => list.isNotEmpty);
        expect(docs, hasLength(1));
        expect(docs.first.name, 'Rules.pdf');
        expect(docs.first.versions, isEmpty);

        // Add version
        await fs.addDocumentVersion(orgId, docId, {
          'url': 'https://example.com/rules-v2.pdf',
          'fileSize': 2048,
          'uploadedAt': DateTime.now().toIso8601String(),
          'uploadedBy': userId,
          'uploadedByName': 'User',
        });

        // Verify versions grew - wait for snapshot with version
        final docByIdStream = fs.getDocumentById(orgId, docId);
        final updatedDoc = await docByIdStream
            .timeout(const Duration(seconds: 5))
            .firstWhere((doc) => doc != null && doc.versions.isNotEmpty);
        expect(updatedDoc, isNotNull);
        expect(updatedDoc!.versions, hasLength(1));
        expect(updatedDoc.versions.first.version, 1);
        expect(updatedDoc.versions.first.fileUrl, 'https://example.com/rules-v2.pdf');
      });
    });

    group('Flow 5: Create announcement → verify scope filtering', () {
      test('Create org-wide, league, hub announcements → verify getAnnouncementsByLeague filtering',
          () async {
        final orgId = 'org5';
        final userId = 'user5';
        final leagueId = 'league5';
        final hubId = 'hub5';

        // Create org
        final org = Organization(
          id: orgId,
          name: 'Test Org 5',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: userId,
        );
        await fs.createOrganization(org);

        // Create org-wide announcement
        await fs.createAnnouncement(orgId, {
          'scope': 'orgWide',
          'title': 'Global Announcement',
          'body': 'This is org-wide',
          'authorId': userId,
          'authorName': 'Admin',
          'authorRole': 'superAdmin',
          'attachments': [],
          'isPinned': false,
        });

        // Create league-scoped announcement
        await fs.createAnnouncement(orgId, {
          'scope': 'league',
          'leagueId': leagueId,
          'title': 'League Announcement',
          'body': 'This is league-scoped',
          'authorId': userId,
          'authorName': 'Admin',
          'authorRole': 'superAdmin',
          'attachments': [],
          'isPinned': false,
        });

        // Create hub-scoped announcement
        await fs.createAnnouncement(orgId, {
          'scope': 'hub',
          'hubId': hubId,
          'title': 'Hub Announcement',
          'body': 'This is hub-scoped',
          'authorId': userId,
          'authorName': 'Admin',
          'authorRole': 'superAdmin',
          'attachments': [],
          'isPinned': false,
        });

        // Get all announcements
        final allAnnouncements = await fs.getAnnouncements(orgId).first;
        expect(allAnnouncements, hasLength(3));

        // Get announcements by league (should include org-wide + league-scoped)
        final leagueAnnouncements = await fs.getAnnouncementsByLeague(orgId, leagueId).first;
        expect(leagueAnnouncements, hasLength(2));
        expect(
          leagueAnnouncements.where((a) => a.scope == AnnouncementScope.orgWide),
          hasLength(1),
        );
        expect(
          leagueAnnouncements.where((a) => a.leagueId == leagueId),
          hasLength(1),
        );
      });
    });

    group('Flow 6: Role change → verify access changes', () {
      test('Create staff user → verify denied → change to managerAdmin → verify allowed',
          () async {
        final orgId = 'org6';
        final staffId = 'staff6';

        // Create org
        final org = Organization(
          id: orgId,
          name: 'Test Org 6',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner6',
        );
        await fs.createOrganization(org);

        // Create staff user
        final staffUser = AppUser(
          id: staffId,
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: orgId,
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        await fs.updateUser(staffUser);

        // Verify staff cannot create announcements
        final ps = PermissionService();
        expect(ps.canCreateAnnouncement(staffUser), isFalse);

        // Update user to managerAdmin
        final managerUser = AppUser(
          id: staffId,
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.managerAdmin,
          orgId: orgId,
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        await fs.updateUser(managerUser);

        // Fetch updated user
        final fetchedUser = await fs.getUser(staffId);
        expect(fetchedUser!.role, UserRole.managerAdmin);

        // Verify managerAdmin can create announcements
        expect(ps.canCreateAnnouncement(fetchedUser), isTrue);
      });
    });

    group('Flow 7: Deactivate user → verify blocked', () {
      test('Create active user → deactivate → verify isActive false → verify blocked by permission',
          () async {
        final orgId = 'org7';
        final userId = 'user7';

        // Create org
        final org = Organization(
          id: orgId,
          name: 'Test Org 7',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: userId,
        );
        await fs.createOrganization(org);

        // Create active user
        final user = AppUser(
          id: userId,
          email: 'user@example.com',
          displayName: 'User',
          role: UserRole.staff,
          orgId: orgId,
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        await fs.updateUser(user);

        // Verify initially active
        var fetchedUser = await fs.getUser(userId);
        expect(fetchedUser!.isActive, isTrue);

        // Deactivate
        await fs.deactivateUser(userId);

        // Verify deactivated
        fetchedUser = await fs.getUser(userId);
        expect(fetchedUser!.isActive, isFalse);

        // Verify permission service blocks inactive user
        final ps = PermissionService();
        expect(ps.isActiveUser(fetchedUser), isFalse);
        expect(ps.canSendMessage(fetchedUser), isFalse);
        expect(ps.canAccessRoute(fetchedUser, '/chat'), isFalse);
      });
    });
  });
}
