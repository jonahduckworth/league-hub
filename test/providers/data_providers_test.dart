// Provider tests use direct provider overrides (not service mocks) because
// FirestoreService accesses Firebase.instance at construction time.
// TODO: Integration tests against a Firebase emulator would cover the service layer.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/document.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/message.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/providers/data_providers.dart';

void main() {
  final testDate = DateTime(2024, 1, 1);

  Organization makeOrg() => Organization(
        id: 'org1',
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: testDate,
        ownerId: 'owner1',
      );

  group('selectedLeagueProvider', () {
    test('defaults to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedLeagueProvider), isNull);
    });

    test('can be updated to a league id', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedLeagueProvider.notifier).state = 'league1';

      expect(container.read(selectedLeagueProvider), 'league1');
    });

    test('can be reset to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedLeagueProvider.notifier).state = 'league1';
      container.read(selectedLeagueProvider.notifier).state = null;

      expect(container.read(selectedLeagueProvider), isNull);
    });
  });

  group('selectedCategoryProvider', () {
    test('defaults to "All"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedCategoryProvider), 'All');
    });

    test('can be updated to a category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedCategoryProvider.notifier).state = 'Handbooks';

      expect(container.read(selectedCategoryProvider), 'Handbooks');
    });

    test('can be changed multiple times', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedCategoryProvider.notifier).state = 'Forms';
      container.read(selectedCategoryProvider.notifier).state = 'Rules';

      expect(container.read(selectedCategoryProvider), 'Rules');
    });
  });

  group('leaguesProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        leaguesProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(leaguesProvider.future);
      expect(result, isEmpty);
    });

    test('emits leagues when overridden with data', () async {
      final league = League(
        id: 'l1',
        orgId: 'org1',
        name: 'Premier',
        abbreviation: 'PL',
        createdAt: testDate,
      );

      final container = ProviderContainer(overrides: [
        leaguesProvider.overrideWith((ref) => Stream.value([league])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(leaguesProvider.future);
      expect(result.length, 1);
      expect(result.first.name, 'Premier');
    });
  });

  group('chatRoomsProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        chatRoomsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(chatRoomsProvider.future);
      expect(result, isEmpty);
    });

    test('emits chat rooms when overridden with data', () async {
      final room = ChatRoom(
        id: 'room1',
        orgId: 'org1',
        name: 'General',
        type: ChatRoomType.league,
        participants: [],
        createdAt: testDate,
        isArchived: false,
      );

      final container = ProviderContainer(overrides: [
        chatRoomsProvider.overrideWith((ref) => Stream.value([room])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(chatRoomsProvider.future);
      expect(result.length, 1);
      expect(result.first.name, 'General');
    });
  });

  group('announcementsProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        announcementsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(announcementsProvider.future);
      expect(result, isEmpty);
    });

    test('emits announcements when overridden with data', () async {
      final ann = Announcement(
        id: 'ann1',
        orgId: 'org1',
        scope: AnnouncementScope.orgWide,
        title: 'Test Announcement',
        body: 'Body text',
        authorId: 'u1',
        authorName: 'Admin',
        authorRole: 'Super Admin',
        attachments: [],
        isPinned: true,
        createdAt: testDate,
      );

      final container = ProviderContainer(overrides: [
        announcementsProvider.overrideWith((ref) => Stream.value([ann])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(announcementsProvider.future);
      expect(result.length, 1);
      expect(result.first.isPinned, true);
    });
  });

  group('documentsProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        documentsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(documentsProvider.future);
      expect(result, isEmpty);
    });

    test('emits documents when overridden with data', () async {
      final doc = Document(
        id: 'doc1',
        orgId: 'org1',
        name: 'Handbook',
        fileUrl: 'https://example.com/handbook.pdf',
        fileType: 'pdf',
        fileSize: 1024,
        category: 'Handbooks',
        uploadedBy: 'u1',
        uploadedByName: 'Admin',
        versions: [],
        createdAt: testDate,
        updatedAt: testDate,
      );

      final container = ProviderContainer(overrides: [
        documentsProvider.overrideWith((ref) => Stream.value([doc])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(documentsProvider.future);
      expect(result.length, 1);
      expect(result.first.category, 'Handbooks');
    });
  });

  group('orgUsersProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        orgUsersProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(orgUsersProvider.future);
      expect(result, isEmpty);
    });

    test('emits users when overridden with data', () async {
      final user = AppUser(
        id: 'u1',
        email: 'user@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        hubIds: [],
        teamIds: [],
        createdAt: testDate,
        isActive: true,
      );

      final container = ProviderContainer(overrides: [
        orgUsersProvider.overrideWith((ref) => Stream.value([user])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(orgUsersProvider.future);
      expect(result.length, 1);
    });
  });

  group('invitationsProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        invitationsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(invitationsProvider.future);
      expect(result, isEmpty);
    });
  });

  group('pendingInviteCountProvider', () {
    test('returns 0 when there are no invitations', () async {
      final container = ProviderContainer(overrides: [
        invitationsProvider.overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      await container.read(invitationsProvider.future);

      expect(container.read(pendingInviteCountProvider), 0);
    });

    test('counts only pending invitations', () async {
      final invitations = [
        Invitation(
          id: 'inv1',
          orgId: 'org1',
          email: 'a@a.com',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'u1',
          invitedByName: 'N',
          createdAt: testDate,
          status: InvitationStatus.pending,
          token: 'tok1',
        ),
        Invitation(
          id: 'inv2',
          orgId: 'org1',
          email: 'b@b.com',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'u1',
          invitedByName: 'N',
          createdAt: testDate,
          status: InvitationStatus.accepted,
          token: 'tok2',
        ),
        Invitation(
          id: 'inv3',
          orgId: 'org1',
          email: 'c@c.com',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'u1',
          invitedByName: 'N',
          createdAt: testDate,
          status: InvitationStatus.pending,
          token: 'tok3',
        ),
        Invitation(
          id: 'inv4',
          orgId: 'org1',
          email: 'd@d.com',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'u1',
          invitedByName: 'N',
          createdAt: testDate,
          status: InvitationStatus.expired,
          token: 'tok4',
        ),
      ];

      final container = ProviderContainer(overrides: [
        invitationsProvider.overrideWith((ref) => Stream.value(invitations)),
      ]);
      addTearDown(container.dispose);

      await container.read(invitationsProvider.future);

      expect(container.read(pendingInviteCountProvider), 2);
    });

    test('returns correct count when all are pending', () async {
      final invitations = List.generate(
        5,
        (i) => Invitation(
          id: 'inv$i',
          orgId: 'org1',
          email: '$i@a.com',
          role: 'staff',
          hubIds: [],
          teamIds: [],
          invitedBy: 'u1',
          invitedByName: 'N',
          createdAt: testDate,
          status: InvitationStatus.pending,
          token: 'tok$i',
        ),
      );

      final container = ProviderContainer(overrides: [
        invitationsProvider.overrideWith((ref) => Stream.value(invitations)),
      ]);
      addTearDown(container.dispose);

      await container.read(invitationsProvider.future);

      expect(container.read(pendingInviteCountProvider), 5);
    });
  });

  group('hubsProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        hubsProvider('league1').overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(hubsProvider('league1').future);
      expect(result, isEmpty);
    });

    test('emits hubs when overridden with data', () async {
      final hub = Hub(
        id: 'hub1',
        leagueId: 'league1',
        orgId: 'org1',
        name: 'North Hub',
        createdAt: testDate,
      );

      final container = ProviderContainer(overrides: [
        hubsProvider('league1').overrideWith((ref) => Stream.value([hub])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(hubsProvider('league1').future);
      expect(result.length, 1);
      expect(result.first.name, 'North Hub');
    });
  });

  group('teamsProvider', () {
    test('emits empty list when overridden to empty', () async {
      const params = (leagueId: 'l1', hubId: 'h1');
      final container = ProviderContainer(overrides: [
        teamsProvider(params).overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(teamsProvider(params).future);
      expect(result, isEmpty);
    });

    test('emits teams when overridden with data', () async {
      const params = (leagueId: 'l1', hubId: 'h1');
      final team = Team(
        id: 't1',
        hubId: 'h1',
        leagueId: 'l1',
        orgId: 'org1',
        name: 'Red Hawks',
        createdAt: testDate,
      );

      final container = ProviderContainer(overrides: [
        teamsProvider(params).overrideWith((ref) => Stream.value([team])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(teamsProvider(params).future);
      expect(result.length, 1);
      expect(result.first.name, 'Red Hawks');
    });
  });

  group('messagesProvider', () {
    test('emits empty list when overridden to empty', () async {
      final container = ProviderContainer(overrides: [
        messagesProvider('room1').overrideWith((ref) => Stream.value([])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(messagesProvider('room1').future);
      expect(result, isEmpty);
    });

    test('emits messages when overridden with data', () async {
      final msg = Message(
        id: 'msg1',
        chatRoomId: 'room1',
        senderId: 'u1',
        senderName: 'Alice',
        text: 'Hello',
        createdAt: testDate,
        readBy: ['u1'],
      );

      final container = ProviderContainer(overrides: [
        messagesProvider('room1').overrideWith((ref) => Stream.value([msg])),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(messagesProvider('room1').future);
      expect(result.length, 1);
      expect(result.first.text, 'Hello');
    });
  });

  group('chatRoomProvider (family)', () {
    test('emits null when overridden to null', () async {
      final container = ProviderContainer(overrides: [
        chatRoomProvider('room1').overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(chatRoomProvider('room1').future);
      expect(result, isNull);
    });

    test('emits room when overridden with data', () async {
      final room = ChatRoom(
        id: 'room1',
        orgId: 'org1',
        name: 'Test Room',
        type: ChatRoomType.direct,
        participants: ['u1', 'u2'],
        createdAt: testDate,
        isArchived: false,
      );

      final container = ProviderContainer(overrides: [
        chatRoomProvider('room1').overrideWith((ref) => Stream.value(room)),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(chatRoomProvider('room1').future);
      expect(result?.name, 'Test Room');
    });
  });

  group('documentProvider (family)', () {
    test('emits null when overridden to null', () async {
      final container = ProviderContainer(overrides: [
        documentProvider('doc1').overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(documentProvider('doc1').future);
      expect(result, isNull);
    });
  });

  group('organizationProvider', () {
    test('returns null when overridden to null', () async {
      final container = ProviderContainer(overrides: [
        organizationProvider.overrideWith((ref) async => null),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(organizationProvider.future);
      expect(result, isNull);
    });

    test('returns org when overridden with data', () async {
      final org = makeOrg();

      final container = ProviderContainer(overrides: [
        organizationProvider.overrideWith((ref) async => org),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(organizationProvider.future);
      expect(result?.name, 'Test Org');
    });
  });
}
