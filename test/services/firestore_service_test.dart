/// Firebase emulator integration tests for FirestoreService.
///
/// Prerequisites:
///   npm install -g firebase-tools
///   firebase login
///
/// Run:
///   firebase emulators:exec --only auth,firestore,storage \
///     "flutter test test/services/firestore_service_test.dart"
///
/// Or use the convenience script:
///   ./scripts/run_integration_tests.sh
@Tags(['emulator'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/firestore_service.dart';

import '../helpers/firebase_test_helper.dart';

void main() {
  late FirestoreService svc;

  const orgId = 'test-org-001';

  setUpAll(FirebaseTestHelper.setupAll);
  setUp(FirebaseTestHelper.clearData);
  tearDownAll(FirebaseTestHelper.tearDownAll);

  setUp(() {
    svc = FirestoreService();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Organization makeOrg() => Organization(
        id: orgId,
        name: 'Test League',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: 'owner-001',
      );

  League makeLeague(String id) => League(
        id: id,
        orgId: orgId,
        name: 'North League',
        abbreviation: 'NL',
        createdAt: DateTime.now(),
      );

  Hub makeHub(String id, String leagueId) => Hub(
        id: id,
        leagueId: leagueId,
        orgId: orgId,
        name: 'East Hub',
        createdAt: DateTime.now(),
      );

  Team makeTeam(String id, String leagueId, String hubId) => Team(
        id: id,
        hubId: hubId,
        leagueId: leagueId,
        orgId: orgId,
        name: 'Red Hawks',
        ageGroup: 'U12',
        division: 'Division 1',
        createdAt: DateTime.now(),
      );

  AppUser makeUser(String id) => AppUser(
        id: id,
        email: '$id@example.com',
        displayName: 'User $id',
        role: UserRole.staff,
        orgId: orgId,
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now(),
        isActive: true,
      );

  // ---------------------------------------------------------------------------
  // Organizations
  // ---------------------------------------------------------------------------

  group('Organizations', () {
    test('createOrganization writes the document', () async {
      final org = makeOrg();
      await svc.createOrganization(org);

      final fetched = await svc.getOrganization(orgId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Test League');
      expect(fetched.ownerId, 'owner-001');
    });

    test('getOrganization returns null for missing doc', () async {
      final result = await svc.getOrganization('nonexistent');
      expect(result, isNull);
    });

    test('updateOrganization modifies fields', () async {
      await svc.createOrganization(makeOrg());
      await svc.updateOrganization(orgId, {'name': 'Updated League'});

      final fetched = await svc.getOrganization(orgId);
      expect(fetched!.name, 'Updated League');
    });
  });

  // ---------------------------------------------------------------------------
  // Leagues
  // ---------------------------------------------------------------------------

  group('Leagues', () {
    setUp(() async => svc.createOrganization(makeOrg()));

    test('createLeague then getLeagues stream returns it', () async {
      final league = makeLeague('league-1');
      await svc.createLeague(orgId, league);

      final leagues = await svc.getLeagues(orgId).first;
      expect(leagues, hasLength(1));
      expect(leagues.first.name, 'North League');
      expect(leagues.first.abbreviation, 'NL');
    });

    test('deleteLeague removes the document', () async {
      await svc.createLeague(orgId, makeLeague('league-del'));
      await svc.deleteLeague(orgId, 'league-del');

      final leagues = await svc.getLeagues(orgId).first;
      expect(leagues, isEmpty);
    });

    test('getLeagues returns multiple leagues ordered by createdAt', () async {
      final now = DateTime.now();
      final l1 = League(
          id: 'l1',
          orgId: orgId,
          name: 'First',
          abbreviation: 'F',
          createdAt: now);
      final l2 = League(
          id: 'l2',
          orgId: orgId,
          name: 'Second',
          abbreviation: 'S',
          createdAt: now.add(const Duration(seconds: 1)));
      await svc.createLeague(orgId, l1);
      await svc.createLeague(orgId, l2);

      final leagues = await svc.getLeagues(orgId).first;
      expect(leagues, hasLength(2));
      expect(leagues.first.name, 'First');
    });
  });

  // ---------------------------------------------------------------------------
  // Hubs
  // ---------------------------------------------------------------------------

  group('Hubs', () {
    const leagueId = 'league-hub-test';

    setUp(() async {
      await svc.createOrganization(makeOrg());
      await svc.createLeague(orgId, makeLeague(leagueId));
    });

    test('createHub then getHubs stream returns it', () async {
      await svc.createHub(orgId, leagueId, makeHub('hub-1', leagueId));

      final hubs = await svc.getHubs(orgId, leagueId).first;
      expect(hubs, hasLength(1));
      expect(hubs.first.name, 'East Hub');
    });

    test('deleteHub removes the document', () async {
      await svc.createHub(orgId, leagueId, makeHub('hub-del', leagueId));
      await svc.deleteHub(orgId, leagueId, 'hub-del');

      final hubs = await svc.getHubs(orgId, leagueId).first;
      expect(hubs, isEmpty);
    });

    test('getAllHubsCount returns correct count across leagues', () async {
      const l2 = 'league-2';
      await svc.createLeague(
          orgId,
          League(
              id: l2,
              orgId: orgId,
              name: 'Second',
              abbreviation: 'S',
              createdAt: DateTime.now()));
      await svc.createHub(orgId, leagueId, makeHub('hub-a', leagueId));
      await svc.createHub(orgId, leagueId, makeHub('hub-b', leagueId));
      await svc.createHub(orgId, l2, makeHub('hub-c', l2));

      final count = await svc.getAllHubsCount(orgId);
      expect(count, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // Teams
  // ---------------------------------------------------------------------------

  group('Teams', () {
    const leagueId = 'league-teams';
    const hubId = 'hub-teams';

    setUp(() async {
      await svc.createOrganization(makeOrg());
      await svc.createLeague(orgId, makeLeague(leagueId));
      await svc.createHub(orgId, leagueId, makeHub(hubId, leagueId));
    });

    test('createTeam then getTeams stream returns it', () async {
      await svc.createTeam(
          orgId, leagueId, hubId, makeTeam('team-1', leagueId, hubId));

      final teams = await svc.getTeams(orgId, leagueId, hubId).first;
      expect(teams, hasLength(1));
      expect(teams.first.name, 'Red Hawks');
      expect(teams.first.ageGroup, 'U12');
    });

    test('deleteTeam removes the document', () async {
      await svc.createTeam(
          orgId, leagueId, hubId, makeTeam('team-del', leagueId, hubId));
      await svc.deleteTeam(orgId, leagueId, hubId, 'team-del');

      final teams = await svc.getTeams(orgId, leagueId, hubId).first;
      expect(teams, isEmpty);
    });

    test('getAllTeamsCount returns correct total', () async {
      await svc.createTeam(
          orgId, leagueId, hubId, makeTeam('t1', leagueId, hubId));
      await svc.createTeam(
          orgId, leagueId, hubId, makeTeam('t2', leagueId, hubId));

      final count = await svc.getAllTeamsCount(orgId);
      expect(count, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  group('Users', () {
    test('updateUser writes user doc and getUser retrieves it', () async {
      final user = makeUser('user-001');
      await svc.updateUser(user);

      final fetched = await svc.getUser('user-001');
      expect(fetched, isNotNull);
      expect(fetched!.email, 'user-001@example.com');
      expect(fetched.isActive, isTrue);
    });

    test('getOrgUsers stream returns users for org', () async {
      await svc.updateUser(makeUser('u1'));
      await svc.updateUser(makeUser('u2'));
      // User in a different org should NOT appear.
      await svc.updateUser(AppUser(
        id: 'u-other',
        email: 'other@other.com',
        displayName: 'Other',
        role: UserRole.staff,
        orgId: 'other-org',
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now(),
        isActive: true,
      ));

      final users = await svc.getOrgUsers(orgId).first;
      expect(users.map((u) => u.id), containsAll(['u1', 'u2']));
      expect(users.any((u) => u.id == 'u-other'), isFalse);
    });

    test('updateUserFields patches specific fields', () async {
      await svc.updateUser(makeUser('u-patch'));
      await svc.updateUserFields('u-patch', {'displayName': 'Patched Name'});

      final fetched = await svc.getUser('u-patch');
      expect(fetched!.displayName, 'Patched Name');
    });

    test('deactivateUser sets isActive to false', () async {
      await svc.updateUser(makeUser('u-deactivate'));
      await svc.deactivateUser('u-deactivate');

      final fetched = await svc.getUser('u-deactivate');
      expect(fetched!.isActive, isFalse);
    });

    test('reactivateUser sets isActive back to true', () async {
      final user = AppUser(
        id: 'u-reactivate',
        email: 'u-reactivate@example.com',
        displayName: 'Reactivate Me',
        role: UserRole.staff,
        orgId: orgId,
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now(),
        isActive: false,
      );
      await svc.updateUser(user);
      await svc.reactivateUser('u-reactivate');

      final fetched = await svc.getUser('u-reactivate');
      expect(fetched!.isActive, isTrue);
    });

    test('getActiveUserCount counts only active users', () async {
      await svc.updateUser(makeUser('active-1'));
      await svc.updateUser(makeUser('active-2'));
      final inactive = AppUser(
        id: 'inactive-1',
        email: 'inactive@example.com',
        displayName: 'Inactive',
        role: UserRole.staff,
        orgId: orgId,
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now(),
        isActive: false,
      );
      await svc.updateUser(inactive);

      final count = await svc.getActiveUserCount(orgId);
      expect(count, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Chat Rooms
  // ---------------------------------------------------------------------------

  group('Chat Rooms', () {
    setUp(() => svc.createOrganization(makeOrg()));

    test('createChatRoom creates a room and getChatRooms returns it', () async {
      await svc.createChatRoom(orgId, 'General', ChatRoomType.league,
          leagueId: 'lg-1');

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms, hasLength(1));
      expect(rooms.first.name, 'General');
      expect(rooms.first.isArchived, isFalse);
    });

    test('archiveChatRoom sets isArchived and room disappears from stream',
        () async {
      final roomId = await svc.createChatRoom(
          orgId, 'To Archive', ChatRoomType.league);

      await svc.archiveChatRoom(orgId, roomId);

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms, isEmpty);
    });

    test('getChatRooms orders by lastMessageAt descending', () async {
      final id1 =
          await svc.createChatRoom(orgId, 'Room A', ChatRoomType.league);
      final id2 =
          await svc.createChatRoom(orgId, 'Room B', ChatRoomType.league);

      // Send a message to room A to make it most recent.
      await svc.sendMessage(orgId, id1,
          senderId: 'u1', senderName: 'Alice', text: 'Hello');

      // Allow server timestamps to settle.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms, hasLength(2));
      expect(rooms.first.id, id1);
      expect(rooms.any((r) => r.id == id2), isTrue);
    });

    test('createLeagueChatRooms creates rooms for leagues without one',
        () async {
      final leagues = [
        {'id': 'lg-a', 'name': 'Alpha'},
        {'id': 'lg-b', 'name': 'Beta'},
      ];
      await svc.createLeagueChatRooms(orgId, leagues);

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms, hasLength(2));
      // Calling again should NOT create duplicates.
      await svc.createLeagueChatRooms(orgId, leagues);
      final roomsAgain = await svc.getChatRooms(orgId).first;
      expect(roomsAgain, hasLength(2));
    });

    test('getOrCreateDMRoom creates a new DM then finds the same one',
        () async {
      final room1 = await svc.getOrCreateDMRoom(
          orgId, 'uid-a', 'uid-b', 'Alice', 'Bob');
      expect(room1.type, ChatRoomType.direct);
      expect(room1.name, 'Alice & Bob');

      // Second call returns the same room.
      final room2 = await svc.getOrCreateDMRoom(
          orgId, 'uid-a', 'uid-b', 'Alice', 'Bob');
      expect(room2.id, room1.id);
    });
  });

  // ---------------------------------------------------------------------------
  // Messages
  // ---------------------------------------------------------------------------

  group('Messages', () {
    late String roomId;

    setUp(() async {
      await svc.createOrganization(makeOrg());
      roomId = await svc.createChatRoom(orgId, 'Test Room', ChatRoomType.league);
    });

    test('sendMessage creates message and updates room lastMessage', () async {
      await svc.sendMessage(orgId, roomId,
          senderId: 'sender-1',
          senderName: 'Alice',
          text: 'Hello emulator!');

      final messages = await svc.getMessages(orgId, roomId).first;
      expect(messages, hasLength(1));
      expect(messages.first.text, 'Hello emulator!');
      expect(messages.first.senderId, 'sender-1');

      // Room's lastMessage should be updated.
      final rooms = await svc.getChatRooms(orgId).first;
      final room = rooms.firstWhere((r) => r.id == roomId);
      expect(room.lastMessage, 'Hello emulator!');
      expect(room.lastMessageBy, 'Alice');
    });

    test('getMessages returns messages in chronological order', () async {
      await svc.sendMessage(orgId, roomId,
          senderId: 'u1', senderName: 'Alice', text: 'First');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await svc.sendMessage(orgId, roomId,
          senderId: 'u2', senderName: 'Bob', text: 'Second');

      final messages = await svc.getMessages(orgId, roomId).first;
      expect(messages, hasLength(2));
      expect(messages[0].text, 'First');
      expect(messages[1].text, 'Second');
    });
  });

  // ---------------------------------------------------------------------------
  // Announcements
  // ---------------------------------------------------------------------------

  group('Announcements', () {
    setUp(() => svc.createOrganization(makeOrg()));

    Map<String, dynamic> announcementData({
      String title = 'Test Announcement',
      bool isPinned = false,
      String scope = 'orgWide',
      String? leagueId,
    }) =>
        {
          'title': title,
          'body': 'Body text',
          'scope': scope,
          'leagueId': leagueId,
          'authorId': 'author-1',
          'authorName': 'Coach',
          'authorRole': 'managerAdmin',
          'attachments': [],
          'isPinned': isPinned,
        };

    test('createAnnouncement creates doc and getAnnouncements returns it',
        () async {
      await svc.createAnnouncement(orgId, announcementData());

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements, hasLength(1));
      expect(announcements.first.title, 'Test Announcement');
    });

    test('getAnnouncements puts pinned items first', () async {
      await svc.createAnnouncement(orgId, announcementData(title: 'Regular'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await svc.createAnnouncement(
          orgId, announcementData(title: 'Pinned', isPinned: true));

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements, hasLength(2));
      expect(announcements.first.isPinned, isTrue);
      expect(announcements.first.title, 'Pinned');
    });

    test('updateAnnouncement modifies fields', () async {
      final id =
          await svc.createAnnouncement(orgId, announcementData());
      await svc.updateAnnouncement(orgId, id, {'title': 'Updated Title'});

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements.first.title, 'Updated Title');
    });

    test('deleteAnnouncement removes the doc', () async {
      final id =
          await svc.createAnnouncement(orgId, announcementData());
      await svc.deleteAnnouncement(orgId, id);

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements, isEmpty);
    });

    test('togglePin flips isPinned', () async {
      final id = await svc.createAnnouncement(orgId, announcementData());
      await svc.togglePin(orgId, id, true);

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements.first.isPinned, isTrue);

      await svc.togglePin(orgId, id, false);
      final updated = await svc.getAnnouncements(orgId).first;
      expect(updated.first.isPinned, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Documents
  // ---------------------------------------------------------------------------

  group('Documents', () {
    setUp(() => svc.createOrganization(makeOrg()));

    Map<String, dynamic> docData({
      String name = 'Rulebook',
      String? leagueId,
      String category = 'general',
    }) =>
        {
          'name': name,
          'fileUrl': 'https://example.com/file.pdf',
          'fileType': 'pdf',
          'fileSize': 1024,
          'category': category,
          'leagueId': leagueId,
          'uploadedBy': 'user-1',
          'uploadedByName': 'Alice',
          'versions': [],
        };

    test('createDocument returns an ID and getDocuments stream returns it',
        () async {
      final id = await svc.createDocument(orgId, docData());
      expect(id, isNotEmpty);

      final docs = await svc.getDocuments(orgId).first;
      expect(docs, hasLength(1));
      expect(docs.first.name, 'Rulebook');
    });

    test('getDocumentsByLeague filters correctly', () async {
      await svc.createDocument(orgId, docData(leagueId: 'lg-1'));
      await svc.createDocument(orgId, docData(name: 'Other', leagueId: 'lg-2'));

      final docs = await svc.getDocumentsByLeague(orgId, 'lg-1').first;
      expect(docs, hasLength(1));
      expect(docs.first.leagueId, 'lg-1');
    });

    test('getDocumentsByCategory filters correctly', () async {
      await svc.createDocument(orgId, docData(category: 'rules'));
      await svc.createDocument(
          orgId, docData(name: 'Other', category: 'forms'));

      final docs = await svc.getDocumentsByCategory(orgId, 'rules').first;
      expect(docs, hasLength(1));
      expect(docs.first.category, 'rules');
    });

    test('addDocumentVersion appends to versions array', () async {
      final id = await svc.createDocument(orgId, docData());
      await svc.addDocumentVersion(orgId, id, {
        'url': 'https://example.com/v2.pdf',
        'fileSize': 2048,
        'uploadedAt': DateTime.now().toIso8601String(),
        'uploadedBy': 'user-1',
        'uploadedByName': 'Alice',
      });

      final docs = await svc.getDocuments(orgId).first;
      expect(docs.first.versions, hasLength(1));
      expect(docs.first.versions.first.version, 1);
    });

    test('deleteDocument removes the doc', () async {
      final id = await svc.createDocument(orgId, docData());
      await svc.deleteDocument(orgId, id);

      final docs = await svc.getDocuments(orgId).first;
      expect(docs, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Invitations
  // ---------------------------------------------------------------------------

  group('Invitations', () {
    setUp(() => svc.createOrganization(makeOrg()));

    Invitation makeInvitation() => Invitation(
          id: '',
          orgId: orgId,
          email: 'newuser@example.com',
          displayName: 'New User',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'admin-1',
          invitedByName: 'Admin',
          createdAt: DateTime.now(),
          status: InvitationStatus.pending,
          token: '',
        );

    test('createInvitation returns a token and getInvitations streams it',
        () async {
      final token = await svc.createInvitation(orgId, makeInvitation());
      expect(token, isNotEmpty);

      final invites = await svc.getInvitations(orgId).first;
      expect(invites, hasLength(1));
      expect(invites.first.email, 'newuser@example.com');
      expect(invites.first.token, token);
    });

    test('getInvitationByToken finds the invitation by token', () async {
      final token = await svc.createInvitation(orgId, makeInvitation());

      final invite = await svc.getInvitationByToken(token);
      expect(invite, isNotNull);
      expect(invite!.email, 'newuser@example.com');
    });

    test('getInvitationByToken returns null for unknown token', () async {
      final invite = await svc.getInvitationByToken('no-such-token');
      expect(invite, isNull);
    });

    test('acceptInvitation marks status as accepted', () async {
      final token = await svc.createInvitation(orgId, makeInvitation());
      final invite = await svc.getInvitationByToken(token);
      await svc.acceptInvitation(orgId, invite!.id);

      final invites = await svc.getInvitations(orgId).first;
      expect(invites.first.status, InvitationStatus.accepted);
    });
  });
}
