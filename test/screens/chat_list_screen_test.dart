import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/chat_list_screen.dart';
import 'package:league_hub/screens/new_chat_screen.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/avatar_widget.dart';
import 'package:league_hub/widgets/chat_room_avatar.dart';
import 'package:league_hub/widgets/empty_state.dart';
import 'package:league_hub/widgets/league_filter.dart';
import 'package:mockito/mockito.dart';

class MockAuthorizedFirestoreService extends Mock
    implements AuthorizedFirestoreService {
  @override
  Future<String> createChatRoom(
    AppUser actor,
    String orgId,
    String name,
    ChatRoomType type, {
    String? leagueId,
    String? hubId,
    String? teamId,
    List<String> participants = const [],
    String? roomIconName,
    String? roomImageUrl,
    ChatRoomPurpose? roomPurpose,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #createChatRoom,
          [actor, orgId, name, type],
          {
            #leagueId: leagueId,
            #hubId: hubId,
            #teamId: teamId,
            #participants: participants,
            #roomIconName: roomIconName,
            #roomImageUrl: roomImageUrl,
            #roomPurpose: roomPurpose,
          },
        ),
        returnValue: Future<String>.value('created-room'),
      ) as Future<String>);
}

class MockFirestoreService extends Mock implements FirestoreService {
  @override
  Future<ChatRoom> getOrCreateDMRoom(
    String orgId,
    String currentUserId,
    String otherUserId,
    String currentUserName,
    String otherUserName,
  ) =>
      (super.noSuchMethod(
        Invocation.method(
          #getOrCreateDMRoom,
          [
            orgId,
            currentUserId,
            otherUserId,
            currentUserName,
            otherUserName,
          ],
        ),
        returnValue: Future<ChatRoom>.value(
          ChatRoom(
            id: 'dm-room-created',
            orgId: orgId,
            name: 'DM',
            type: ChatRoomType.direct,
            participants: [currentUserId, otherUserId],
            createdAt: DateTime(2026),
            isArchived: false,
          ),
        ),
      ) as Future<ChatRoom>);
}

