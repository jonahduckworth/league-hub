import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/document.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/permission_service.dart';

// Manual mocks
class MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  group('Scoped Providers Tests', () {
    late ProviderContainer container;
    late MockFirestoreService mockFs;

    setUp(() {
      mockFs = MockFirestoreService();
    });

    group('chatRoomsProvider filtering', () {
      test('staff user: only sees DMs they are in', () {
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
            currentUserProvider.overrideWithValue(
              AsyncValue.data(staffUser),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(chatRoomsProvider).valueOrNull ?? [];

        // Staff should see: DM (is participant) + league room (visible to all)
        expect(result, hasLength(2));
        expect(result.map((r) => r.id), containsAll(['dm1', 'league1']));
      });

      test('staff user: does not see DMs they are not in', () {
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
            currentUserProvider.overrideWithValue(
              AsyncValue.data(staffUser),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(chatRoomsProvider).valueOrNull ?? [];

        // Staff should not see DM they are not in
        expect(result, isEmpty);
      });

      test('superAdmin: sees all rooms', () {
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
            currentUserProvider.overrideWithValue(
              AsyncValue.data(superAdmin),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(chatRoomsProvider).valueOrNull ?? [];

        // SuperAdmin sees all
        expect(result, hasLength(2));
      });
    });

    group('documentsProvider filtering', () {
      test('staff user: only sees docs in their hubs', () {
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

        final docInHub = Document(
          id: 'doc1',
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

        final docInOtherHub = Document(
          id: 'doc2',
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

        when(mockFs.documentsStream('org1', leagueId: null, category: null))
            .thenAnswer((_) => Stream.value([docInHub, docInOtherHub]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWithValue(
              AsyncValue.data(staffUser),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(documentsProvider).valueOrNull ?? [];

        // Staff should only see doc in h1
        expect(result, hasLength(1));
        expect(result.first.id, 'doc1');
      });

      test('superAdmin: sees all docs', () {
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

        final doc1 = Document(
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

        final doc2 = Document(
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

        when(mockFs.documentsStream('org1', leagueId: null, category: null))
            .thenAnswer((_) => Stream.value([doc1, doc2]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWithValue(
              AsyncValue.data(superAdmin),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(documentsProvider).valueOrNull ?? [];

        // SuperAdmin sees all
        expect(result, hasLength(2));
      });
    });

    group('announcementsProvider filtering', () {
      test('staff user: sees org-wide and hub-scoped announcements in their hubs', () {
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

        when(mockFs.getAnnouncements('org1'))
            .thenAnswer((_) => Stream.value([orgWideAnn, hubAnnInTheirHub, hubAnnInOtherHub]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWithValue(
              AsyncValue.data(staffUser),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(announcementsProvider).valueOrNull ?? [];

        // Staff should see org-wide + hub announcement in h1
        expect(result, hasLength(2));
        expect(result.map((a) => a.id), containsAll(['ann1', 'ann2']));
      });

      test('superAdmin: sees all announcements', () {
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

        when(mockFs.getAnnouncements('org1')).thenAnswer((_) => Stream.value([ann1, ann2]));

        container = ProviderContainer(
          overrides: [
            firestoreServiceProvider.overrideWithValue(mockFs),
            currentUserProvider.overrideWithValue(
              AsyncValue.data(superAdmin),
            ),
            organizationProvider.overrideWithValue(
              AsyncValue.data(testOrg),
            ),
          ],
        );

        final result = container.read(announcementsProvider).valueOrNull ?? [];

        // SuperAdmin sees all
        expect(result, hasLength(2));
      });
    });
  });
}
