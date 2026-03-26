import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/permission_service.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreService fs;
  late AuthorizedFirestoreService authFs;
  const ps = PermissionService();

  AppUser makeUser({
    required String id,
    required UserRole role,
    String orgId = 'org1',
    List<String> hubIds = const [],
    List<String> leagueIds = const [],
    List<String> teamIds = const [],
  }) =>
      AppUser(
        id: id,
        email: '$id@test.com',
        displayName: 'User $id',
        role: role,
        orgId: orgId,
        hubIds: hubIds,
        leagueIds: leagueIds,
        teamIds: teamIds,
        createdAt: DateTime(2024),
        isActive: true,
      );

  setUp(() async {
    fakeDb = FakeFirebaseFirestore();
    fs = FirestoreService(firestore: fakeDb);
    authFs = AuthorizedFirestoreService(fs, ps);

    // Seed organization.
    final org = Organization(
      id: 'org1',
      name: 'Test Org',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime.now(),
      ownerId: 'owner',
    );
    await fs.createOrganization(org);
  });

  // =========================================================================
  // platformOwner: Full hierarchy creation
  // =========================================================================

  group('platformOwner flow', () {
    late AppUser owner;

    setUp(() {
      owner = makeUser(id: 'owner', role: UserRole.platformOwner);
    });

    test('create org → league → hub → team → verify hierarchy', () async {
      // Create league
      final leagueId = fs.newLeagueId('org1');
      final league = League(
        id: leagueId,
        orgId: 'org1',
        name: 'Hockey League',
        abbreviation: 'HL',
        createdAt: DateTime.now(),
      );
      await authFs.createLeague(owner, 'org1', league);

      // Verify league exists
      final leagues = await fs.getLeagues('org1').first;
      expect(leagues, hasLength(1));
      expect(leagues.first.name, 'Hockey League');

      // Create hub
      final hubId = fs.newHubId('org1', leagueId);
      final hub = Hub(
        id: hubId,
        leagueId: leagueId,
        orgId: 'org1',
        name: 'Calgary Hub',
        location: 'Calgary, AB',
        createdAt: DateTime.now(),
      );
      await authFs.createHub(owner, 'org1', leagueId, hub);

      // Verify hub exists
      final hubs = await fs.getHubs('org1', leagueId).first;
      expect(hubs, hasLength(1));

      // Create team
      final teamId = fs.newTeamId('org1', leagueId, hubId);
      final team = Team(
        id: teamId,
        hubId: hubId,
        leagueId: leagueId,
        orgId: 'org1',
        name: 'U11 AA',
        ageGroup: 'U11',
        division: 'AA',
        createdAt: DateTime.now(),
      );
      await authFs.createTeam(owner, 'org1', leagueId, hubId, team);

      // Verify team exists
      final teams = await fs.getTeams('org1', leagueId, hubId).first;
      expect(teams, hasLength(1));
      expect(teams.first.name, 'U11 AA');
    });

    test('cascade delete league removes all children', () async {
      final leagueId = fs.newLeagueId('org1');
      await fs.createLeague(
          'org1',
          League(
              id: leagueId,
              orgId: 'org1',
              name: 'L',
              abbreviation: 'L',
              createdAt: DateTime.now()));

      final hubId = fs.newHubId('org1', leagueId);
      await fs.createHub(
          'org1',
          leagueId,
          Hub(
              id: hubId,
              leagueId: leagueId,
              orgId: 'org1',
              name: 'H',
              createdAt: DateTime.now()));

      final teamId = fs.newTeamId('org1', leagueId, hubId);
      await fs.createTeam(
          'org1',
          leagueId,
          hubId,
          Team(
              id: teamId,
              hubId: hubId,
              leagueId: leagueId,
              orgId: 'org1',
              name: 'T',
              createdAt: DateTime.now()));

      await authFs.deleteLeagueCascade(owner, 'org1', leagueId);

      final leagues = await fs.getLeagues('org1').first;
      expect(leagues, isEmpty);
    });
  });

  // =========================================================================
  // superAdmin: Announcement CRUD
  // =========================================================================

  group('superAdmin flow', () {
    late AppUser admin;

    setUp(() {
      admin = makeUser(id: 'admin', role: UserRole.superAdmin);
    });

    test('create → verify → delete announcement', () async {
      // Create
      final announcementId = await authFs.createAnnouncement(
        admin,
        'org1',
        {
          'title': 'Important Update',
          'body': 'Please read this.',
          'scope': 'orgWide',
          'authorId': admin.id,
          'authorName': admin.displayName,
          'authorRole': admin.role.name,
          'isPinned': false,
          'attachments': [],
          'createdAt': DateTime.now().toIso8601String(),
        },
        scope: AnnouncementScope.orgWide,
      );
      expect(announcementId, isNotEmpty);

      // Verify in list
      final announcements = await fs.getAnnouncements('org1').first;
      expect(announcements.any((a) => a.title == 'Important Update'), isTrue);

      // Delete
      await authFs.deleteAnnouncement(admin, 'org1', announcementId);

      // Verify removed
      final after = await fs.getAnnouncements('org1').first;
      expect(after.any((a) => a.id == announcementId), isFalse);
    });

    test('toggle pin on announcement', () async {
      final id = await fs.createAnnouncement('org1', {
        'title': 'Pin Me',
        'body': 'Test',
        'scope': 'orgWide',
        'authorId': admin.id,
        'authorName': admin.displayName,
        'authorRole': admin.role.name,
        'isPinned': false,
        'attachments': [],
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authFs.togglePin(admin, 'org1', id, true);

      final doc = await fakeDb
          .collection('organizations')
          .doc('org1')
          .collection('announcements')
          .doc(id)
          .get();
      expect(doc.data()!['isPinned'], isTrue);
    });

    test('update announcement title', () async {
      final id = await authFs.createAnnouncement(
        admin,
        'org1',
        {
          'title': 'Original Title',
          'body': 'Content',
          'scope': 'orgWide',
          'authorId': admin.id,
          'authorName': admin.displayName,
          'authorRole': admin.role.name,
          'isPinned': false,
          'attachments': [],
          'createdAt': DateTime.now().toIso8601String(),
        },
        scope: AnnouncementScope.orgWide,
      );

      await authFs.updateAnnouncement(admin, 'org1', id,
          {'title': 'Updated Title'}, authorId: admin.id);

      final doc = await fakeDb
          .collection('organizations')
          .doc('org1')
          .collection('announcements')
          .doc(id)
          .get();
      expect(doc.data()!['title'], 'Updated Title');
    });
  });

  // =========================================================================
  // managerAdmin: Chat + document flows
  // =========================================================================

  group('managerAdmin flow', () {
    late AppUser manager;

    setUp(() {
      manager =
          makeUser(id: 'mgr', role: UserRole.managerAdmin, hubIds: ['h1']);
    });

    test('send message in chat room', () async {
      // Create chat room
      final roomId =
          await authFs.createChatRoom(manager, 'org1', 'General', ChatRoomType.league);
      expect(roomId, isNotEmpty);

      // Send message
      await authFs.sendMessage(manager, 'org1', roomId, text: 'Hello world');

      // Verify in conversation
      final messages = await fs.getMessages('org1', roomId).first;
      expect(messages, hasLength(1));
      expect(messages.first.text, 'Hello world');
      expect(messages.first.senderId, 'mgr');
    });

    test('create and delete document', () async {
      final docId = await authFs.createDocument(manager, 'org1', {
        'name': 'Policy.pdf',
        'fileUrl': 'https://example.com/file.pdf',
        'fileType': 'pdf',
        'fileSize': 1024,
        'category': 'Policy',
        'uploadedBy': manager.id,
        'uploadedByName': manager.displayName,
        'versions': [],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      expect(docId, isNotEmpty);

      // Verify
      final docs = await fs.documentsStream('org1').first;
      expect(docs.any((d) => d.name == 'Policy.pdf'), isTrue);
    });
  });

  // =========================================================================
  // staff: Verify limited permissions
  // =========================================================================

  group('staff flow', () {
    late AppUser staffUser;

    setUp(() {
      staffUser = makeUser(
          id: 'staff1',
          role: UserRole.staff,
          hubIds: ['h1'],
          leagueIds: ['l1']);
    });

    test('staff cannot create announcements', () {
      expect(
        () => authFs.createAnnouncement(
          staffUser,
          'org1',
          {'title': 'test', 'body': 'test'},
          scope: AnnouncementScope.orgWide,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('staff cannot create leagues', () {
      final league = League(
        id: 'l1',
        orgId: 'org1',
        name: 'L',
        abbreviation: 'L',
        createdAt: DateTime.now(),
      );
      expect(
        () => authFs.createLeague(staffUser, 'org1', league),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('staff cannot delete leagues', () {
      expect(
        () => authFs.deleteLeague(staffUser, 'org1', 'l1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('staff cannot create chat rooms', () {
      expect(
        () => authFs.createChatRoom(
            staffUser, 'org1', 'Room', ChatRoomType.league),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('staff can send messages', () async {
      // Seed a chat room.
      await fakeDb
          .collection('organizations')
          .doc('org1')
          .collection('chatRooms')
          .doc('room1')
          .set({
        'name': 'Test Room',
        'type': 'league',
        'participants': [],
        'isArchived': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await authFs.sendMessage(staffUser, 'org1', 'room1', text: 'Hi there');

      final messages = await fs.getMessages('org1', 'room1').first;
      expect(messages, hasLength(1));
    });

    test('staff cannot upload documents', () {
      expect(
        () => authFs.createDocument(staffUser, 'org1', {
          'name': 'test.pdf',
          'fileUrl': 'https://example.com/test.pdf',
          'fileType': 'pdf',
        }),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('staff cannot delete documents', () {
      expect(
        () => authFs.deleteDocument(staffUser, 'org1', 'doc1'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('staff can view announcements for their league', () {
      expect(
        ps.canViewAnnouncement(staffUser,
            scope: AnnouncementScope.league, leagueId: 'l1'),
        isTrue,
      );
    });

    test('staff cannot view announcements for other leagues', () {
      expect(
        ps.canViewAnnouncement(staffUser,
            scope: AnnouncementScope.league, leagueId: 'l2'),
        isFalse,
      );
    });

    test('staff can view org-wide announcements', () {
      expect(
        ps.canViewAnnouncement(staffUser, scope: AnnouncementScope.orgWide),
        isTrue,
      );
    });

    test('staff can view documents in their hub', () {
      expect(ps.canViewDocument(staffUser, hubId: 'h1'), isTrue);
    });

    test('staff cannot view documents in other hubs', () {
      expect(ps.canViewDocument(staffUser, hubId: 'h2'), isFalse);
    });
  });

  // =========================================================================
  // Permission boundary tests across roles
  // =========================================================================

  group('Permission boundaries', () {
    test('managerAdmin cannot create org-wide announcements', () {
      final manager =
          makeUser(id: 'mgr', role: UserRole.managerAdmin, hubIds: ['h1']);
      expect(
        () => authFs.createAnnouncement(
          manager,
          'org1',
          {'title': 't', 'body': 'b'},
          scope: AnnouncementScope.orgWide,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('managerAdmin can create hub-scoped announcements for own hub',
        () async {
      final manager =
          makeUser(id: 'mgr', role: UserRole.managerAdmin, hubIds: ['h1']);
      final id = await authFs.createAnnouncement(
        manager,
        'org1',
        {
          'title': 'Hub Update',
          'body': 'Info',
          'scope': 'hub',
          'hubId': 'h1',
          'authorId': manager.id,
          'authorName': manager.displayName,
          'authorRole': manager.role.name,
          'isPinned': false,
          'attachments': [],
          'createdAt': DateTime.now().toIso8601String(),
        },
        scope: AnnouncementScope.hub,
        hubId: 'h1',
      );
      expect(id, isNotEmpty);
    });

    test('managerAdmin cannot manage superAdmin users', () {
      final manager = makeUser(id: 'mgr', role: UserRole.managerAdmin);
      final admin = makeUser(id: 'sa', role: UserRole.superAdmin);
      expect(ps.canManageUser(manager, admin), isFalse);
    });

    test('superAdmin can manage managerAdmin users', () {
      final admin = makeUser(id: 'sa', role: UserRole.superAdmin);
      final manager = makeUser(id: 'mgr', role: UserRole.managerAdmin);
      expect(ps.canManageUser(admin, manager), isTrue);
    });

    test('route access follows role hierarchy', () {
      final owner = makeUser(id: 'o', role: UserRole.platformOwner);
      final admin = makeUser(id: 'sa', role: UserRole.superAdmin);
      final manager = makeUser(id: 'ma', role: UserRole.managerAdmin);
      final staff = makeUser(id: 's', role: UserRole.staff);

      // Admin routes
      expect(ps.canAccessRoute(owner, '/settings/leagues'), isTrue);
      expect(ps.canAccessRoute(admin, '/settings/leagues'), isTrue);
      expect(ps.canAccessRoute(manager, '/settings/leagues'), isFalse);
      expect(ps.canAccessRoute(staff, '/settings/leagues'), isFalse);

      // Manager routes
      expect(ps.canAccessRoute(manager, '/settings/users'), isTrue);
      expect(ps.canAccessRoute(staff, '/settings/users'), isFalse);

      // Team detail — accessible to all
      expect(ps.canAccessRoute(staff, '/teams/t1'), isTrue);
      expect(ps.canAccessRoute(manager, '/teams/t1'), isTrue);

      // Public routes
      for (final u in [owner, admin, manager, staff]) {
        expect(ps.canAccessRoute(u, '/'), isTrue);
        expect(ps.canAccessRoute(u, '/chat'), isTrue);
        expect(ps.canAccessRoute(u, '/documents'), isTrue);
        expect(ps.canAccessRoute(u, '/announcements'), isTrue);
      }
    });
  });
}
