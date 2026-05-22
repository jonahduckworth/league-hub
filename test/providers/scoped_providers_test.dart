import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/policy.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/services/firestore_service.dart';

// Manual mock with proper null-safe return values via noSuchMethod overrides.
class MockFirestoreService extends Mock implements FirestoreService {
  @override
  Stream<List<ChatRoom>> getChatRooms(String orgId) => (super.noSuchMethod(
      Invocation.method(#getChatRooms, [orgId]),
      returnValue: Stream<List<ChatRoom>>.value([])) as Stream<List<ChatRoom>>);

  @override
  Stream<List<Policy>> policiesStream(String orgId,
          {String? leagueId, String? category}) =>
      (super.noSuchMethod(
          Invocation.method(#policiesStream, [orgId],
              {#leagueId: leagueId, #category: category}),
          returnValue: Stream<List<Policy>>.value([])) as Stream<List<Policy>>);

  @override
  Stream<List<Announcement>> getAnnouncements(String orgId) =>
      (super.noSuchMethod(Invocation.method(#getAnnouncements, [orgId]),
              returnValue: Stream<List<Announcement>>.value([]))
          as Stream<List<Announcement>>);
}

void main() {
  group('Scoped Providers Tests', () {
    late ProviderContainer container;
    late MockFirestoreService mockFs;

    setUp(() {
      mockFs = MockFirestoreService();
    });

    tearDown(() {
      resetMockitoState();
    });

    group('chatRoomsProvider filtering', () {
      test('staff user: only sees DMs they are in', () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          leagueIds: ['l1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final dmRoom = ChatRoom(
          id: 'dm1',
          orgId: 'org1',
          name: 'Staff & Manager',
          type: ChatRoomType.direct,
          participants: ['staff1', 'manager1'],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        final leagueRoom = ChatRoom(
          id: 'league1',
          orgId: 'org1',
          name: 'League General',
          type: ChatRoomType.league,
          leagueId: 'l1',
          participants: [],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        when(mockFs.getChatRooms('org1'))
            .thenAnswer((_) => Stream.value([dmRoom, leagueRoom]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(chatRoomsProvider.future);

        // Staff should see: DM (is participant) + league room (visible to all)
        expect(result, hasLength(2));
        expect(result.map((r) => r.id), containsAll(['dm1', 'league1']));
      });

      test('staff user: does not see DMs they are not in', () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final otherDmRoom = ChatRoom(
          id: 'dm2',
          orgId: 'org1',
          name: 'Manager & Admin',
          type: ChatRoomType.direct,
          participants: ['manager1', 'admin1'],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        when(mockFs.getChatRooms('org1'))
            .thenAnswer((_) => Stream.value([otherDmRoom]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(chatRoomsProvider.future);

        // Staff should not see DM they are not in
        expect(result, isEmpty);
      });

      test('superAdmin: sees all rooms', () async {
        final superAdmin = AppUser(
          id: 'admin1',
          email: 'admin@example.com',
          displayName: 'Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final dmRoom = ChatRoom(
          id: 'dm1',
          orgId: 'org1',
          name: 'Staff & Manager',
          type: ChatRoomType.direct,
          participants: ['staff1', 'manager1'],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        final leagueRoom = ChatRoom(
          id: 'league1',
          orgId: 'org1',
          name: 'League General',
          type: ChatRoomType.league,
          leagueId: 'l1',
          participants: [],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        when(mockFs.getChatRooms('org1'))
            .thenAnswer((_) => Stream.value([dmRoom, leagueRoom]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => superAdmin),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(chatRoomsProvider.future);

        // SuperAdmin sees all
        expect(result, hasLength(2));
      });
    });

    group('policiesProvider filtering', () {
      test('staff user: only sees policies in their hubs', () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final policyInHub = Policy(
          id: 'policy1',
          orgId: 'org1',
          hubId: 'h1',
          name: 'Rules in H1',
          fileUrl: 'https://example.com/rules.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          category: 'Rules',
          uploadedBy: 'admin1',
          uploadedByName: 'Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final policyInOtherHub = Policy(
          id: 'policy2',
          orgId: 'org1',
          hubId: 'h2',
          name: 'Rules in H2',
          fileUrl: 'https://example.com/rules2.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          category: 'Rules',
          uploadedBy: 'admin1',
          uploadedByName: 'Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFs.policiesStream('org1'))
            .thenAnswer((_) => Stream.value([policyInHub, policyInOtherHub]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(policiesProvider.future);

        // Staff should only see the policy in h1.
        expect(result, hasLength(1));
        expect(result.first.id, 'policy1');
      });

      test('superAdmin: sees all policies', () async {
        final superAdmin = AppUser(
          id: 'admin1',
          email: 'admin@example.com',
          displayName: 'Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final doc1 = Policy(
          id: 'doc1',
          orgId: 'org1',
          hubId: 'h1',
          name: 'Rules 1',
          fileUrl: 'https://example.com/rules1.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          category: 'Rules',
          uploadedBy: 'admin1',
          uploadedByName: 'Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final doc2 = Policy(
          id: 'doc2',
          orgId: 'org1',
          hubId: 'h2',
          name: 'Rules 2',
          fileUrl: 'https://example.com/rules2.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          category: 'Rules',
          uploadedBy: 'admin1',
          uploadedByName: 'Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFs.policiesStream('org1'))
            .thenAnswer((_) => Stream.value([doc1, doc2]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => superAdmin),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(policiesProvider.future);

        // SuperAdmin sees all
        expect(result, hasLength(2));
      });
    });

    group('announcementsProvider filtering', () {
      test(
          'staff user: sees org-wide and hub-scoped announcements in their hubs',
          () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final orgWideAnn = Announcement(
          id: 'ann1',
          orgId: 'org1',
          scope: AnnouncementScope.orgWide,
          title: 'Org Wide',
          body: 'This is org-wide',
          authorId: 'admin1',
          authorName: 'Admin',
          authorRole: 'superAdmin',
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        final hubAnnInTheirHub = Announcement(
          id: 'ann2',
          orgId: 'org1',
          scope: AnnouncementScope.hub,
          hubId: 'h1',
          title: 'Hub Announcement',
          body: 'For H1',
          authorId: 'admin1',
          authorName: 'Admin',
          authorRole: 'superAdmin',
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        final hubAnnInOtherHub = Announcement(
          id: 'ann3',
          orgId: 'org1',
          scope: AnnouncementScope.hub,
          hubId: 'h2',
          title: 'Other Hub',
          body: 'For H2',
          authorId: 'admin1',
          authorName: 'Admin',
          authorRole: 'superAdmin',
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        when(mockFs.getAnnouncements('org1')).thenAnswer((_) =>
            Stream.value([orgWideAnn, hubAnnInTheirHub, hubAnnInOtherHub]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(announcementsProvider.future);

        // Staff should see org-wide + hub announcement in h1
        expect(result, hasLength(2));
        expect(result.map((a) => a.id), containsAll(['ann1', 'ann2']));
      });

      test('superAdmin: sees all announcements', () async {
        final superAdmin = AppUser(
          id: 'admin1',
          email: 'admin@example.com',
          displayName: 'Admin',
          role: UserRole.superAdmin,
          orgId: 'org1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final testOrg = Organization(
          id: 'org1',
          name: 'Test Org',
          primaryColor: '#1A3A5C',
          secondaryColor: '#2E75B6',
          accentColor: '#4DA3FF',
          createdAt: DateTime.now(),
          ownerId: 'owner1',
        );

        final ann1 = Announcement(
          id: 'ann1',
          orgId: 'org1',
          scope: AnnouncementScope.orgWide,
          title: 'Org Wide',
          body: 'This is org-wide',
          authorId: 'admin1',
          authorName: 'Admin',
          authorRole: 'superAdmin',
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        final ann2 = Announcement(
          id: 'ann2',
          orgId: 'org1',
          scope: AnnouncementScope.hub,
          hubId: 'h1',
          title: 'Hub Ann',
          body: 'For hub',
          authorId: 'admin1',
          authorName: 'Admin',
          authorRole: 'superAdmin',
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        when(mockFs.getAnnouncements('org1'))
            .thenAnswer((_) => Stream.value([ann1, ann2]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => superAdmin),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(announcementsProvider.future);

        // SuperAdmin sees all
        expect(result, hasLength(2));
      });
    });

    // -----------------------------------------------------------------
    // League-scoped filtering with leagueIds
    // -----------------------------------------------------------------

    group('league-scoped filtering', () {
      final testOrg = Organization(
        id: 'org1',
        name: 'Test Org',
        primaryColor: '#1A3A5C',
        secondaryColor: '#2E75B6',
        accentColor: '#4DA3FF',
        createdAt: DateTime.now(),
        ownerId: 'owner1',
      );

      test('staff with leagueIds sees league-scoped chat room', () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          leagueIds: ['l1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final leagueRoom = ChatRoom(
          id: 'lr1',
          orgId: 'org1',
          name: 'League 1 Chat',
          type: ChatRoomType.league,
          leagueId: 'l1',
          participants: [],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        final otherLeagueRoom = ChatRoom(
          id: 'lr2',
          orgId: 'org1',
          name: 'League 2 Chat',
          type: ChatRoomType.league,
          leagueId: 'l2',
          participants: [],
          createdAt: DateTime.now(),
          isArchived: false,
        );

        when(mockFs.getChatRooms('org1'))
            .thenAnswer((_) => Stream.value([leagueRoom, otherLeagueRoom]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(chatRoomsProvider.future);
        expect(result, hasLength(1));
        expect(result.first.id, 'lr1');
      });

      test('staff without leagueIds sees no league-scoped announcements',
          () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          leagueIds: [],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final leagueAnn = Announcement(
          id: 'ann1',
          orgId: 'org1',
          title: 'League News',
          body: 'Content',
          scope: AnnouncementScope.league,
          leagueId: 'l1',
          authorId: 'admin',
          authorName: 'Admin',
          authorRole: 'superAdmin',
          isPinned: false,
          createdAt: DateTime.now(),
          attachments: [],
        );

        when(mockFs.getAnnouncements('org1'))
            .thenAnswer((_) => Stream.value([leagueAnn]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(announcementsProvider.future);
        expect(result, isEmpty);
      });

      test('staff with matching leagueIds sees league-scoped policies',
          () async {
        final staffUser = AppUser(
          id: 'staff1',
          email: 'staff@example.com',
          displayName: 'Staff',
          role: UserRole.staff,
          orgId: 'org1',
          hubIds: ['h1'],
          leagueIds: ['l1'],
          teamIds: [],
          createdAt: DateTime.now(),
          isActive: true,
        );

        final leagueDoc = Policy(
          id: 'doc1',
          orgId: 'org1',
          leagueId: 'l1',
          name: 'League Rules',
          fileUrl: 'https://example.com/rules.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          category: 'Rules',
          uploadedBy: 'admin',
          uploadedByName: 'Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final otherLeagueDoc = Policy(
          id: 'doc2',
          orgId: 'org1',
          leagueId: 'l2',
          name: 'Other League Rules',
          fileUrl: 'https://example.com/rules2.pdf',
          fileType: 'pdf',
          fileSize: 1024,
          category: 'Rules',
          uploadedBy: 'admin',
          uploadedByName: 'Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        when(mockFs.policiesStream('org1'))
            .thenAnswer((_) => Stream.value([leagueDoc, otherLeagueDoc]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWith((ref) => staffUser),
            organizationProvider.overrideWith((ref) => testOrg),
          ],
        );

        final result = await container.read(policiesProvider.future);
        expect(result, hasLength(1));
        expect(result.first.id, 'doc1');
      });
    });
  });
}
