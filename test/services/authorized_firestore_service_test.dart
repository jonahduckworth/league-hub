import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/permission_service.dart';

// Manual mock for FirestoreService with proper null-safe return values.
// Each override calls super.noSuchMethod with a non-null returnValue so that
// Mockito's when() / verify() machinery works under sound null safety.
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
  Stream<List<Hub>> getHubs(String orgId, String leagueId) =>
      (super.noSuchMethod(Invocation.method(#getHubs, [orgId, leagueId]),
          returnValue: Stream<List<Hub>>.value([])) as Stream<List<Hub>>);

  @override
  Stream<List<Team>> getTeams(String orgId, String leagueId, String hubId) =>
      (super.noSuchMethod(
          Invocation.method(#getTeams, [orgId, leagueId, hubId]),
          returnValue: Stream<List<Team>>.value([])) as Stream<List<Team>>);

  @override
  Future<void> deleteTeam(
          String orgId, String leagueId, String hubId, String teamId) =>
      (super.noSuchMethod(
          Invocation.method(#deleteTeam, [orgId, leagueId, hubId, teamId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> createHub(String orgId, String leagueId, Hub hub) =>
      (super.noSuchMethod(Invocation.method(#createHub, [orgId, leagueId, hub]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> deleteHub(String orgId, String leagueId, String hubId) => (super
      .noSuchMethod(Invocation.method(#deleteHub, [orgId, leagueId, hubId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> createTeam(
          String orgId, String leagueId, String hubId, Team team) =>
      (super.noSuchMethod(
          Invocation.method(#createTeam, [orgId, leagueId, hubId, team]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> updateTeamFields(String orgId, String leagueId, String hubId,
          String teamId, Map<String, dynamic> data) =>
      (super.noSuchMethod(
          Invocation.method(
              #updateTeamFields, [orgId, leagueId, hubId, teamId, data]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> sendMediaMessage(String orgId, String roomId,
          {required String senderId,
          required String senderName,
          required String mediaUrl,
          required String mediaType,
          String? caption}) =>
      (super.noSuchMethod(
          Invocation.method(#sendMediaMessage, [
            orgId,
            roomId
          ], {
            #senderId: senderId,
            #senderName: senderName,
            #mediaUrl: mediaUrl,
            #mediaType: mediaType,
            #caption: caption,
          }),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> updateMessage(
          String orgId, String roomId, String messageId, String newText) =>
      (super.noSuchMethod(
          Invocation.method(
              #updateMessage, [orgId, roomId, messageId, newText]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> deleteMessage(String orgId, String roomId, String messageId) =>
      (super.noSuchMethod(
          Invocation.method(#deleteMessage, [orgId, roomId, messageId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> deactivateUser(String uid) =>
      (super.noSuchMethod(Invocation.method(#deactivateUser, [uid]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> reactivateUser(String uid) =>
      (super.noSuchMethod(Invocation.method(#reactivateUser, [uid]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) =>
      (super.noSuchMethod(Invocation.method(#updateUserFields, [uid, data]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<String> createChatRoom(String orgId, String name, ChatRoomType type,
          {String? leagueId,
          String? hubId,
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
            #hubId: hubId,
            #participants: participants,
            #roomIconName: roomIconName,
            #roomImageUrl: roomImageUrl,
          }),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<void> archiveChatRoom(String orgId, String roomId) =>
      (super.noSuchMethod(Invocation.method(#archiveChatRoom, [orgId, roomId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> updateChatRoomFields(
          String orgId, String roomId, Map<String, dynamic> data) =>
      (super.noSuchMethod(
          Invocation.method(#updateChatRoomFields, [orgId, roomId, data]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> sendMessage(String orgId, String roomId,
          {required String senderId,
          required String senderName,
          required String text}) =>
      (super.noSuchMethod(
          Invocation.method(#sendMessage, [orgId, roomId],
              {#senderId: senderId, #senderName: senderName, #text: text}),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<String> createDocument(String orgId, Map<String, dynamic> docData,
          {String? docId}) =>
      (super.noSuchMethod(
          Invocation.method(#createDocument, [orgId, docData], {#docId: docId}),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<void> updateDocument(
          String orgId, String docId, Map<String, dynamic> data) =>
      (super.noSuchMethod(
          Invocation.method(#updateDocument, [orgId, docId, data]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> deleteDocument(String orgId, String docId) =>
      (super.noSuchMethod(Invocation.method(#deleteDocument, [orgId, docId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> addDocumentVersion(
          String orgId, String docId, Map<String, dynamic> versionData) =>
      (super.noSuchMethod(
          Invocation.method(#addDocumentVersion, [orgId, docId, versionData]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<String> createAnnouncement(String orgId, Map<String, dynamic> data) =>
      (super.noSuchMethod(Invocation.method(#createAnnouncement, [orgId, data]),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<void> updateAnnouncement(
          String orgId, String announcementId, Map<String, dynamic> data) =>
      (super.noSuchMethod(
          Invocation.method(#updateAnnouncement, [orgId, announcementId, data]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> deleteAnnouncement(String orgId, String announcementId) =>
      (super.noSuchMethod(
          Invocation.method(#deleteAnnouncement, [orgId, announcementId]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<void> togglePin(String orgId, String announcementId, bool isPinned) =>
      (super.noSuchMethod(
          Invocation.method(#togglePin, [orgId, announcementId, isPinned]),
          returnValue: Future<void>.value()) as Future<void>);

  @override
  Future<String> createInvitation(String orgId, Invitation invitation) => (super
      .noSuchMethod(Invocation.method(#createInvitation, [orgId, invitation]),
          returnValue: Future<String>.value('')) as Future<String>);

  @override
  Future<void> acceptInvitation(String orgId, String inviteId) => (super
      .noSuchMethod(Invocation.method(#acceptInvitation, [orgId, inviteId]),
          returnValue: Future<void>.value()) as Future<void>);
}

// Helper factory for creating test users
AppUser makeUser({
  String id = 'u1',
  UserRole role = UserRole.staff,
  String? orgId = 'org1',
  List<String> hubIds = const [],
  List<String> teamIds = const [],
  bool isActive = true,
}) =>
    AppUser(
      id: id,
      email: '$id@test.com',
      displayName: 'User $id',
      role: role,
      orgId: orgId,
      hubIds: hubIds,
      teamIds: teamIds,
      createdAt: DateTime(2024),
      isActive: isActive,
    );

// Helper factory for creating test hubs
Hub makeHub({
  String id = 'h1',
  String leagueId = 'l1',
  String orgId = 'org1',
  String name = 'Hub 1',
  String? location,
}) =>
    Hub(
      id: id,
      leagueId: leagueId,
      orgId: orgId,
      name: name,
      location: location,
      createdAt: DateTime(2024),
    );

// Helper factory for creating test teams
Team makeTeam({
  String id = 't1',
  String hubId = 'h1',
  String leagueId = 'l1',
  String orgId = 'org1',
  String name = 'Team 1',
  String? ageGroup,
  String? division,
}) =>
    Team(
      id: id,
      hubId: hubId,
      leagueId: leagueId,
      orgId: orgId,
      name: name,
      ageGroup: ageGroup,
      division: division,
      createdAt: DateTime(2024),
    );

// Helper factory for creating test leagues
League makeLeague({
  String id = 'l1',
  String orgId = 'org1',
  String name = 'League 1',
  String abbreviation = 'L1',
}) =>
    League(
      id: id,
      orgId: orgId,
      name: name,
      abbreviation: abbreviation,
      createdAt: DateTime(2024),
    );

// Helper factory for creating test invitations
Invitation makeInvitation({
  String id = 'inv1',
  String orgId = 'org1',
  String email = 'newuser@test.com',
  String? displayName,
  String role = 'staff',
  List<String> hubIds = const ['h1'],
  List<String> teamIds = const [],
  String invitedBy = 'u1',
  String invitedByName = 'User 1',
  InvitationStatus status = InvitationStatus.pending,
}) =>
    Invitation(
      id: id,
      orgId: orgId,
      email: email,
      displayName: displayName,
      role: role,
      hubIds: hubIds,
      teamIds: teamIds,
      invitedBy: invitedBy,
      invitedByName: invitedByName,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: status,
      token: 'token-123',
    );

void main() {
  group('AuthorizedFirestoreService', () {
    late MockFirestoreService mockFs;
    late PermissionService ps;
    late AuthorizedFirestoreService afs;

    setUp(() {
      provideDummy<Future<void>>(Future.value());
      provideDummy<Future<String>>(Future.value(''));
      provideDummy<Stream<List<Hub>>>(Stream.value([]));
      provideDummy<Stream<List<Team>>>(Stream.value([]));
      mockFs = MockFirestoreService();
      ps = const PermissionService();
      afs = AuthorizedFirestoreService(mockFs, ps);
    });

    tearDown(() {
      resetMockitoState();
    });

    // =========================================================================
    // Organizations
    // =========================================================================

    group('updateOrganization', () {
      test('throws PermissionDeniedException when staff tries to update org',
          () async {
        final staff = makeUser(role: UserRole.staff);
        final data = {'name': 'New Org Name'};

        expect(
          () => afs.updateOrganization(staff, 'org1', data),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to update org',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);
        final data = {'name': 'New Org Name'};

        expect(
          () => afs.updateOrganization(managerAdmin, 'org1', data),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin updates org', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final data = {'name': 'New Org Name'};

        when(mockFs.updateOrganization('org1', data))
            .thenAnswer((_) async => {});

        await afs.updateOrganization(superAdmin, 'org1', data);

        verify(mockFs.updateOrganization('org1', data)).called(1);
      });

      test('calls FirestoreService when platformOwner updates org', () async {
        final platformOwner = makeUser(role: UserRole.platformOwner);
        final data = {'name': 'New Org Name'};

        when(mockFs.updateOrganization('org1', data))
            .thenAnswer((_) async => {});

        await afs.updateOrganization(platformOwner, 'org1', data);

        verify(mockFs.updateOrganization('org1', data)).called(1);
      });
    });

    // =========================================================================
    // Leagues
    // =========================================================================

    group('createLeague', () {
      test('throws PermissionDeniedException when staff tries to create league',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.createLeague(staff, 'org1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin creates league', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final league = makeLeague();

        when(mockFs.createLeague('org1', league)).thenAnswer((_) async {});

        await afs.createLeague(superAdmin, 'org1', league);

        verify(mockFs.createLeague('org1', league)).called(1);
      });

      test('calls FirestoreService when platformOwner creates league',
          () async {
        final platformOwner = makeUser(role: UserRole.platformOwner);
        final league = makeLeague();

        when(mockFs.createLeague('org1', league)).thenAnswer((_) async {});

        await afs.createLeague(platformOwner, 'org1', league);

        verify(mockFs.createLeague('org1', league)).called(1);
      });
    });

    group('deleteLeague', () {
      test('throws PermissionDeniedException when staff tries to delete league',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.deleteLeague(staff, 'org1', 'l1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin deletes league', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.deleteLeague('org1', 'l1')).thenAnswer((_) async => {});

        await afs.deleteLeague(superAdmin, 'org1', 'l1');

        verify(mockFs.deleteLeague('org1', 'l1')).called(1);
      });
    });

    group('deleteLeagueCascade', () {
      test(
          'throws PermissionDeniedException when staff tries to cascade delete league',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.deleteLeagueCascade(staff, 'org1', 'l1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('cascade deletes league with all hubs and teams', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final hub = makeHub();
        final team = makeTeam();

        when(mockFs.getHubs('org1', 'l1'))
            .thenAnswer((_) => Stream.value([hub]));
        when(mockFs.getTeams('org1', 'l1', 'h1'))
            .thenAnswer((_) => Stream.value([team]));
        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't1'))
            .thenAnswer((_) async => {});
        when(mockFs.deleteHub('org1', 'l1', 'h1')).thenAnswer((_) async => {});
        when(mockFs.deleteLeague('org1', 'l1')).thenAnswer((_) async => {});

        await afs.deleteLeagueCascade(superAdmin, 'org1', 'l1');

        verify(mockFs.getHubs('org1', 'l1')).called(1);
        verify(mockFs.getTeams('org1', 'l1', 'h1')).called(1);
        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't1')).called(1);
        verify(mockFs.deleteHub('org1', 'l1', 'h1')).called(1);
        verify(mockFs.deleteLeague('org1', 'l1')).called(1);
      });

      test('cascade deletes multiple hubs and teams', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final hub1 = makeHub(id: 'h1');
        final hub2 = makeHub(id: 'h2');
        final team1 = makeTeam(id: 't1', hubId: 'h1');
        final team2 = makeTeam(id: 't2', hubId: 'h2');

        when(mockFs.getHubs('org1', 'l1'))
            .thenAnswer((_) => Stream.value([hub1, hub2]));
        when(mockFs.getTeams('org1', 'l1', 'h1'))
            .thenAnswer((_) => Stream.value([team1]));
        when(mockFs.getTeams('org1', 'l1', 'h2'))
            .thenAnswer((_) => Stream.value([team2]));
        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't1'))
            .thenAnswer((_) async {});
        when(mockFs.deleteTeam('org1', 'l1', 'h2', 't2'))
            .thenAnswer((_) async {});
        when(mockFs.deleteHub('org1', 'l1', 'h1')).thenAnswer((_) async {});
        when(mockFs.deleteHub('org1', 'l1', 'h2')).thenAnswer((_) async {});
        when(mockFs.deleteLeague('org1', 'l1')).thenAnswer((_) async {});

        await afs.deleteLeagueCascade(superAdmin, 'org1', 'l1');

        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't1')).called(1);
        verify(mockFs.deleteTeam('org1', 'l1', 'h2', 't2')).called(1);
        verify(mockFs.deleteHub('org1', 'l1', 'h1')).called(1);
        verify(mockFs.deleteHub('org1', 'l1', 'h2')).called(1);
      });
    });

    // =========================================================================
    // Hubs
    // =========================================================================

    group('createHub', () {
      test('throws PermissionDeniedException when staff tries to create hub',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.createHub(staff, 'org1', 'l1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin creates hub', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final hub = makeHub();

        when(mockFs.createHub('org1', 'l1', hub)).thenAnswer((_) async {});

        await afs.createHub(superAdmin, 'org1', 'l1', hub);

        verify(mockFs.createHub('org1', 'l1', hub)).called(1);
      });

      test(
          'calls FirestoreService when managerAdmin with hub assignment creates hub',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final hub = makeHub();

        when(mockFs.createHub('org1', 'l1', hub)).thenAnswer((_) async {});

        await afs.createHub(managerAdmin, 'org1', 'l1', hub);

        verify(mockFs.createHub('org1', 'l1', hub)).called(1);
      });

      // managerAdmin can always create hubs per current PermissionService logic
      test(
          'calls FirestoreService when managerAdmin without hub assignment creates hub',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin, hubIds: []);
        final hub = makeHub();

        when(mockFs.createHub('org1', 'l1', hub)).thenAnswer((_) async {});

        await afs.createHub(managerAdmin, 'org1', 'l1', hub);

        verify(mockFs.createHub('org1', 'l1', hub)).called(1);
      });
    });

    group('deleteHub', () {
      test('throws PermissionDeniedException when staff tries to delete hub',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.deleteHub(staff, 'org1', 'l1', 'h1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to delete hub',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);

        expect(
          () => afs.deleteHub(managerAdmin, 'org1', 'l1', 'h1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin deletes hub', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.deleteHub('org1', 'l1', 'h1')).thenAnswer((_) async => {});

        await afs.deleteHub(superAdmin, 'org1', 'l1', 'h1');

        verify(mockFs.deleteHub('org1', 'l1', 'h1')).called(1);
      });
    });

    group('deleteHubCascade', () {
      test(
          'throws PermissionDeniedException when staff tries to cascade delete hub',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.deleteHubCascade(staff, 'org1', 'l1', 'h1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('cascade deletes hub with all teams', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final team = makeTeam();

        when(mockFs.getTeams('org1', 'l1', 'h1'))
            .thenAnswer((_) => Stream.value([team]));
        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't1'))
            .thenAnswer((_) async => {});
        when(mockFs.deleteHub('org1', 'l1', 'h1')).thenAnswer((_) async => {});

        await afs.deleteHubCascade(superAdmin, 'org1', 'l1', 'h1');

        verify(mockFs.getTeams('org1', 'l1', 'h1')).called(1);
        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't1')).called(1);
        verify(mockFs.deleteHub('org1', 'l1', 'h1')).called(1);
      });

      test('cascade deletes multiple teams', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final team1 = makeTeam(id: 't1');
        final team2 = makeTeam(id: 't2');

        when(mockFs.getTeams('org1', 'l1', 'h1'))
            .thenAnswer((_) => Stream.value([team1, team2]));
        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't1'))
            .thenAnswer((_) async {});
        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't2'))
            .thenAnswer((_) async {});
        when(mockFs.deleteHub('org1', 'l1', 'h1')).thenAnswer((_) async {});

        await afs.deleteHubCascade(superAdmin, 'org1', 'l1', 'h1');

        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't1')).called(1);
        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't2')).called(1);
      });
    });

    // =========================================================================
    // Teams
    // =========================================================================

    group('createTeam', () {
      test('throws PermissionDeniedException when staff tries to create team',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.createTeam(staff, 'org1', 'l1', 'h1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin creates team', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final team = makeTeam();

        when(mockFs.createTeam('org1', 'l1', 'h1', team))
            .thenAnswer((_) async {});

        await afs.createTeam(superAdmin, 'org1', 'l1', 'h1', team);

        verify(mockFs.createTeam('org1', 'l1', 'h1', team)).called(1);
      });

      test(
          'calls FirestoreService when managerAdmin with hub assignment creates team',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final team = makeTeam();

        when(mockFs.createTeam('org1', 'l1', 'h1', team))
            .thenAnswer((_) async {});

        await afs.createTeam(managerAdmin, 'org1', 'l1', 'h1', team);

        verify(mockFs.createTeam('org1', 'l1', 'h1', team)).called(1);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to create team in hub they don\'t own',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h2']);

        expect(
          () => afs.createTeam(managerAdmin, 'org1', 'l1', 'h1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });
    });

    group('deleteTeam', () {
      test('throws PermissionDeniedException when staff tries to delete team',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.deleteTeam(staff, 'org1', 'l1', 'h1', 't1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin deletes team', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't1'))
            .thenAnswer((_) async => {});

        await afs.deleteTeam(superAdmin, 'org1', 'l1', 'h1', 't1');

        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't1')).called(1);
      });

      test(
          'calls FirestoreService when managerAdmin with hub assignment deletes team',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);

        when(mockFs.deleteTeam('org1', 'l1', 'h1', 't1'))
            .thenAnswer((_) async => {});

        await afs.deleteTeam(managerAdmin, 'org1', 'l1', 'h1', 't1');

        verify(mockFs.deleteTeam('org1', 'l1', 'h1', 't1')).called(1);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to delete team in hub they don\'t own',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h2']);

        expect(
          () => afs.deleteTeam(managerAdmin, 'org1', 'l1', 'h1', 't1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });
    });

    // =========================================================================
    // Users
    // =========================================================================

    group('deactivateUser', () {
      test(
          'throws PermissionDeniedException when staff tries to deactivate user',
          () async {
        final staff = makeUser(role: UserRole.staff);
        final target = makeUser(id: 'u2', role: UserRole.staff);

        expect(
          () => afs.deactivateUser(staff, target),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to deactivate higher role',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final target = makeUser(id: 'u2', role: UserRole.superAdmin);

        expect(
          () => afs.deactivateUser(managerAdmin, target),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin deactivates staff user',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final target = makeUser(id: 'u2', role: UserRole.staff);

        when(mockFs.deactivateUser('u2')).thenAnswer((_) async => {});

        await afs.deactivateUser(superAdmin, target);

        verify(mockFs.deactivateUser('u2')).called(1);
      });

      test(
          'calls FirestoreService when managerAdmin deactivates staff in their hub',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final target = makeUser(id: 'u2', role: UserRole.staff, hubIds: ['h1']);

        when(mockFs.deactivateUser('u2')).thenAnswer((_) async => {});

        await afs.deactivateUser(managerAdmin, target);

        verify(mockFs.deactivateUser('u2')).called(1);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to deactivate user outside their hub',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final target = makeUser(id: 'u2', role: UserRole.staff, hubIds: ['h2']);

        expect(
          () => afs.deactivateUser(managerAdmin, target),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });
    });

    group('reactivateUser', () {
      test('calls FirestoreService when superAdmin reactivates user', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final target =
            makeUser(id: 'u2', role: UserRole.staff, isActive: false);

        when(mockFs.reactivateUser('u2')).thenAnswer((_) async => {});

        await afs.reactivateUser(superAdmin, target);

        verify(mockFs.reactivateUser('u2')).called(1);
      });

      test(
          'throws PermissionDeniedException when staff tries to reactivate user',
          () async {
        final staff = makeUser(role: UserRole.staff);
        final target =
            makeUser(id: 'u2', role: UserRole.staff, isActive: false);

        expect(
          () => afs.reactivateUser(staff, target),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });
    });

    group('updateUserFields', () {
      test('throws PermissionDeniedException when staff tries to update user',
          () async {
        final staff = makeUser(role: UserRole.staff);
        final target = makeUser(id: 'u2', role: UserRole.staff);

        expect(
          () => afs.updateUserFields(staff, target, {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when user tries to update themselves through management',
          () async {
        final superAdmin = makeUser(id: 'u1', role: UserRole.superAdmin);

        expect(
          () => afs.updateUserFields(superAdmin, superAdmin, {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin updates user', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final target = makeUser(id: 'u2', role: UserRole.staff);
        final data = {'displayName': 'Updated Name'};

        when(mockFs.updateUserFields('u2', data)).thenAnswer((_) async => {});

        await afs.updateUserFields(superAdmin, target, data);

        verify(mockFs.updateUserFields('u2', data)).called(1);
      });
    });

    // =========================================================================
    // Chat
    // =========================================================================

    group('createChatRoom', () {
      test(
          'throws PermissionDeniedException when staff tries to create chat room',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () =>
              afs.createChatRoom(staff, 'org1', 'Room 1', ChatRoomType.league),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin creates chat room',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);

        when(mockFs.createChatRoom('org1', 'Room 1', ChatRoomType.league,
            leagueId: null,
            participants: [])).thenAnswer((_) async => 'roomId');

        final result = await afs.createChatRoom(
            managerAdmin, 'org1', 'Room 1', ChatRoomType.league);

        expect(result, equals('roomId'));
        verify(mockFs.createChatRoom('org1', 'Room 1', ChatRoomType.league,
            leagueId: null, participants: [])).called(1);
      });

      test('calls FirestoreService when superAdmin creates chat room',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.createChatRoom('org1', 'Room 2', ChatRoomType.event,
            leagueId: 'l1',
            participants: ['u1', 'u2'])).thenAnswer((_) async => 'roomId2');

        final result = await afs.createChatRoom(
          superAdmin,
          'org1',
          'Room 2',
          ChatRoomType.event,
          leagueId: 'l1',
          participants: ['u1', 'u2'],
        );

        expect(result, equals('roomId2'));
      });
    });

    group('archiveChatRoom', () {
      test('throws PermissionDeniedException when staff tries to archive room',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.archiveChatRoom(staff, 'org1', 'room1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin archives room', () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);

        when(mockFs.archiveChatRoom('org1', 'room1'))
            .thenAnswer((_) async => {});

        await afs.archiveChatRoom(managerAdmin, 'org1', 'room1');

        verify(mockFs.archiveChatRoom('org1', 'room1')).called(1);
      });
    });

    group('updateChatRoomFields', () {
      test('throws PermissionDeniedException when staff tries to update room',
          () async {
        final staff = makeUser(role: UserRole.staff);
        final data = {'name': 'Updated'};

        expect(
          () => afs.updateChatRoomFields(staff, 'org1', 'room1', data),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin updates room', () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);
        final data = {
          'name': 'Updated',
          'roomIconName': 'trophy',
          'roomImageUrl': null,
        };

        when(mockFs.updateChatRoomFields('org1', 'room1', data))
            .thenAnswer((_) async => {});

        await afs.updateChatRoomFields(managerAdmin, 'org1', 'room1', data);

        verify(mockFs.updateChatRoomFields('org1', 'room1', data)).called(1);
      });
    });

    group('sendMessage', () {
      test(
          'throws PermissionDeniedException when inactive user tries to send message',
          () async {
        final inactive = makeUser(role: UserRole.staff, isActive: false);

        expect(
          () => afs.sendMessage(inactive, 'org1', 'room1', text: 'Hello'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService with actor.id as senderId for staff',
          () async {
        final staff = makeUser(id: 'u1', role: UserRole.staff);

        when(mockFs.sendMessage(
          'org1',
          'room1',
          senderId: 'u1',
          senderName: 'User u1',
          text: 'Hello',
        )).thenAnswer((_) async => {});

        await afs.sendMessage(staff, 'org1', 'room1', text: 'Hello');

        verify(mockFs.sendMessage(
          'org1',
          'room1',
          senderId: 'u1',
          senderName: 'User u1',
          text: 'Hello',
        )).called(1);
      });

      test('enforces senderId matches actor.id', () async {
        final user = makeUser(id: 'u1', role: UserRole.staff);

        when(mockFs.sendMessage(
          'org1',
          'room1',
          senderId: 'u1',
          senderName: 'User u1',
          text: 'Message',
        )).thenAnswer((_) async => {});

        await afs.sendMessage(user, 'org1', 'room1', text: 'Message');

        // Verify senderId is exactly the actor's id, not something else
        verify(mockFs.sendMessage(
          'org1',
          'room1',
          senderId: 'u1',
          senderName: 'User u1',
          text: 'Message',
        )).called(1);
      });

      test('calls FirestoreService when managerAdmin sends message', () async {
        final managerAdmin = makeUser(id: 'u2', role: UserRole.managerAdmin);

        when(mockFs.sendMessage(
          'org1',
          'room1',
          senderId: 'u2',
          senderName: 'User u2',
          text: 'Admin message',
        )).thenAnswer((_) async => {});

        await afs.sendMessage(managerAdmin, 'org1', 'room1',
            text: 'Admin message');

        verify(mockFs.sendMessage(
          'org1',
          'room1',
          senderId: 'u2',
          senderName: 'User u2',
          text: 'Admin message',
        )).called(1);
      });
    });

    // =========================================================================
    // Documents
    // =========================================================================

    group('createDocument', () {
      test(
          'throws PermissionDeniedException when staff tries to create document',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.createDocument(staff, 'org1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin creates document',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);
        final docData = {'title': 'Document'};

        when(mockFs.createDocument('org1', docData, docId: null))
            .thenAnswer((_) async => 'docId');

        final result = await afs.createDocument(managerAdmin, 'org1', docData);

        expect(result, equals('docId'));
        verify(mockFs.createDocument('org1', docData, docId: null)).called(1);
      });

      test(
          'calls FirestoreService when superAdmin creates document with specific docId',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final docData = {'title': 'Document'};

        when(mockFs.createDocument('org1', docData, docId: 'specific-id'))
            .thenAnswer((_) async => 'specific-id');

        final result = await afs.createDocument(
          superAdmin,
          'org1',
          docData,
          docId: 'specific-id',
        );

        expect(result, equals('specific-id'));
        verify(mockFs.createDocument('org1', docData, docId: 'specific-id'))
            .called(1);
      });
    });

    group('updateDocument', () {
      test(
          'throws PermissionDeniedException when staff tries to update document',
          () async {
        final staff = makeUser(id: 'u1', role: UserRole.staff);

        expect(
          () => afs.updateDocument(staff, 'org1', 'doc1', {}, uploadedBy: 'u1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to edit document by different author',
          () async {
        final managerAdmin = makeUser(id: 'u1', role: UserRole.managerAdmin);

        expect(
          () => afs.updateDocument(managerAdmin, 'org1', 'doc1', {},
              uploadedBy: 'u2'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin edits their own document',
          () async {
        final managerAdmin = makeUser(id: 'u1', role: UserRole.managerAdmin);
        final data = {'title': 'Updated'};

        when(mockFs.updateDocument('org1', 'doc1', data))
            .thenAnswer((_) async => {});

        await afs.updateDocument(managerAdmin, 'org1', 'doc1', data,
            uploadedBy: 'u1');

        verify(mockFs.updateDocument('org1', 'doc1', data)).called(1);
      });

      test('calls FirestoreService when superAdmin edits any document',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final data = {'title': 'Updated'};

        when(mockFs.updateDocument('org1', 'doc1', data))
            .thenAnswer((_) async => {});

        await afs.updateDocument(superAdmin, 'org1', 'doc1', data,
            uploadedBy: 'u2');

        verify(mockFs.updateDocument('org1', 'doc1', data)).called(1);
      });
    });

    group('deleteDocument', () {
      test(
          'throws PermissionDeniedException when managerAdmin tries to delete document',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);

        expect(
          () => afs.deleteDocument(managerAdmin, 'org1', 'doc1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin deletes document', () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.deleteDocument('org1', 'doc1')).thenAnswer((_) async => {});

        await afs.deleteDocument(superAdmin, 'org1', 'doc1');

        verify(mockFs.deleteDocument('org1', 'doc1')).called(1);
      });
    });

    group('addDocumentVersion', () {
      test('throws PermissionDeniedException when staff tries to add version',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.addDocumentVersion(staff, 'org1', 'doc1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin adds version', () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);
        final versionData = {'url': 'https://...', 'fileSize': 1024};

        when(mockFs.addDocumentVersion('org1', 'doc1', versionData))
            .thenAnswer((_) async => {});

        await afs.addDocumentVersion(managerAdmin, 'org1', 'doc1', versionData);

        verify(mockFs.addDocumentVersion('org1', 'doc1', versionData))
            .called(1);
      });
    });

    // =========================================================================
    // Announcements
    // =========================================================================

    group('createAnnouncement', () {
      test(
          'throws PermissionDeniedException when staff tries to create announcement',
          () async {
        final staff = makeUser(role: UserRole.staff);

        expect(
          () => afs.createAnnouncement(
            staff,
            'org1',
            {},
            scope: AnnouncementScope.orgWide,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to create org-wide announcement',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);

        expect(
          () => afs.createAnnouncement(
            managerAdmin,
            'org1',
            {},
            scope: AnnouncementScope.orgWide,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'calls FirestoreService when managerAdmin creates hub-scoped announcement in their hub',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final data = {'title': 'Announcement'};

        when(mockFs.createAnnouncement('org1', data))
            .thenAnswer((_) async => 'announceId');

        final result = await afs.createAnnouncement(
          managerAdmin,
          'org1',
          data,
          scope: AnnouncementScope.hub,
          hubId: 'h1',
        );

        expect(result, equals('announceId'));
        verify(mockFs.createAnnouncement('org1', data)).called(1);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to create announcement in hub they don\'t own',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);

        expect(
          () => afs.createAnnouncement(
            managerAdmin,
            'org1',
            {},
            scope: AnnouncementScope.hub,
            hubId: 'h2',
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'calls FirestoreService when superAdmin creates org-wide announcement',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final data = {'title': 'Global Announcement'};

        when(mockFs.createAnnouncement('org1', data))
            .thenAnswer((_) async => 'announceId');

        final result = await afs.createAnnouncement(
          superAdmin,
          'org1',
          data,
          scope: AnnouncementScope.orgWide,
        );

        expect(result, equals('announceId'));
      });

      test(
          'calls FirestoreService when managerAdmin creates league-scoped announcement',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final data = {'title': 'League Announcement'};

        when(mockFs.createAnnouncement('org1', data))
            .thenAnswer((_) async => 'announceId');

        final result = await afs.createAnnouncement(
          managerAdmin,
          'org1',
          data,
          scope: AnnouncementScope.league,
        );

        expect(result, equals('announceId'));
      });
    });

    group('updateAnnouncement', () {
      test(
          'throws PermissionDeniedException when staff tries to update announcement',
          () async {
        final staff = makeUser(id: 'u1', role: UserRole.staff);

        expect(
          () =>
              afs.updateAnnouncement(staff, 'org1', 'ann1', {}, authorId: 'u1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when user tries to edit announcement by different author',
          () async {
        final managerAdmin = makeUser(id: 'u1', role: UserRole.managerAdmin);

        expect(
          () => afs.updateAnnouncement(managerAdmin, 'org1', 'ann1', {},
              authorId: 'u2'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when user edits their own announcement',
          () async {
        final managerAdmin = makeUser(id: 'u1', role: UserRole.managerAdmin);
        final data = {'title': 'Updated'};

        when(mockFs.updateAnnouncement('org1', 'ann1', data))
            .thenAnswer((_) async => {});

        await afs.updateAnnouncement(managerAdmin, 'org1', 'ann1', data,
            authorId: 'u1');

        verify(mockFs.updateAnnouncement('org1', 'ann1', data)).called(1);
      });

      test('calls FirestoreService when superAdmin edits any announcement',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final data = {'title': 'Updated'};

        when(mockFs.updateAnnouncement('org1', 'ann1', data))
            .thenAnswer((_) async => {});

        await afs.updateAnnouncement(superAdmin, 'org1', 'ann1', data,
            authorId: 'u2');

        verify(mockFs.updateAnnouncement('org1', 'ann1', data)).called(1);
      });
    });

    group('deleteAnnouncement', () {
      test(
          'throws PermissionDeniedException when managerAdmin tries to delete announcement',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);

        expect(
          () => afs.deleteAnnouncement(managerAdmin, 'org1', 'ann1'),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin deletes announcement',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.deleteAnnouncement('org1', 'ann1'))
            .thenAnswer((_) async => {});

        await afs.deleteAnnouncement(superAdmin, 'org1', 'ann1');

        verify(mockFs.deleteAnnouncement('org1', 'ann1')).called(1);
      });
    });

    group('togglePin', () {
      test(
          'throws PermissionDeniedException when managerAdmin tries to toggle pin',
          () async {
        final managerAdmin = makeUser(role: UserRole.managerAdmin);

        expect(
          () => afs.togglePin(managerAdmin, 'org1', 'ann1', true),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin pins announcement',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.togglePin('org1', 'ann1', true))
            .thenAnswer((_) async => {});

        await afs.togglePin(superAdmin, 'org1', 'ann1', true);

        verify(mockFs.togglePin('org1', 'ann1', true)).called(1);
      });

      test('calls FirestoreService when superAdmin unpins announcement',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);

        when(mockFs.togglePin('org1', 'ann1', false))
            .thenAnswer((_) async => {});

        await afs.togglePin(superAdmin, 'org1', 'ann1', false);

        verify(mockFs.togglePin('org1', 'ann1', false)).called(1);
      });
    });

    // =========================================================================
    // Invitations
    // =========================================================================

    group('createInvitation', () {
      test(
          'throws PermissionDeniedException when staff tries to create invitation',
          () async {
        final staff = makeUser(role: UserRole.staff);
        final invitation = makeInvitation();

        expect(
          () => afs.createInvitation(staff, 'org1', invitation),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when managerAdmin invites to their hub',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final invitation = makeInvitation(hubIds: ['h1']);

        when(mockFs.createInvitation('org1', invitation))
            .thenAnswer((_) async => 'token');

        final result =
            await afs.createInvitation(managerAdmin, 'org1', invitation);

        expect(result, equals('token'));
        verify(mockFs.createInvitation('org1', invitation)).called(1);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to invite to hub they don\'t own',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final invitation = makeInvitation(hubIds: ['h2']);

        expect(
          () => afs.createInvitation(managerAdmin, 'org1', invitation),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test(
          'throws PermissionDeniedException when managerAdmin tries to invite to multiple hubs, one they don\'t own',
          () async {
        final managerAdmin =
            makeUser(role: UserRole.managerAdmin, hubIds: ['h1']);
        final invitation = makeInvitation(hubIds: ['h1', 'h2']);

        expect(
          () => afs.createInvitation(managerAdmin, 'org1', invitation),
          throwsA(isA<PermissionDeniedException>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('calls FirestoreService when superAdmin invites to multiple hubs',
          () async {
        final superAdmin = makeUser(role: UserRole.superAdmin);
        final invitation = makeInvitation(hubIds: ['h1', 'h2']);

        when(mockFs.createInvitation('org1', invitation))
            .thenAnswer((_) async => 'token');

        final result =
            await afs.createInvitation(superAdmin, 'org1', invitation);

        expect(result, equals('token'));
        verify(mockFs.createInvitation('org1', invitation)).called(1);
      });
    });

    group('acceptInvitation', () {
      test('throws StateError when invitation has expired', () async {
        final expiredDate = DateTime.now().subtract(const Duration(days: 8));

        expect(
          () => afs.acceptInvitation('org1', 'inv1', invitedAt: expiredDate),
          throwsA(isA<StateError>()),
        );

        verifyZeroInteractions(mockFs);
      });

      test('accepts invitation within 7-day default expiry window', () async {
        final invitedDate = DateTime.now().subtract(const Duration(days: 5));

        when(mockFs.acceptInvitation('org1', 'inv1'))
            .thenAnswer((_) async => {});

        await afs.acceptInvitation('org1', 'inv1', invitedAt: invitedDate);

        verify(mockFs.acceptInvitation('org1', 'inv1')).called(1);
      });

      test('accepts invitation at exact expiry boundary', () async {
        // Use 6 days 23 hours to avoid race condition at exact boundary
        final invitedDate =
            DateTime.now().subtract(const Duration(days: 6, hours: 23));

        when(mockFs.acceptInvitation('org1', 'inv1'))
            .thenAnswer((_) async => {});

        await afs.acceptInvitation('org1', 'inv1', invitedAt: invitedDate);

        verify(mockFs.acceptInvitation('org1', 'inv1')).called(1);
      });

      test('respects custom expiryDays parameter', () async {
        final invitedDate = DateTime.now().subtract(const Duration(days: 15));

        when(mockFs.acceptInvitation('org1', 'inv1'))
            .thenAnswer((_) async => {});

        await afs.acceptInvitation(
          'org1',
          'inv1',
          invitedAt: invitedDate,
          expiryDays: 20,
        );

        verify(mockFs.acceptInvitation('org1', 'inv1')).called(1);
      });

      test('throws StateError when invitation exceeds custom expiry days',
          () async {
        final invitedDate = DateTime.now().subtract(const Duration(days: 25));

        expect(
          () => afs.acceptInvitation(
            'org1',
            'inv1',
            invitedAt: invitedDate,
            expiryDays: 20,
          ),
          throwsA(isA<StateError>()),
        );

        verifyZeroInteractions(mockFs);
      });
    });

    // =========================================================================
    // Raw service delegation
    // =========================================================================

    group('raw property', () {
      test('provides access to underlying FirestoreService', () {
        expect(afs.raw, equals(mockFs));
      });
    });

    // =========================================================================
    // PermissionDeniedException details
    // =========================================================================

    group('PermissionDeniedException', () {
      test('includes action, userId, and role in exception', () {
        final staff = makeUser(id: 'u1', role: UserRole.staff);

        try {
          afs.deleteLeague(staff, 'org1', 'l1');
          fail('Should have thrown PermissionDeniedException');
        } on PermissionDeniedException catch (e) {
          expect(e.action, equals('deleteLeague'));
          expect(e.userId, equals('u1'));
          expect(e.role, equals(UserRole.staff));
          expect(
            e.toString(),
            contains('user u1'),
          );
        }
      });

      test('exception toString provides readable format', () {
        final staff = makeUser(id: 'u2', role: UserRole.staff);

        try {
          afs.createHub(staff, 'org1', 'l1', {});
          fail('Should have thrown PermissionDeniedException');
        } on PermissionDeniedException catch (e) {
          expect(e.toString(), contains('PermissionDenied'));
          expect(e.toString(), contains('u2'));
          expect(e.toString(), contains('staff'));
          expect(e.toString(), contains('createHub'));
        }
      });
    });

    // -------------------------------------------------------------------
    // updateTeamFields
    // -------------------------------------------------------------------

    group('updateTeamFields', () {
      test('superAdmin can update team fields', () async {
        final sa = makeUser(id: 'sa', role: UserRole.superAdmin);
        when(mockFs.updateTeamFields('org1', 'l1', 'h1', 't1', {
          'memberIds': ['u1']
        })).thenAnswer((_) async {});
        await afs.updateTeamFields(sa, 'org1', 'l1', 'h1', 't1', {
          'memberIds': ['u1']
        });
        verify(mockFs.updateTeamFields('org1', 'l1', 'h1', 't1', {
          'memberIds': ['u1']
        })).called(1);
      });

      test('managerAdmin can update team in own hub', () async {
        final ma =
            makeUser(id: 'ma', role: UserRole.managerAdmin, hubIds: ['h1']);
        when(mockFs
                .updateTeamFields('org1', 'l1', 'h1', 't1', {'memberIds': []}))
            .thenAnswer((_) async {});
        await afs
            .updateTeamFields(ma, 'org1', 'l1', 'h1', 't1', {'memberIds': []});
        verify(mockFs.updateTeamFields(
            'org1', 'l1', 'h1', 't1', {'memberIds': []})).called(1);
      });

      test('managerAdmin cannot update team in other hub', () {
        final ma =
            makeUser(id: 'ma', role: UserRole.managerAdmin, hubIds: ['h2']);
        expect(
          () => afs.updateTeamFields(ma, 'org1', 'l1', 'h1', 't1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('staff cannot update team fields', () {
        final staff = makeUser(id: 's', role: UserRole.staff);
        expect(
          () => afs.updateTeamFields(staff, 'org1', 'l1', 'h1', 't1', {}),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // -------------------------------------------------------------------
    // sendMediaMessage
    // -------------------------------------------------------------------

    group('sendMediaMessage', () {
      test('active user can send media', () async {
        final user = makeUser(id: 'u1', role: UserRole.staff);
        when(mockFs.sendMediaMessage('org1', 'room1',
                senderId: 'u1',
                senderName: 'User u1',
                mediaUrl: 'https://example.com/img.jpg',
                mediaType: 'image/jpeg',
                caption: null))
            .thenAnswer((_) async {});
        await afs.sendMediaMessage(user, 'org1', 'room1',
            mediaUrl: 'https://example.com/img.jpg', mediaType: 'image/jpeg');
        verify(mockFs.sendMediaMessage('org1', 'room1',
                senderId: 'u1',
                senderName: 'User u1',
                mediaUrl: 'https://example.com/img.jpg',
                mediaType: 'image/jpeg',
                caption: null))
            .called(1);
      });

      test('inactive user cannot send media', () {
        final user = makeUser(id: 'u1', role: UserRole.staff, isActive: false);
        expect(
          () => afs.sendMediaMessage(user, 'org1', 'room1',
              mediaUrl: 'url', mediaType: 'image/png'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // -------------------------------------------------------------------
    // updateMessage
    // -------------------------------------------------------------------

    group('updateMessage', () {
      test('sender can update own message', () async {
        final user = makeUser(id: 'u1', role: UserRole.staff);
        when(mockFs.updateMessage('org1', 'room1', 'msg1', 'edited'))
            .thenAnswer((_) async {});
        await afs.updateMessage(user, 'org1', 'room1', 'msg1', 'edited',
            senderId: 'u1');
        verify(mockFs.updateMessage('org1', 'room1', 'msg1', 'edited'))
            .called(1);
      });

      test('other user cannot update someone else message', () {
        final user = makeUser(id: 'u2', role: UserRole.staff);
        expect(
          () => afs.updateMessage(user, 'org1', 'room1', 'msg1', 'edited',
              senderId: 'u1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('superAdmin cannot update someone else message', () {
        final admin = makeUser(id: 'admin', role: UserRole.superAdmin);
        expect(
          () => afs.updateMessage(admin, 'org1', 'room1', 'msg1', 'edited',
              senderId: 'u1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    // -------------------------------------------------------------------
    // deleteMessage
    // -------------------------------------------------------------------

    group('deleteMessage', () {
      test('sender can delete own message', () async {
        final user = makeUser(id: 'u1', role: UserRole.staff);
        when(mockFs.deleteMessage('org1', 'room1', 'msg1'))
            .thenAnswer((_) async {});
        await afs.deleteMessage(user, 'org1', 'room1', 'msg1', senderId: 'u1');
        verify(mockFs.deleteMessage('org1', 'room1', 'msg1')).called(1);
      });

      test('superAdmin can delete any message', () async {
        final admin = makeUser(id: 'admin', role: UserRole.superAdmin);
        when(mockFs.deleteMessage('org1', 'room1', 'msg1'))
            .thenAnswer((_) async {});
        await afs.deleteMessage(admin, 'org1', 'room1', 'msg1', senderId: 'u1');
        verify(mockFs.deleteMessage('org1', 'room1', 'msg1')).called(1);
      });

      test('staff cannot delete other user message', () {
        final user = makeUser(id: 'u2', role: UserRole.staff);
        expect(
          () =>
              afs.deleteMessage(user, 'org1', 'room1', 'msg1', senderId: 'u1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('inactive user cannot delete any message', () {
        final user = makeUser(id: 'u1', role: UserRole.staff, isActive: false);
        expect(
          () =>
              afs.deleteMessage(user, 'org1', 'room1', 'msg1', senderId: 'u1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });
  });
}
