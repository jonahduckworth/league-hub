import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/permission_service.dart';

// Manual mock with proper null-safe return values via noSuchMethod overrides.
class MockFirestoreService extends Mock implements FirestoreService {
  @override
  Future<void> updateOrganization(String orgId, Map<String, dynamic> data) =>
      (super.noSuchMethod(Invocation.method(#updateOrganization, [orgId, data]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> createLeague(String orgId, League league) =>
      (super.noSuchMethod(Invocation.method(#createLeague, [orgId, league]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> deleteLeague(String orgId, String leagueId) =>
      (super.noSuchMethod(Invocation.method(#deleteLeague, [orgId, leagueId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> createHub(String orgId, String leagueId, Hub hub) =>
      (super.noSuchMethod(Invocation.method(#createHub, [orgId, leagueId, hub]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> createTeam(
          String orgId, String leagueId, String hubId, Team team) =>
      (super.noSuchMethod(
          Invocation.method(#createTeam, [orgId, leagueId, hubId, team]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<String> createChatRoom(String orgId, String name, ChatRoomType type,
          {String? leagueId,
          List<String> participants = const [],
          String? roomIconName,
          String? roomImageUrl}) =>
      (super.noSuchMethod(
          Invocation.method(#createChatRoom, [
            orgId,
            name,
            type
          ], {
            #leagueId: leagueId,
            #participants: participants,
            #roomIconName: roomIconName,
            #roomImageUrl: roomImageUrl,
          }),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<String> createAnnouncement(String orgId, Map<String, dynamic> data) =>
      (super.noSuchMethod(Invocation.method(#createAnnouncement, [orgId, data]),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<String> createDocument(String orgId, Map<String, dynamic> docData,
          {String? docId}) =>
      (super.noSuchMethod(
          Invocation.method(#createDocument, [orgId, docData], {#docId: docId}),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<String> createInvitation(String orgId, Invitation invitation) => (super
      .noSuchMethod(Invocation.method(#createInvitation, [orgId, invitation]),
          returnValue: Future<String>.value('')) as Future<String>);
}

void main() {
  group('Permission Integration Tests (AuthorizedFirestoreService)', () {
    late MockFirestoreService mockFs;
    late PermissionService ps;
    late AuthorizedFirestoreService afs;

    setUp(() {
      mockFs = MockFirestoreService();
      ps = const PermissionService();
      afs = AuthorizedFirestoreService(mockFs, ps);
    });

    tearDown(() {
      resetMockitoState();
    });

    group('platformOwner can do everything', () {
      test('can update organization', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.updateOrganization('org1', {'name': 'New Name'}))
            .thenAnswer((_) => Future.value());

        await afs.updateOrganization(actor, 'org1', {'name': 'New Name'});
        verify(mockFs.updateOrganization('org1', {'name': 'New Name'}))
            .called(1);
      });

      test('can create league', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final league = League(
          id: 'l1',
          orgId: 'org1',
          name: 'League',
          abbreviation: 'L',
          createdAt: DateTime.now(),
        );

        when(mockFs.createLeague('org1', league))
            .thenAnswer((_) => Future.value());

        await afs.createLeague(actor, 'org1', league);
        verify(mockFs.createLeague('org1', league)).called(1);
      });

      test('can delete league', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.deleteLeague('org1', 'l1'))
            .thenAnswer((_) => Future.value());

        await afs.deleteLeague(actor, 'org1', 'l1');
        verify(mockFs.deleteLeague('org1', 'l1')).called(1);
      });

      test('can create hub', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final hub = Hub(
          id: 'h1',
          leagueId: 'l1',
          orgId: 'org1',
          name: 'Hub',
          createdAt: DateTime.now(),
        );

        when(mockFs.createHub('org1', 'l1', hub))
            .thenAnswer((_) => Future.value());

        await afs.createHub(actor, 'org1', 'l1', hub);
        verify(mockFs.createHub('org1', 'l1', hub)).called(1);
      });

      test('can create team', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final team = Team(
          id: 't1',
          hubId: 'h1',
          leagueId: 'l1',
          orgId: 'org1',
          name: 'Team',
          createdAt: DateTime.now(),
        );

        when(mockFs.createTeam('org1', 'l1', 'h1', team))
            .thenAnswer((_) => Future.value());

        await afs.createTeam(actor, 'org1', 'l1', 'h1', team);
        verify(mockFs.createTeam('org1', 'l1', 'h1', team)).called(1);
      });

      test('can create chat room', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.createChatRoom('org1', 'General', ChatRoomType.league,
            leagueId: null,
            participants: const [])).thenAnswer((_) => Future.value('room1'));

        final roomId = await afs.createChatRoom(
            actor, 'org1', 'General', ChatRoomType.league);
        expect(roomId, 'room1');
      });

      test('can create announcement (org-wide)', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.createAnnouncement('org1', {'title': 'Announcement'}))
            .thenAnswer((_) => Future.value('ann1'));

        final annId = await afs.createAnnouncement(
          actor,
          'org1',
          {'title': 'Announcement'},
          scope: AnnouncementScope.orgWide,
        );
        expect(annId, 'ann1');
      });

      test('can create document', () async {
        final actor = AppUser(
          id: 'po1',
          email: 'po@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.createDocument('org1', {'name': 'Document'}, docId: null))
            .thenAnswer((_) => Future.value('doc1'));

        final docId =
            await afs.createDocument(actor, 'org1', {'name': 'Document'});
        expect(docId, 'doc1');
      });
    });

    group('superAdmin can manage orgs and do everything else', () {
      test('can update organization', () async {
        final actor = AppUser(
          id: 'sa1',
          email: 'sa@example.com',
          displayName: 'Super Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.updateOrganization('org1', {'name': 'Updated'}))
            .thenAnswer((_) => Future.value());

        await afs.updateOrganization(actor, 'org1', {'name': 'Updated'});
        verify(mockFs.updateOrganization('org1', {'name': 'Updated'}))
            .called(1);
      });

      test('can create league', () async {
        final actor = AppUser(
          id: 'sa1',
          email: 'sa@example.com',
          displayName: 'Super Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final league = League(
          id: 'l1',
          orgId: 'org1',
          name: 'League',
          abbreviation: 'L',
          createdAt: DateTime.now(),
        );

        when(mockFs.createLeague('org1', league))
            .thenAnswer((_) => Future.value());

        await afs.createLeague(actor, 'org1', league);
        verify(mockFs.createLeague('org1', league)).called(1);
      });

      test('can create chat room', () async {
        final actor = AppUser(
          id: 'sa1',
          email: 'sa@example.com',
          displayName: 'Super Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.createChatRoom('org1', 'General', ChatRoomType.league,
            leagueId: null,
            participants: const [])).thenAnswer((_) => Future.value('room1'));

        final roomId = await afs.createChatRoom(
            actor, 'org1', 'General', ChatRoomType.league);
        expect(roomId, 'room1');
      });

      test('can create announcement (any scope)', () async {
        final actor = AppUser(
          id: 'sa1',
          email: 'sa@example.com',
          displayName: 'Super Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.createAnnouncement('org1', {'title': 'Announcement'}))
            .thenAnswer((_) => Future.value('ann1'));

        final annId = await afs.createAnnouncement(
          actor,
          'org1',
          {'title': 'Announcement'},
          scope: AnnouncementScope.orgWide,
        );
        expect(annId, 'ann1');
      });
    });

    group('managerAdmin can only operate within their scope', () {
      test('can create hub in assigned league', () async {
        final actor = AppUser(
          id: 'ma1',
          email: 'ma@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final hub = Hub(
          id: 'h2',
          leagueId: 'l1',
          orgId: 'org1',
          name: 'New Hub',
          createdAt: DateTime.now(),
        );

        when(mockFs.createHub('org1', 'l1', hub))
            .thenAnswer((_) => Future.value());

        await afs.createHub(actor, 'org1', 'l1', hub);
        verify(mockFs.createHub('org1', 'l1', hub)).called(1);
      });

      test('can create team in their hub', () async {
        final hubId = 'h1';
        final actor = AppUser(
          id: 'ma1',
          email: 'ma@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: [hubId],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final team = Team(
          id: 't1',
          hubId: hubId,
          leagueId: 'l1',
          orgId: 'org1',
          name: 'Team',
          createdAt: DateTime.now(),
        );

        when(mockFs.createTeam('org1', 'l1', hubId, team))
            .thenAnswer((_) => Future.value());

        await afs.createTeam(actor, 'org1', 'l1', hubId, team);
        verify(mockFs.createTeam('org1', 'l1', hubId, team)).called(1);
      });

      test('cannot create team in another hub', () async {
        final actor = AppUser(
          id: 'ma1',
          email: 'ma@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final team = Team(
          id: 't1',
          hubId: 'h2',
          leagueId: 'l1',
          orgId: 'org1',
          name: 'Team',
          createdAt: DateTime.now(),
        );

        expect(
          () => afs.createTeam(actor, 'org1', 'l1', 'h2', team),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('cannot create org-wide announcement', () async {
        final actor = AppUser(
          id: 'ma1',
          email: 'ma@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        expect(
          () => afs.createAnnouncement(
            actor,
            'org1',
            {'title': 'Announcement'},
            scope: AnnouncementScope.orgWide,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('can create hub-scoped announcement in their hub', () async {
        final hubId = 'h1';
        final actor = AppUser(
          id: 'ma1',
          email: 'ma@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: [hubId],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        when(mockFs.createAnnouncement('org1', {'title': 'Announcement'}))
            .thenAnswer((_) => Future.value('ann1'));

        final annId = await afs.createAnnouncement(
          actor,
          'org1',
          {'title': 'Announcement'},
          scope: AnnouncementScope.hub,
          hubId: hubId,
        );
        expect(annId, 'ann1');
      });

      test('cannot create hub-scoped announcement in another hub', () async {
        final actor = AppUser(
          id: 'ma1',
          email: 'ma@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        expect(
          () => afs.createAnnouncement(
            actor,
            'org1',
            {'title': 'Announcement'},
            scope: AnnouncementScope.hub,
            hubId: 'h2',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('staff is denied on all write operations', () {
      test('cannot create league', () async {
        final actor = AppUser(
          id: 'st1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final league = League(
          id: 'l1',
          orgId: 'org1',
          name: 'League',
          abbreviation: 'L',
          createdAt: DateTime.now(),
        );

        expect(
          () => afs.createLeague(actor, 'org1', league),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('cannot create hub', () async {
        final actor = AppUser(
          id: 'st1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final hub = Hub(
          id: 'h1',
          leagueId: 'l1',
          orgId: 'org1',
          name: 'Hub',
          createdAt: DateTime.now(),
        );

        expect(
          () => afs.createHub(actor, 'org1', 'l1', hub),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('cannot create team', () async {
        final actor = AppUser(
          id: 'st1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );
        final team = Team(
          id: 't1',
          hubId: 'h1',
          leagueId: 'l1',
          orgId: 'org1',
          name: 'Team',
          createdAt: DateTime.now(),
        );

        expect(
          () => afs.createTeam(actor, 'org1', 'l1', 'h1', team),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('cannot create chat room', () async {
        final actor = AppUser(
          id: 'st1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        expect(
          () =>
              afs.createChatRoom(actor, 'org1', 'General', ChatRoomType.league),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('cannot create announcement', () async {
        final actor = AppUser(
          id: 'st1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        expect(
          () => afs.createAnnouncement(
            actor,
            'org1',
            {'title': 'Announcement'},
            scope: AnnouncementScope.league,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('cannot create document', () async {
        final actor = AppUser(
          id: 'st1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        expect(
          () => afs.createDocument(actor, 'org1', {'name': 'Document'}),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('inactive user is denied all operations', () {
      test('inactive user cannot do anything', () async {
        final actor = AppUser(
          id: 'inactive1',
          email: 'inactive@example.com',
          displayName: 'Inactive',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: false,
        );
        final league = League(
          id: 'l1',
          orgId: 'org1',
          name: 'League',
          abbreviation: 'L',
          createdAt: DateTime.now(),
        );

        expect(
          () => afs.createLeague(actor, 'org1', league),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
  });
}