void main() {
  group('chat list helpers', () {
    final baseTime = DateTime(2026, 1, 1);
    final leagueRoom = ChatRoom(
      id: 'league-room',
      orgId: 'org-1',
      name: 'Spring League Hub',
      type: ChatRoomType.league,
      leagueId: 'league-1',
      participants: ['user-1'],
      createdAt: baseTime,
      isArchived: false,
    );
    final eventRoom = ChatRoom(
      id: 'event-room',
      orgId: 'org-1',
      name: 'Tournament Bracket',
      type: ChatRoomType.event,
      participants: ['user-1'],
      createdAt: baseTime,
      isArchived: false,
    );
    final hubRoom = ChatRoom(
      id: 'hub-room',
      orgId: 'org-1',
      name: 'Calgary - General',
      type: ChatRoomType.league,
      leagueId: 'league-1',
      hubId: 'hub-1',
      participants: const [],
      createdAt: baseTime,
      isArchived: false,
    );
    final teamRoom = ChatRoom(
      id: 'team-room',
      orgId: 'org-1',
      name: 'Calgary U18 - General',
      type: ChatRoomType.league,
      leagueId: 'league-1',
      hubId: 'hub-1',
      teamId: 'team-1',
      participants: const [],
      createdAt: baseTime,
      isArchived: false,
    );
    final hubGroupRoom = ChatRoom(
      id: 'hub-group-room',
      orgId: 'org-1',
      name: 'Hub GMs',
      type: ChatRoomType.event,
      roomPurpose: ChatRoomPurpose.group,
      leagueId: 'league-1',
      hubId: 'hub-1',
      participants: const [],
      createdAt: baseTime,
      isArchived: false,
    );
    final dmRoom = ChatRoom(
      id: 'dm-room',
      orgId: 'org-1',
      name: 'Direct Message',
      type: ChatRoomType.direct,
      participants: ['user-1', 'user-2'],
      createdAt: baseTime,
      isArchived: false,
    );

    test('filters chat rooms by search text and selected league', () {
      final filtered = filterChatRooms(
        rooms: [leagueRoom, eventRoom, dmRoom],
        searchText: 'spring',
        selectedLeagueId: 'league-1',
      );

      expect(filtered, [leagueRoom]);
    });

    test('selected league keeps direct messages visible', () {
      final filtered = filterChatRooms(
        rooms: [leagueRoom, eventRoom, dmRoom],
        searchText: '',
        selectedLeagueId: 'league-1',
      );

      expect(filtered, containsAll([leagueRoom, dmRoom]));
      expect(filtered, isNot(contains(eventRoom)));
    });

    test('builds non-empty chat room sections in display order', () {
      final sections = buildChatRoomSections(
        [dmRoom, eventRoom, teamRoom, hubGroupRoom, leagueRoom],
      );

      expect(
        sections.map((section) => section.title).toList(),
        [
          'League Rooms',
          'Hub Rooms',
          'Team Rooms',
          'Events',
          'Direct Messages',
        ],
      );
      expect(sections[0].rooms, [leagueRoom]);
      expect(sections[1].rooms, [hubGroupRoom]);
      expect(sections[2].rooms, [teamRoom]);
      expect(sections[3].rooms, [eventRoom]);
      expect(sections[4].rooms, [dmRoom]);
    });

    test('orders chat rooms for flat display by latest activity', () {
      final olderLeagueRoom = ChatRoom(
        id: leagueRoom.id,
        orgId: leagueRoom.orgId,
        name: leagueRoom.name,
        type: leagueRoom.type,
        leagueId: leagueRoom.leagueId,
        participants: leagueRoom.participants,
        createdAt: baseTime,
        isArchived: false,
        lastMessageAt: baseTime.add(const Duration(minutes: 1)),
      );
      final newestEventRoom = ChatRoom(
        id: eventRoom.id,
        orgId: eventRoom.orgId,
        name: eventRoom.name,
        type: eventRoom.type,
        participants: eventRoom.participants,
        createdAt: baseTime,
        isArchived: false,
        lastMessageAt: baseTime.add(const Duration(minutes: 3)),
      );
      final middleDmRoom = ChatRoom(
        id: dmRoom.id,
        orgId: dmRoom.orgId,
        name: dmRoom.name,
        type: dmRoom.type,
        participants: dmRoom.participants,
        createdAt: baseTime,
        isArchived: false,
        lastMessageAt: baseTime.add(const Duration(minutes: 2)),
      );
      final ordered = orderChatRoomsForDisplay(
          [middleDmRoom, newestEventRoom, olderLeagueRoom]);

      expect(ordered, [newestEventRoom, middleDmRoom, olderLeagueRoom]);
    });

    test('filters chat rooms by selected room category', () {
      final filtered = filterChatRooms(
        rooms: [leagueRoom, eventRoom, dmRoom],
        searchText: '',
        selectedLeagueId: null,
        roomFilter: ChatRoomListFilter.events,
      );

      expect(filtered, [eventRoom]);
    });

    test('categorizes shared rooms by purpose and audience', () {
      expect(chatRoomCategory(leagueRoom), ChatRoomListFilter.leagueRooms);
      expect(chatRoomCategory(hubRoom), ChatRoomListFilter.hubRooms);
      expect(chatRoomCategory(teamRoom), ChatRoomListFilter.teamRooms);
      expect(chatRoomCategory(hubGroupRoom), ChatRoomListFilter.hubRooms);
      expect(chatRoomCategory(eventRoom), ChatRoomListFilter.events);
      expect(chatRoomCategory(dmRoom), ChatRoomListFilter.directMessages);
    });

    test('builds preview text from sender and message', () {
      final room = ChatRoom(
        id: leagueRoom.id,
        orgId: leagueRoom.orgId,
        name: leagueRoom.name,
        type: leagueRoom.type,
        leagueId: leagueRoom.leagueId,
        participants: leagueRoom.participants,
        createdAt: leagueRoom.createdAt,
        isArchived: leagueRoom.isArchived,
        lastMessage: 'Ready to go',
        lastMessageBy: 'Coach',
      );

      expect(chatRoomPreviewText(room), 'Coach: Ready to go');
      expect(
        chatRoomPreviewText(room, lastMessageIsBlocked: true),
        'Blocked message hidden',
      );
    });

    test('returns null preview when there is no last message', () {
      expect(chatRoomPreviewText(leagueRoom), isNull);
    });

    test('detects blocked last-message senders without exposing preview text',
        () {
      final currentUser = AppUser(
        id: 'current',
        email: 'current@example.com',
        displayName: 'Current User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: const [],
        teamIds: const [],
        blockedUserIds: const ['blocked'],
        createdAt: DateTime(2026),
        isActive: true,
      );
      final blockedUser = AppUser(
        id: 'blocked',
        email: 'blocked@example.com',
        displayName: 'Blocked User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: const [],
        teamIds: const [],
        createdAt: DateTime(2026),
        isActive: true,
      );
      final room = ChatRoom(
        id: 'room',
        orgId: 'org-1',
        name: 'Team Chat',
        type: ChatRoomType.league,
        participants: const [],
        createdAt: DateTime(2026),
        isArchived: false,
        lastMessage: 'This must stay private',
        lastMessageBy: 'Blocked User',
        lastMessageSenderId: 'blocked',
      );

      final blocked = chatRoomLastMessageIsBlocked(
        room,
        currentUser,
        [blockedUser],
      );
      expect(blocked, isTrue);
      expect(
        chatRoomPreviewText(
          room,
          currentUser: currentUser,
          lastMessageIsBlocked: blocked,
        ),
        'Blocked message hidden',
      );
    });

    test('formats unread badge count and timestamp color', () {
      expect(formatUnreadBadgeCount(4), '4');
      expect(formatUnreadBadgeCount(104), '99+');
      expect(chatRoomTimestampColor(0), AppColors.textMuted);
      expect(chatRoomTimestampColor(2), AppColors.primary);
    });

    test('builds preview text from message without sender', () {
      final room = ChatRoom(
        id: leagueRoom.id,
        orgId: leagueRoom.orgId,
        name: leagueRoom.name,
        type: leagueRoom.type,
        leagueId: leagueRoom.leagueId,
        participants: leagueRoom.participants,
        createdAt: leagueRoom.createdAt,
        isArchived: leagueRoom.isArchived,
        lastMessage: 'Ready to go',
      );

      expect(chatRoomPreviewText(room), 'Ready to go');
    });

    test('direct message preview omits current users name', () {
      final currentUser = AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      final room = ChatRoom(
        id: dmRoom.id,
        orgId: dmRoom.orgId,
        name: dmRoom.name,
        type: dmRoom.type,
        participants: dmRoom.participants,
        createdAt: dmRoom.createdAt,
        isArchived: dmRoom.isArchived,
        lastMessage: 'See you at 5',
        lastMessageBy: currentUser.displayName,
      );

      expect(
          chatRoomPreviewText(room, currentUser: currentUser), 'See you at 5');
    });

    test('direct message display name uses the other participant', () {
      final currentUser = AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      final otherUser = AppUser(
        id: 'user-2',
        email: 'other@example.com',
        displayName: 'Other User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );

      expect(
        chatRoomDisplayName(dmRoom, currentUser, [currentUser, otherUser]),
        'Other User',
      );
    });

    test('chat room members come from league membership when league scoped',
        () {
      final leagueMember = AppUser(
        id: 'user-2',
        email: 'member@example.com',
        displayName: 'League Member',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        leagueIds: ['league-1'],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      final otherUser = AppUser(
        id: 'user-3',
        email: 'other@example.com',
        displayName: 'Other User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        leagueIds: ['league-2'],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );

      final members = chatRoomMembers(leagueRoom, [leagueMember, otherUser]);

      expect(members, [leagueMember]);
    });

    test('event room participant ids include active users from selected league',
        () {
      final creator = AppUser(
        id: 'creator',
        email: 'creator@example.com',
        displayName: 'Creator',
        role: UserRole.managerAdmin,
        orgId: 'org-1',
        hubIds: [],
        leagueIds: ['league-1'],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      final leagueMember = AppUser(
        id: 'sam',
        email: 'sam@example.com',
        displayName: 'Sam Orr',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        leagueIds: ['league-1'],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      final otherLeagueMember = AppUser(
        id: 'other',
        email: 'other@example.com',
        displayName: 'Other League',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        leagueIds: ['league-2'],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );

      expect(
        sharedRoomParticipantIds(
          creator: creator,
          users: [leagueMember, otherLeagueMember],
          leagueId: 'league-1',
        ),
        ['creator', 'sam'],
      );
    });

    test('opens direct message room when current user is available', () async {
      final currentUser = AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      final otherUser = AppUser(
        id: 'user-2',
        email: 'other@example.com',
        displayName: 'Other User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );

      final roomId = await openDirectMessageRoom(
        currentUser: currentUser,
        otherUser: otherUser,
        orgId: 'org-1',
        getOrCreateDMRoom: (
          orgId,
          currentUserId,
          otherUserId,
          currentUserName,
          otherUserName,
        ) async {
          expect(orgId, 'org-1');
          expect(currentUserId, 'user-1');
          expect(otherUserId, 'user-2');
          expect(currentUserName, 'Test User');
          expect(otherUserName, 'Other User');
          return ChatRoom(
            id: 'dm-created',
            orgId: orgId,
            name: 'DM',
            type: ChatRoomType.direct,
            participants: [currentUserId, otherUserId],
            createdAt: baseTime,
            isArchived: false,
          );
        },
      );

      expect(roomId, 'dm-created');
    });

    test('does not open direct message room without current user', () async {
      final otherUser = AppUser(
        id: 'user-2',
        email: 'other@example.com',
        displayName: 'Other User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );

      final roomId = await openDirectMessageRoom(
        currentUser: null,
        otherUser: otherUser,
        orgId: 'org-1',
        getOrCreateDMRoom: (
          _,
          __,
          ___,
          ____,
          _____,
        ) async =>
            throw StateError('should not be called'),
      );

      expect(roomId, isNull);
    });
  });

  group('ChatListScreen', () {
    final testUser = AppUser(
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Test User',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: [],
      leagueIds: ['league-1'],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );
    final managerUser = AppUser(
      id: 'manager-1',
      email: 'manager@example.com',
      displayName: 'Manager User',
      role: UserRole.managerAdmin,
      orgId: 'org-1',
      hubIds: [],
      leagueIds: ['league-1'],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime.now(),
      ownerId: 'user-1',
    );

    final testLeagues = [
      League(
        id: 'league-1',
        orgId: 'org-1',
        name: 'Spring League',
        abbreviation: 'SL',
        createdAt: DateTime.now(),
      ),
      League(
        id: 'league-2',
        orgId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime.now(),
      ),
    ];

    final testChatRooms = [
      ChatRoom(
        id: 'chat-1',
        orgId: 'org-1',
        name: 'Spring League Hub',
        type: ChatRoomType.league,
        leagueId: 'league-1',
        participants: ['user-1', 'user-2'],
        createdAt: DateTime.now(),
        isArchived: false,
        lastMessage: 'Great game this weekend!',
        lastMessageBy: 'user-2',
        lastMessageAt: DateTime.now().subtract(Duration(hours: 1)),
      ),
      ChatRoom(
        id: 'chat-2',
        orgId: 'org-1',
        name: 'Tournament Bracket',
        type: ChatRoomType.event,
        participants: ['user-1', 'user-2', 'user-3'],
        createdAt: DateTime.now(),
        isArchived: false,
        lastMessage: 'Bracket updates available',
        lastMessageBy: 'user-1',
        lastMessageAt: DateTime.now().subtract(Duration(minutes: 30)),
      ),
      ChatRoom(
        id: 'chat-hub',
        orgId: 'org-1',
        name: 'Calgary - General',
        type: ChatRoomType.league,
        leagueId: 'league-1',
        hubId: 'hub-1',
        participants: const [],
        createdAt: DateTime(2026, 1, 1),
        isArchived: false,
      ),
      ChatRoom(
        id: 'chat-team',
        orgId: 'org-1',
        name: 'Calgary U18 - General',
        type: ChatRoomType.league,
        leagueId: 'league-1',
        hubId: 'hub-1',
        teamId: 'team-1',
        participants: const [],
        createdAt: DateTime(2026, 1, 1),
        isArchived: false,
      ),
      ChatRoom(
        id: 'chat-hub-group',
        orgId: 'org-1',
        name: 'Hub GMs',
        type: ChatRoomType.event,
        roomPurpose: ChatRoomPurpose.group,
        leagueId: 'league-1',
        hubId: 'hub-1',
        participants: const [],
        createdAt: DateTime(2026, 1, 1),
        isArchived: false,
      ),
      ChatRoom(
        id: 'chat-3',
        orgId: 'org-1',
        name: 'Direct Message',
        type: ChatRoomType.direct,
        participants: ['user-1', 'user-2'],
        createdAt: DateTime.now(),
        isArchived: false,
        lastMessage: 'See you tomorrow',
        lastMessageBy: 'user-2',
        lastMessageAt: DateTime.now().subtract(Duration(minutes: 15)),
      ),
    ];

    final pinnedAnnouncement = Announcement(
      id: 'announcement-1',
      orgId: 'org-1',
      scope: AnnouncementScope.league,
      leagueId: 'league-1',
      title: 'Weekend schedule update',
      body: 'Please review the revised arrival times before Saturday.',
      authorId: 'manager-1',
      authorName: 'Manager User',
      authorRole: 'Manager',
      attachments: const [],
      isPinned: true,
      createdAt: DateTime(2026, 8, 10),
    );

    final regularAnnouncement = Announcement(
      id: 'announcement-2',
      orgId: 'org-1',
      scope: AnnouncementScope.league,
      leagueId: 'league-1',
      title: 'Regular update',
      body: 'This post belongs in the full announcement feed.',
      authorId: 'manager-1',
      authorName: 'Manager User',
      authorRole: 'Manager',
      attachments: const [],
      isPinned: false,
      createdAt: DateTime(2026, 8, 9),
    );

    Widget createTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      List<ChatRoom>? chatRooms,
      List<AppUser>? orgUsers,
      List<Announcement> announcements = const [],
      bool includePinnedAnnouncements = false,
      TextScaler? textScaler,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? testUser,
          ),
          organizationProvider.overrideWith(
            (ref) => org ?? testOrg,
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          chatRoomsProvider.overrideWith(
            (ref) => Stream.value(chatRooms ?? testChatRooms),
          ),
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements),
          ),
          orgUsersProvider.overrideWith(
            (ref) => Stream.value(
              orgUsers ?? [testUser],
            ),
          ),
          unreadCountProvider.overrideWith(
            (ref, roomId) => Stream.value(0),
          ),
        ],
        child: MaterialApp(
          builder: textScaler == null
              ? null
              : (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: textScaler,
                    ),
                    child: child!,
                  ),
          home: ChatListScreen(
            includePinnedAnnouncements: includePinnedAnnouncements,
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    Widget createRoutedTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      List<ChatRoom>? chatRooms,
      List<AppUser>? orgUsers,
      AuthorizedFirestoreService? authorizedFirestoreService,
      FirestoreService? firestoreService,
      int unreadCount = 0,
      List<Announcement> announcements = const [],
      bool includePinnedAnnouncements = false,
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChatListScreen(
              includePinnedAnnouncements: includePinnedAnnouncements,
            ),
          ),
          GoRoute(
            path: '/chat/new',
            builder: (context, state) => const NewChatScreen(),
          ),
          GoRoute(
            path: '/chat/:roomId',
            builder: (context, state) => Scaffold(
              body: Text('Chat Route ${state.pathParameters['roomId']}'),
            ),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) =>
                const Scaffold(body: Text('All Announcements Route')),
          ),
          GoRoute(
            path: '/announcements/:announcementId',
            builder: (context, state) => Scaffold(
              body: Text(
                'Announcement ${state.pathParameters['announcementId']}',
              ),
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user ?? testUser),
          organizationProvider.overrideWith((ref) => org ?? testOrg),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          chatRoomsProvider.overrideWith(
            (ref) => Stream.value(chatRooms ?? testChatRooms),
          ),
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements),
          ),
          orgUsersProvider.overrideWith(
            (ref) => Stream.value(orgUsers ?? [testUser]),
          ),
          if (authorizedFirestoreService != null)
            authorizedFirestoreServiceProvider
                .overrideWithValue(authorizedFirestoreService),
          if (firestoreService != null)
            firestoreServiceProvider.overrideWithValue(firestoreService),
          unreadCountProvider.overrideWith(
            (ref, roomId) => Stream.value(unreadCount),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
        ),
      );
    }

    Future<void> scrollRoomsUntilVisible(
      WidgetTester tester,
      Finder target,
    ) async {
      await tester.scrollUntilVisible(
        target,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }

    Future<void> selectRoomFilter(
      WidgetTester tester,
      ChatRoomListFilter filter,
    ) async {
      final finder = find.byKey(ValueKey('chat-type-filter-${filter.name}'));
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('chat-type-selector')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    group('Screen Rendering', () {
      testWidgets('renders without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byType(ChatListScreen), findsOneWidget);
      });

      testWidgets('lazily builds large room lists with shader-free cards',
          (WidgetTester tester) async {
        final manyRooms = List.generate(
          40,
          (index) => ChatRoom(
            id: 'room-$index',
            orgId: 'org-1',
            name: 'Room $index',
            type: ChatRoomType.league,
            participants: const ['user-1'],
            createdAt: DateTime(2026, 8, 1).add(Duration(minutes: index)),
            isArchived: false,
          ),
        );

        await tester.pumpWidget(createTestWidget(chatRooms: manyRooms));
        await tester.pumpAndSettle();

        expect(find.byType(ChatRoomAvatar), findsWidgets);
        expect(find.byType(ChatRoomAvatar).evaluate().length, lessThan(40));
        expect(
          tester
              .widgetList<AppGlassSurface>(find.byType(AppGlassSurface))
              .any((surface) => surface.quality == appGlassListSurfaceQuality),
          isTrue,
        );
      });

      testWidgets('displays title Messages', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Messages'), findsOneWidget);
        expect(find.byType(AppHeaderLogoMark), findsOneWidget);
        expect(
          tester
              .widget<AppHeaderLogoMark>(find.byType(AppHeaderLogoMark))
              .label,
          'Spring League',
        );
      });

      testWidgets('does not show a header search field',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.search), findsNothing);
        expect(find.text('Search conversations...'), findsNothing);
      });

      testWidgets('communication mode combines pinned updates and chats',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createRoutedTestWidget(
            includePinnedAnnouncements: true,
            announcements: [pinnedAnnouncement, regularAnnouncement],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Communication'), findsOneWidget);
        expect(find.text('Pinned announcements'), findsOneWidget);
        expect(find.text('Weekend schedule update'), findsOneWidget);
        expect(find.text('Regular update'), findsNothing);
        expect(find.text('Chats'), findsOneWidget);
        expect(find.byKey(const ValueKey('communication-scroll-view')),
            findsOneWidget);
      });

      testWidgets('communication announcement actions preserve full routes',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createRoutedTestWidget(
            includePinnedAnnouncements: true,
            announcements: [pinnedAnnouncement],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Weekend schedule update'));
        await tester.pumpAndSettle();
        expect(find.text('Announcement announcement-1'), findsOneWidget);

        final router = GoRouter.of(
          tester.element(find.text('Announcement announcement-1')),
        );
        router.go('/');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('view-all-announcements')));
        await tester.pumpAndSettle();
        expect(find.text('All Announcements Route'), findsOneWidget);
      });
    });

    group('FAB Visibility', () {
      testWidgets('shows FAB when organization is available',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('FAB is visible to any user with organization',
          (WidgetTester tester) async {
        final staffUser = AppUser(
          id: 'staff-user',
          email: 'staff@example.com',
          displayName: 'Staff User',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2024),
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: staffUser));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('no FAB when organization is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              organizationProvider.overrideWith(
                (ref) => null,
              ),
              chatRoomsProvider.overrideWith(
                (ref) => Stream.value(<ChatRoom>[]),
              ),
              leaguesProvider.overrideWith(
                (ref) => Stream.value(<League>[]),
              ),
              currentUserProvider.overrideWith(
                (ref) => testUser,
              ),
              unreadCountProvider.overrideWith(
                (ref, roomId) => Stream.value(0),
              ),
            ],
            child: MaterialApp(
              home: ChatListScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add), findsNothing);
      });
    });

    group('New Conversation Flow', () {
      testWidgets('fab opens new conversation page',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('New Conversation'), findsOneWidget);
        expect(find.text('Group Room'), findsNothing);
        expect(find.text('Event Room'), findsNothing);
        expect(find.text('Direct Message'), findsOneWidget);
      });

      testWidgets('manager sees managed shared room options',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: managerUser));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('Group Room'), findsOneWidget);
        expect(find.text('Event Room'), findsOneWidget);
        expect(find.text('Direct Message'), findsOneWidget);
      });

      for (final role in [
        UserRole.platformOwner,
        UserRole.superAdmin,
        UserRole.managerAdmin,
        UserRole.staff,
      ]) {
        testWidgets('${role.name} receives the correct room creation choices',
            (WidgetTester tester) async {
          final user = AppUser(
            id: role.name,
            email: '${role.name}@example.com',
            displayName: role.name,
            role: role,
            orgId: 'org-1',
            leagueIds: const ['league-1'],
            hubIds: const ['hub-1'],
            teamIds: const ['team-1'],
            createdAt: DateTime(2024),
            isActive: true,
          );

          await tester.pumpWidget(createRoutedTestWidget(user: user));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.add));
          await tester.pumpAndSettle();

          final canCreateSharedRooms = role != UserRole.staff;
          expect(find.text('Group Room'),
              canCreateSharedRooms ? findsOneWidget : findsNothing);
          expect(find.text('Event Room'),
              canCreateSharedRooms ? findsOneWidget : findsNothing);
          expect(find.text('Direct Message'), findsOneWidget);
        });
      }

      testWidgets('group option opens group room form',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: managerUser));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Group Room').last);
        await tester.pumpAndSettle();

        expect(find.text('New Group Room'), findsOneWidget);
        expect(find.text('Coaches and Managers'), findsOneWidget);
        expect(find.text('ROOM SCOPE'), findsOneWidget);
      });

      testWidgets('event option opens event room form',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: managerUser));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();

        expect(find.text('Room Name'), findsOneWidget);
        expect(find.text('LEAGUE'), findsOneWidget);
        expect(find.text('ROOM SCOPE'), findsOneWidget);
        expect(find.text('None'), findsNothing);
      });

      testWidgets('event room page hides league chips while leagues load',
          (WidgetTester tester) async {
        final controller = StreamController<List<League>>();
        addTearDown(controller.close);

        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ChatListScreen(),
            ),
            GoRoute(
              path: '/chat/new',
              builder: (context, state) => const NewChatScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => managerUser),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith((ref) => controller.stream),
              chatRoomsProvider
                  .overrideWith((ref) => Stream.value(testChatRooms)),
              orgUsersProvider
                  .overrideWith((ref) => Stream.value([managerUser])),
              unreadCountProvider
                  .overrideWith((ref, roomId) => Stream.value(0)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();

        expect(find.text('LEAGUE OPTIONAL'), findsNothing);
      });

      testWidgets('event room page hides league chips on leagues error',
          (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ChatListScreen(),
            ),
            GoRoute(
              path: '/chat/new',
              builder: (context, state) => const NewChatScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => managerUser),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith(
                (ref) => Stream<List<League>>.error('boom'),
              ),
              chatRoomsProvider
                  .overrideWith((ref) => Stream.value(testChatRooms)),
              orgUsersProvider
                  .overrideWith((ref) => Stream.value([managerUser])),
              unreadCountProvider
                  .overrideWith((ref, roomId) => Stream.value(0)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();

        expect(find.text('LEAGUE OPTIONAL'), findsNothing);
      });

      testWidgets('direct message option opens chooser page',
          (WidgetTester tester) async {
        final otherUser = AppUser(
          id: 'user-2',
          email: 'other@example.com',
          displayName: 'Other User',
          avatarUrl: 'https://example.com/other-user.jpg',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2024),
          isActive: true,
        );

        await tester.pumpWidget(
          createRoutedTestWidget(orgUsers: [testUser, otherUser]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Direct Message').last);
        await tester.pumpAndSettle();

        expect(find.text('New Direct Message'), findsOneWidget);
        expect(find.text('Other User'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is AvatarWidget &&
                widget.imageUrl == 'https://example.com/other-user.jpg',
          ),
          findsOneWidget,
        );
        expect(find.byType(ListTile), findsWidgets);
      });

      testWidgets('direct message page shows empty state when no peers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(orgUsers: [testUser]));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Direct Message').last);
        await tester.pumpAndSettle();

        expect(find.text('No other members in your organization.'),
            findsOneWidget);
      });

      testWidgets('create room submits and navigates to created route',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            managerUser,
            'org-1',
            'Playoffs',
            ChatRoomType.event,
            leagueId: 'league-1',
            participants: [managerUser.id, testUser.id],
            roomIconName: 'event',
            roomPurpose: ChatRoomPurpose.event,
          ),
        ).thenAnswer((_) async => 'created-room');

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: managerUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Playoffs');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route created-room'), findsOneWidget);
      });

      testWidgets('group room persists its purpose for category placement',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            managerUser,
            'org-1',
            'Hub Leadership',
            ChatRoomType.event,
            leagueId: 'league-1',
            participants: [managerUser.id, testUser.id],
            roomIconName: 'group',
            roomPurpose: ChatRoomPurpose.group,
          ),
        ).thenAnswer((_) async => 'group-room');

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: managerUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Group Room').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Hub Leadership');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route group-room'), findsOneWidget);
      });

      testWidgets('create room uses selected league id',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            managerUser,
            'org-1',
            'Playoffs',
            ChatRoomType.event,
            leagueId: 'league-1',
            participants: [managerUser.id, testUser.id],
            roomIconName: 'event',
            roomPurpose: ChatRoomPurpose.event,
          ),
        ).thenAnswer((_) async => 'created-room');

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: managerUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Playoffs');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route created-room'), findsOneWidget);
      });

      testWidgets('create room requires a selected league',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: managerUser,
            leagues: const [],
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'No League Event');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Please select a league.'), findsOneWidget);
        verifyZeroInteractions(service);
      });

      testWidgets('create room shows snackbar on permission denied',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            managerUser,
            'org-1',
            'Playoffs',
            ChatRoomType.event,
            leagueId: 'league-1',
            participants: [managerUser.id, testUser.id],
            roomIconName: 'event',
            roomPurpose: ChatRoomPurpose.event,
          ),
        ).thenThrow(
          PermissionDeniedException(
            action: 'createChatRoom',
            userId: managerUser.id,
            role: managerUser.role,
          ),
        );

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: managerUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event Room').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Playoffs');
        await tester.tap(find.text('Create Room'));
        await tester.pump();

        expect(
          find.text('You do not have permission to create chat rooms'),
          findsOneWidget,
        );
      });
    });

    group('Chat Room List Rendering', () {
      testWidgets('displays all chat rooms', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.text('Direct Message'), findsOneWidget);
      });

      testWidgets('shows chat type selector in requested order',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final all = find.byKey(const ValueKey('chat-type-filter-all'));
        final leagueRooms =
            find.byKey(const ValueKey('chat-type-filter-leagueRooms'));
        final hubRooms =
            find.byKey(const ValueKey('chat-type-filter-hubRooms'));
        final teamRooms =
            find.byKey(const ValueKey('chat-type-filter-teamRooms'));
        final events = find.byKey(const ValueKey('chat-type-filter-events'));
        final directMessages =
            find.byKey(const ValueKey('chat-type-filter-directMessages'));

        expect(all, findsOneWidget);
        expect(leagueRooms, findsOneWidget);
        expect(hubRooms, findsOneWidget);
        expect(teamRooms, findsOneWidget);
        expect(events, findsOneWidget);
        expect(directMessages, findsOneWidget);
        expect(tester.getTopLeft(all).dx,
            lessThan(tester.getTopLeft(leagueRooms).dx));
        expect(tester.getTopLeft(leagueRooms).dx,
            lessThan(tester.getTopLeft(hubRooms).dx));
        expect(tester.getTopLeft(hubRooms).dx,
            lessThan(tester.getTopLeft(teamRooms).dx));
        expect(tester.getTopLeft(teamRooms).dx,
            lessThan(tester.getTopLeft(events).dx));
        expect(tester.getTopLeft(events).dx,
            lessThan(tester.getTopLeft(directMessages).dx));
      });

      testWidgets('selector remains usable on a small phone with large text',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(textScaler: const TextScaler.linear(2)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('chat-type-selector')))
              .height,
          greaterThanOrEqualTo(44),
        );
        await selectRoomFilter(tester, ChatRoomListFilter.directMessages);
        expect(find.text('Direct Message'), findsOneWidget);
      });

      testWidgets('selector remains usable in phone landscape',
          (WidgetTester tester) async {
        tester.view.physicalSize = const Size(812, 375);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await selectRoomFilter(tester, ChatRoomListFilter.teamRooms);
        expect(find.text('Calgary U18 - General'), findsOneWidget);
      });

      testWidgets('selector defaults to all rooms',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.text('Direct Message'), findsOneWidget);
      });

      testWidgets('selector filters to league rooms',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await selectRoomFilter(tester, ChatRoomListFilter.leagueRooms);

        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Calgary - General'), findsNothing);
        expect(find.text('Calgary U18 - General'), findsNothing);
        expect(find.text('Tournament Bracket'), findsNothing);
        expect(find.text('Direct Message'), findsNothing);
      });

      testWidgets('selector filters to Hub rooms', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await selectRoomFilter(tester, ChatRoomListFilter.hubRooms);

        expect(find.text('Calgary - General'), findsOneWidget);
        expect(find.text('Hub GMs'), findsOneWidget);
        expect(find.text('Calgary U18 - General'), findsNothing);
        expect(find.text('Tournament Bracket'), findsNothing);
      });

      testWidgets('selector filters to Team rooms',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await selectRoomFilter(tester, ChatRoomListFilter.teamRooms);

        expect(find.text('Calgary U18 - General'), findsOneWidget);
        expect(find.text('Calgary - General'), findsNothing);
        expect(find.text('Tournament Bracket'), findsNothing);
      });

      testWidgets('selector filters to events and tournaments',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await selectRoomFilter(tester, ChatRoomListFilter.events);

        expect(find.text('Spring League Hub'), findsNothing);
        expect(find.text('Tournament Bracket'), findsOneWidget);
        expect(find.text('Hub GMs'), findsNothing);
        expect(find.text('Direct Message'), findsNothing);
      });

      testWidgets('selector filters to direct messages',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await selectRoomFilter(tester, ChatRoomListFilter.directMessages);

        expect(find.text('Spring League Hub'), findsNothing);
        expect(find.text('Tournament Bracket'), findsNothing);
        expect(find.text('Direct Message'), findsOneWidget);
      });

      testWidgets('shows last message preview', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Great game this weekend!'), findsOneWidget);
        expect(
            find.textContaining('Bracket updates available'), findsOneWidget);
      });

      testWidgets('displays correct leading visuals for room types',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.forum), findsWidgets); // Shared rooms
        await scrollRoomsUntilVisible(tester, find.text('Tournament Bracket'));
        expect(find.byIcon(Icons.event_outlined), findsOneWidget); // Event room
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.byType(AvatarWidget), findsOneWidget); // Direct message
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no chat rooms',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chatRooms: []));
        await tester.pumpAndSettle();

        expect(find.text('No chat rooms yet'), findsOneWidget);
        expect(find.text('Tap + to start a conversation'), findsOneWidget);
        expect(find.byType(EmptyState), findsOneWidget);
      });

      testWidgets('empty state message is centered',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chatRooms: []));
        await tester.pumpAndSettle();

        expect(find.byType(Center), findsWidgets);
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // League filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pumpAndSettle();

        // Should still render properly
        expect(find.byType(ChatListScreen), findsOneWidget);
      });

      testWidgets('hides league filter when there is only one league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsNothing);
      });
    });

    group('Header Search Removal', () {
      testWidgets('does not render a search text field',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('shows rooms without name filtering',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.text('Direct Message'), findsOneWidget);
      });
    });

    group('Chat Room Sections Organization', () {
      testWidgets('keeps selector options visible with one room type',
          (WidgetTester tester) async {
        final onlyDirectRooms = [
          ChatRoom(
            id: 'chat-1',
            orgId: 'org-1',
            name: 'Direct Chat',
            type: ChatRoomType.direct,
            participants: ['user-1', 'user-2'],
            createdAt: DateTime.now(),
            isArchived: false,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(chatRooms: onlyDirectRooms),
        );
        await tester.pumpAndSettle();

        expect(
            find.byKey(const ValueKey('chat-type-filter-all')), findsOneWidget);
        expect(find.byKey(const ValueKey('chat-type-filter-leagueRooms')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('chat-type-filter-hubRooms')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('chat-type-filter-teamRooms')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('chat-type-filter-events')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('chat-type-filter-directMessages')),
            findsOneWidget);
        expect(find.text('Direct Messages'), findsOneWidget);
        expect(find.text('Direct Chat'), findsOneWidget);
      });

      testWidgets('all view orders rooms by latest activity',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final leagueRoom = find.text('Spring League Hub');
        final eventRoom = find.text('Tournament Bracket');
        final directMessage = find.text('Direct Message');

        expect(leagueRoom, findsOneWidget);
        expect(eventRoom, findsOneWidget);
        expect(directMessage, findsOneWidget);
        expect(tester.getTopLeft(directMessage).dy,
            lessThan(tester.getTopLeft(eventRoom).dy));
        expect(tester.getTopLeft(eventRoom).dy,
            lessThan(tester.getTopLeft(leagueRoom).dy));
      });
    });

    group('Timestamp Display', () {
      testWidgets('displays last message timestamp',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Timestamps should be displayed for rooms with last message
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('shows no timestamp for rooms without messages',
          (WidgetTester tester) async {
        final roomsWithoutMessages = [
          ChatRoom(
            id: 'chat-1',
            orgId: 'org-1',
            name: 'Empty Room',
            type: ChatRoomType.league,
            participants: ['user-1'],
            createdAt: DateTime.now(),
            isArchived: false,
          ),
        ];

        await tester
            .pumpWidget(createTestWidget(chatRooms: roomsWithoutMessages));
        await tester.pumpAndSettle();

        expect(find.text('Empty Room'), findsOneWidget);
      });
    });

    group('Chat Room Tile Display', () {
      testWidgets('tile displays room name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Spring League Hub'), findsOneWidget);
      });

      testWidgets('tile displays no message indicator when empty',
          (WidgetTester tester) async {
        final emptyRoom = [
          ChatRoom(
            id: 'chat-1',
            orgId: 'org-1',
            name: 'Empty Room',
            type: ChatRoomType.league,
            participants: ['user-1'],
            createdAt: DateTime.now(),
            isArchived: false,
          ),
        ];

        await tester.pumpWidget(createTestWidget(chatRooms: emptyRoom));
        await tester.pumpAndSettle();

        expect(find.text('No messages yet'), findsOneWidget);
      });

      testWidgets('tile with message shows preview',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Great game this weekend!'), findsOneWidget);
      });

      testWidgets('tile shows unread badge capped at 99+',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(unreadCount: 120));
        await tester.pumpAndSettle();

        expect(find.text('99+'), findsWidgets);
      });
    });

    group('Navigation', () {
      testWidgets('chat room tiles are tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsWidgets);
      });

      testWidgets('tapping chat room tile navigates to conversation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Spring League Hub'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route chat-1'), findsOneWidget);
      });
    });

    group('League Filter with Chat Rooms', () {
      testWidgets('filtering by league shows related rooms',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('SL').last);
        await tester.pumpAndSettle();

        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsNothing);
      });

      testWidgets('direct messages appear regardless of league filter',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Direct message room should always be visible
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.text('Direct Message'), findsOneWidget);
      });
    });

    group('Multiple Rooms of Same Type', () {
      testWidgets('displays multiple league rooms in same section',
          (WidgetTester tester) async {
        final multipleLeagueRooms = [
          ChatRoom(
            id: 'chat-1',
            orgId: 'org-1',
            name: 'Spring League',
            type: ChatRoomType.league,
            leagueId: 'league-1',
            participants: ['user-1'],
            createdAt: DateTime.now(),
            isArchived: false,
            lastMessage: 'Message 1',
            lastMessageBy: 'user-1',
            lastMessageAt: DateTime.now(),
          ),
          ChatRoom(
            id: 'chat-2',
            orgId: 'org-1',
            name: 'Fall League',
            type: ChatRoomType.league,
            leagueId: 'league-2',
            participants: ['user-1'],
            createdAt: DateTime.now(),
            isArchived: false,
            lastMessage: 'Message 2',
            lastMessageBy: 'user-1',
            lastMessageAt: DateTime.now(),
          ),
        ];

        await tester
            .pumpWidget(createTestWidget(chatRooms: multipleLeagueRooms));
        await tester.pumpAndSettle();

        expect(find.text('Spring League'), findsOneWidget);
        expect(find.text('Fall League'), findsOneWidget);
        expect(find.byKey(const ValueKey('chat-type-filter-leagueRooms')),
            findsOneWidget);
      });
    });

    group('Loading and Error States', () {
      testWidgets('shows loading indicator while chats load',
          (WidgetTester tester) async {
        final controller = StreamController<List<ChatRoom>>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => testUser),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith((ref) => Stream.value(testLeagues)),
              chatRoomsProvider.overrideWith((ref) => controller.stream),
              unreadCountProvider.overrideWith(
                (ref, roomId) => Stream.value(0),
              ),
            ],
            child: MaterialApp(home: const ChatListScreen()),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('shows error message when chats fail to load',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => testUser),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith((ref) => Stream.value(testLeagues)),
              chatRoomsProvider.overrideWith(
                (ref) => Stream<List<ChatRoom>>.error('boom'),
              ),
              unreadCountProvider.overrideWith(
                (ref, roomId) => Stream.value(0),
              ),
            ],
            child: MaterialApp(home: const ChatListScreen()),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Unable to load conversations'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      });
    });
  });
}
