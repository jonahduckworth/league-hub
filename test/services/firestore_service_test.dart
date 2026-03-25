import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/core/constants.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService svc;

  const orgId = 'test-org-001';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    svc = FirestoreService(firestore: fakeFirestore);
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
    test('getOrganization returns org when exists', () async {
      final org = makeOrg();
      await svc.createOrganization(org);

      final fetched = await svc.getOrganization(orgId);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Test League');
      expect(fetched.ownerId, 'owner-001');
    });

    test('getOrganization returns null when not exists', () async {
      final result = await svc.getOrganization('nonexistent');
      expect(result, isNull);
    });

    test('createOrganization stores data', () async {
      final org = makeOrg();
      await svc.createOrganization(org);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .get();
      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Test League');
      expect(doc.data()!['ownerId'], 'owner-001');
    });

    test('updateOrganization updates fields', () async {
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

    test('getLeagues streams league list ordered by createdAt', () async {
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
      expect(leagues[1].name, 'Second');
    });

    test('getLeagues returns empty for no-data org', () async {
      final leagues = await svc.getLeagues('empty-org').first;
      expect(leagues, isEmpty);
    });

    test('createLeague stores data', () async {
      final league = makeLeague('league-1');
      await svc.createLeague(orgId, league);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('leagues')
          .doc('league-1')
          .get();
      expect(doc.exists, true);
      expect(doc.data()!['name'], 'North League');
    });

    test('deleteLeague removes document', () async {
      await svc.createLeague(orgId, makeLeague('league-del'));
      await svc.deleteLeague(orgId, 'league-del');

      final leagues = await svc.getLeagues(orgId).first;
      expect(leagues, isEmpty);
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

    test('getHubs streams hub list', () async {
      final now = DateTime.now();
      await svc.createHub(orgId, leagueId,
        Hub(
          id: 'hub-a',
          leagueId: leagueId,
          orgId: orgId,
          name: 'Hub A',
          createdAt: now,
        )
      );
      await svc.createHub(orgId, leagueId,
        Hub(
          id: 'hub-b',
          leagueId: leagueId,
          orgId: orgId,
          name: 'Hub B',
          createdAt: now.add(const Duration(seconds: 1)),
        )
      );

      final hubs = await svc.getHubs(orgId, leagueId).first;
      expect(hubs, hasLength(2));
      expect(hubs[0].name, 'Hub A');
      expect(hubs[1].name, 'Hub B');
    });

    test('createHub stores data', () async {
      await svc.createHub(orgId, leagueId, makeHub('hub-1', leagueId));

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('leagues')
          .doc(leagueId)
          .collection('hubs')
          .doc('hub-1')
          .get();
      expect(doc.exists, true);
      expect(doc.data()!['name'], 'East Hub');
    });

    test('deleteHub removes document', () async {
      await svc.createHub(orgId, leagueId, makeHub('hub-del', leagueId));
      await svc.deleteHub(orgId, leagueId, 'hub-del');

      final hubs = await svc.getHubs(orgId, leagueId).first;
      expect(hubs, isEmpty);
    });

    test('getAllHubsCount counts across all leagues', () async {
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

    test('getTeams streams team list', () async {
      final now = DateTime.now();
      await svc.createTeam(
        orgId, leagueId, hubId,
        Team(
          id: 'team-a',
          hubId: hubId,
          leagueId: leagueId,
          orgId: orgId,
          name: 'Team A',
          createdAt: now,
        )
      );
      await svc.createTeam(
        orgId, leagueId, hubId,
        Team(
          id: 'team-b',
          hubId: hubId,
          leagueId: leagueId,
          orgId: orgId,
          name: 'Team B',
          createdAt: now.add(const Duration(seconds: 1)),
        )
      );

      final teams = await svc.getTeams(orgId, leagueId, hubId).first;
      expect(teams, hasLength(2));
      expect(teams[0].name, 'Team A');
      expect(teams[1].name, 'Team B');
    });

    test('createTeam stores data', () async {
      await svc.createTeam(
          orgId, leagueId, hubId, makeTeam('team-1', leagueId, hubId));

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('leagues')
          .doc(leagueId)
          .collection('hubs')
          .doc(hubId)
          .collection('teams')
          .doc('team-1')
          .get();
      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Red Hawks');
    });

    test('deleteTeam removes document', () async {
      await svc.createTeam(
          orgId, leagueId, hubId, makeTeam('team-del', leagueId, hubId));
      await svc.deleteTeam(orgId, leagueId, hubId, 'team-del');

      final teams = await svc.getTeams(orgId, leagueId, hubId).first;
      expect(teams, isEmpty);
    });

    test('getAllTeamsCount counts across all leagues and hubs', () async {
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
    test('getUser returns user when exists', () async {
      final user = makeUser('user-001');
      await svc.updateUser(user);

      final fetched = await svc.getUser('user-001');
      expect(fetched, isNotNull);
      expect(fetched!.email, 'user-001@example.com');
      expect(fetched.isActive, isTrue);
    });

    test('getUser returns null when not exists', () async {
      final result = await svc.getUser('nonexistent-user');
      expect(result, isNull);
    });

    test('updateUser merges data', () async {
      final user = makeUser('user-001');
      await svc.updateUser(user);

      final updated = AppUser(
        id: 'user-001',
        email: 'user-001@example.com',
        displayName: 'Updated Name',
        role: UserRole.managerAdmin,
        orgId: orgId,
        hubIds: ['hub1'],
        teamIds: ['team1'],
        createdAt: DateTime.now(),
        isActive: true,
      );
      await svc.updateUser(updated);

      final fetched = await svc.getUser('user-001');
      expect(fetched!.displayName, 'Updated Name');
      expect(fetched.role, UserRole.managerAdmin);
    });

    test('getOrgUsers streams users filtered by orgId', () async {
      await svc.updateUser(makeUser('u1'));
      await svc.updateUser(makeUser('u2'));
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

    test('updateUserFields updates specific fields', () async {
      await svc.updateUser(makeUser('u-patch'));
      await svc.updateUserFields('u-patch', {'displayName': 'Patched Name'});

      final fetched = await svc.getUser('u-patch');
      expect(fetched!.displayName, 'Patched Name');
    });

    test('deactivateUser sets isActive false', () async {
      await svc.updateUser(makeUser('u-deactivate'));
      await svc.deactivateUser('u-deactivate');

      final fetched = await svc.getUser('u-deactivate');
      expect(fetched!.isActive, isFalse);
    });

    test('reactivateUser sets isActive true', () async {
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

    test('getActiveUserCount counts only active users in org', () async {
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

    test('createChatRoom creates with correct fields', () async {
      final roomId = await svc.createChatRoom(
        orgId,
        'General',
        ChatRoomType.league,
        leagueId: 'lg-1',
      );

      expect(roomId, isNotEmpty);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection(AppConstants.chatRoomsCollection)
          .doc(roomId)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['name'], 'General');
      expect(doc.data()!['type'], 'league');
      expect(doc.data()!['leagueId'], 'lg-1');
      expect(doc.data()!['isArchived'], false);
    });

    test('archiveChatRoom sets isArchived true', () async {
      final roomId = await svc.createChatRoom(
          orgId, 'To Archive', ChatRoomType.league);

      await svc.archiveChatRoom(orgId, roomId);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection(AppConstants.chatRoomsCollection)
          .doc(roomId)
          .get();
      expect(doc.data()!['isArchived'], true);
    });

    test('getChatRooms returns non-archived rooms', () async {
      await svc.createChatRoom(orgId, 'Room A', ChatRoomType.league);
      final id2 = await svc.createChatRoom(orgId, 'Room B', ChatRoomType.league);

      await svc.archiveChatRoom(orgId, id2);

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms.length, 1);
      expect(rooms[0].name, 'Room A');
    });

    test('getChatRoom streams single room', () async {
      final roomId = await svc.createChatRoom(
          orgId, 'Test Room', ChatRoomType.league);

      final room = await svc.getChatRoom(orgId, roomId).first;
      expect(room, isNotNull);
      expect(room!.name, 'Test Room');
    });

    test('getOrCreateDMRoom creates new DM', () async {
      final room = await svc.getOrCreateDMRoom(
          orgId, 'uid-a', 'uid-b', 'Alice', 'Bob');

      expect(room.id, isNotEmpty);
      expect(room.type, ChatRoomType.direct);
      expect(room.name, 'Alice & Bob');
    });

    test('getOrCreateDMRoom returns existing DM', () async {
      final room1 = await svc.getOrCreateDMRoom(
          orgId, 'uid-a', 'uid-b', 'Alice', 'Bob');

      final room2 = await svc.getOrCreateDMRoom(
          orgId, 'uid-a', 'uid-b', 'Alice', 'Bob');

      expect(room1.id, room2.id);
    });

    test('createLeagueChatRooms creates rooms for leagues without existing ones',
        () async {
      final leagues = [
        {'id': 'lg-a', 'name': 'Alpha'},
      ];
      await svc.createLeagueChatRooms(orgId, leagues);

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms, hasLength(1));
      expect(rooms.first.name, 'Alpha – General');
    });

    test('createLeagueChatRooms skips leagues that already have rooms',
        () async {
      await svc.createChatRoom(orgId, 'Alpha – General', ChatRoomType.league,
          leagueId: 'lg-a');

      final leagues = [
        {'id': 'lg-a', 'name': 'Alpha'},
      ];
      await svc.createLeagueChatRooms(orgId, leagues);

      final rooms = await svc.getChatRooms(orgId).first;
      expect(rooms, hasLength(1));
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

    test('getMessages streams messages ordered by createdAt', () async {
      await svc.sendMessage(orgId, roomId,
          senderId: 'u1', senderName: 'Alice', text: 'First');
      await svc.sendMessage(orgId, roomId,
          senderId: 'u2', senderName: 'Bob', text: 'Second');

      final messages = await svc.getMessages(orgId, roomId).first;
      expect(messages, hasLength(2));
      expect(messages[0].text, 'First');
      expect(messages[1].text, 'Second');
    });

    test('sendMessage creates message and updates room atomically', () async {
      await svc.sendMessage(orgId, roomId,
          senderId: 'sender-1',
          senderName: 'Alice',
          text: 'Hello world!');

      final messages = await svc.getMessages(orgId, roomId).first;
      expect(messages, hasLength(1));
      expect(messages.first.text, 'Hello world!');
      expect(messages.first.senderId, 'sender-1');

      final rooms = await svc.getChatRooms(orgId).first;
      final room = rooms.firstWhere((r) => r.id == roomId);
      expect(room.lastMessage, 'Hello world!');
      expect(room.lastMessageBy, 'Alice');
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

    test('getAnnouncements streams pinned-first then newest', () async {
      await svc.createAnnouncement(orgId, announcementData(title: 'Regular'));
      await svc.createAnnouncement(
          orgId, announcementData(title: 'Pinned', isPinned: true));

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements, hasLength(2));
      expect(announcements.first.isPinned, isTrue);
      expect(announcements.first.title, 'Pinned');
      expect(announcements[1].isPinned, isFalse);
    });

    test('getAnnouncementsByLeague includes orgWide + matching league', () async {
      await svc.createAnnouncement(orgId, announcementData(
        scope: AnnouncementScope.orgWide.name,
        title: 'Org Wide',
      ));
      await svc.createAnnouncement(orgId, announcementData(
        scope: AnnouncementScope.league.name,
        leagueId: 'lg-1',
        title: 'League 1',
      ));
      await svc.createAnnouncement(orgId, announcementData(
        scope: AnnouncementScope.league.name,
        leagueId: 'lg-2',
        title: 'League 2',
      ));

      final annuncements = await svc.getAnnouncementsByLeague(orgId, 'lg-1').first;
      expect(annuncements.length, 2);
      expect(annuncements.any((a) => a.title == 'Org Wide'), true);
      expect(annuncements.any((a) => a.title == 'League 1'), true);
    });

    test('createAnnouncement creates with serverTimestamp', () async {
      final id = await svc.createAnnouncement(orgId, announcementData());
      expect(id, isNotEmpty);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('announcements')
          .doc(id)
          .get();

      expect(doc.exists, true);
    });

    test('updateAnnouncement updates fields', () async {
      final id = await svc.createAnnouncement(orgId, announcementData());
      await svc.updateAnnouncement(orgId, id, {'title': 'Updated Title'});

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('announcements')
          .doc(id)
          .get();

      expect(doc.data()!['title'], 'Updated Title');
    });

    test('deleteAnnouncement removes doc', () async {
      final id = await svc.createAnnouncement(orgId, announcementData());
      await svc.deleteAnnouncement(orgId, id);

      final announcements = await svc.getAnnouncements(orgId).first;
      expect(announcements, isEmpty);
    });

    test('togglePin sets isPinned', () async {
      final id = await svc.createAnnouncement(orgId, announcementData());
      await svc.togglePin(orgId, id, true);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('announcements')
          .doc(id)
          .get();

      expect(doc.data()!['isPinned'], true);
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

    test('documentsStream returns all docs', () async {
      await svc.createDocument(orgId, docData(name: 'Doc 1'));
      await svc.createDocument(orgId, docData(name: 'Doc 2'));

      final docs = await svc.documentsStream(orgId).first;
      expect(docs, hasLength(2));
    });

    test('documentsStream filters by leagueId', () async {
      await svc.createDocument(orgId, docData(leagueId: 'lg-1'));
      await svc.createDocument(orgId, docData(name: 'Other', leagueId: 'lg-2'));

      final docs = await svc.documentsStream(orgId, leagueId: 'lg-1').first;
      expect(docs, hasLength(1));
      expect(docs.first.leagueId, 'lg-1');
    });

    test('documentsStream filters by category', () async {
      await svc.createDocument(orgId, docData(category: 'rules'));
      await svc.createDocument(
          orgId, docData(name: 'Other', category: 'forms'));

      final docs = await svc.documentsStream(orgId, category: 'rules').first;
      expect(docs, hasLength(1));
      expect(docs.first.category, 'rules');
    });

    test('createDocument creates with timestamps', () async {
      final id = await svc.createDocument(orgId, docData());
      expect(id, isNotEmpty);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('documents')
          .doc(id)
          .get();

      expect(doc.exists, true);
      expect(doc.data()!['name'], 'Rulebook');
    });

    test('updateDocument updates with timestamp', () async {
      final id = await svc.createDocument(orgId, docData());
      await svc.updateDocument(orgId, id, {'name': 'Updated Name'});

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('documents')
          .doc(id)
          .get();

      expect(doc.data()!['name'], 'Updated Name');
    });

    test('deleteDocument removes doc', () async {
      final id = await svc.createDocument(orgId, docData());
      await svc.deleteDocument(orgId, id);

      final docs = await svc.documentsStream(orgId).first;
      expect(docs, isEmpty);
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

    test('getDocumentById streams single doc', () async {
      final id = await svc.createDocument(orgId, docData());

      final doc = await svc.getDocumentById(orgId, id).first;
      expect(doc, isNotNull);
      expect(doc!.name, 'Rulebook');
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

    test('createInvitation generates token and stores', () async {
      final token = await svc.createInvitation(orgId, makeInvitation());
      expect(token, isNotEmpty);
      expect(token.length, 32);
    });

    test('getInvitations streams ordered by createdAt desc', () async {
      final token = await svc.createInvitation(orgId, makeInvitation());

      final invites = await svc.getInvitations(orgId).first;
      expect(invites, hasLength(1));
      expect(invites.first.email, 'newuser@example.com');
      expect(invites.first.token, token);
    });

    test('getInvitationByToken finds pending invitation', () async {
      final token = await svc.createInvitation(orgId, makeInvitation());

      final invite = await svc.getInvitationByToken(token);
      expect(invite, isNotNull);
      expect(invite!.email, 'newuser@example.com');
    });

    test('getInvitationByToken returns null for no match', () async {
      final invite = await svc.getInvitationByToken('no-such-token');
      expect(invite, isNull);
    });

    test('acceptInvitation updates status', () async {
      final token = await svc.createInvitation(orgId, makeInvitation());
      final invite = await svc.getInvitationByToken(token);
      await svc.acceptInvitation(orgId, invite!.id);

      final doc = await fakeFirestore
          .collection(AppConstants.orgsCollection)
          .doc(orgId)
          .collection('invitations')
          .doc(invite.id)
          .get();

      expect(doc.data()!['status'], 'accepted');
    });
  });

  // ---------------------------------------------------------------------------
  // Counts & ID Generators
  // ---------------------------------------------------------------------------

  group('Counts', () {
    test('getAllHubsFlat returns all hubs across leagues', () async {
      await svc.createOrganization(makeOrg());
      const lg1 = 'lg-1';
      const lg2 = 'lg-2';
      await svc.createLeague(orgId, makeLeague(lg1));
      await svc.createLeague(orgId, makeLeague(lg2));
      await svc.createHub(orgId, lg1, makeHub('h1', lg1));
      await svc.createHub(orgId, lg1, makeHub('h2', lg1));
      await svc.createHub(orgId, lg2, makeHub('h3', lg2));

      final hubs = await svc.getAllHubsFlat(orgId);
      expect(hubs, hasLength(3));
    });

    test('getActiveUserCount returns count of active users', () async {
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

  group('ID Generators', () {
    test('newLeagueId returns non-empty string', () async {
      await svc.createOrganization(makeOrg());
      final id = svc.newLeagueId(orgId);
      expect(id, isNotEmpty);
    });

    test('newHubId returns non-empty string', () async {
      await svc.createOrganization(makeOrg());
      await svc.createLeague(orgId, makeLeague('lg-1'));
      final id = svc.newHubId(orgId, 'lg-1');
      expect(id, isNotEmpty);
    });

    test('newTeamId returns non-empty string', () async {
      await svc.createOrganization(makeOrg());
      await svc.createLeague(orgId, makeLeague('lg-1'));
      await svc.createHub(orgId, 'lg-1', makeHub('h-1', 'lg-1'));
      final id = svc.newTeamId(orgId, 'lg-1', 'h-1');
      expect(id, isNotEmpty);
    });
  });
}
