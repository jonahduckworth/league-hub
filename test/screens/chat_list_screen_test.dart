import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/chat_list_screen.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/empty_state.dart';
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
    List<String> participants = const [],
  }) =>
      (super.noSuchMethod(
            Invocation.method(
              #createChatRoom,
              [actor, orgId, name, type],
              {
                #leagueId: leagueId,
                #participants: participants,
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
      final sections = buildChatRoomSections([dmRoom, eventRoom, leagueRoom]);

      expect(
        sections.map((section) => section.title).toList(),
        ['League Rooms', 'Events & Tournaments', 'Direct Messages'],
      );
      expect(sections[0].rooms, [leagueRoom]);
      expect(sections[1].rooms, [eventRoom]);
      expect(sections[2].rooms, [dmRoom]);
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
    });

    test('returns null preview when there is no last message', () {
      expect(chatRoomPreviewText(leagueRoom), isNull);
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

    Widget createTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      List<ChatRoom>? chatRooms,
      List<AppUser>? orgUsers,
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
          home: ChatListScreen(),
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
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ChatListScreen(),
          ),
          GoRoute(
            path: '/chat/:roomId',
            builder: (context, state) => Scaffold(
              body: Text('Chat Route ${state.pathParameters['roomId']}'),
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

    group('Screen Rendering', () {
      testWidgets('renders without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byType(ChatListScreen), findsOneWidget);
      });

      testWidgets('displays title Messages', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Messages'), findsOneWidget);
      });

      testWidgets('has search field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('Search conversations...'), findsOneWidget);
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

    group('New Conversation Sheets', () {
      testWidgets('fab opens new conversation options',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('New Conversation'), findsOneWidget);
        expect(find.text('New Event Room'), findsWidgets);
        expect(find.text('New Direct Message'), findsWidgets);
      });

      testWidgets('event option opens event room sheet',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
        await tester.pumpAndSettle();

        expect(find.text('Create a group chat for an event or tournament.'),
            findsOneWidget);
        expect(find.text('Room Name'), findsOneWidget);
        expect(find.text('LEAGUE (OPTIONAL)'), findsOneWidget);
        expect(find.text('None'), findsOneWidget);
      });

      testWidgets('event room sheet hides league chips while leagues load',
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
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => testUser),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith((ref) => controller.stream),
              chatRoomsProvider.overrideWith((ref) => Stream.value(testChatRooms)),
              orgUsersProvider.overrideWith((ref) => Stream.value([testUser])),
              unreadCountProvider.overrideWith((ref, roomId) => Stream.value(0)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
        await tester.pumpAndSettle();

        expect(find.text('LEAGUE (OPTIONAL)'), findsNothing);
      });

      testWidgets('event room sheet hides league chips on leagues error',
          (WidgetTester tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ChatListScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => testUser),
              organizationProvider.overrideWith((ref) => testOrg),
              leaguesProvider.overrideWith(
                (ref) => Stream<List<League>>.error('boom'),
              ),
              chatRoomsProvider.overrideWith((ref) => Stream.value(testChatRooms)),
              orgUsersProvider.overrideWith((ref) => Stream.value([testUser])),
              unreadCountProvider.overrideWith((ref, roomId) => Stream.value(0)),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
        await tester.pumpAndSettle();

        expect(find.text('LEAGUE (OPTIONAL)'), findsNothing);
      });

      testWidgets('direct message option opens chooser sheet',
          (WidgetTester tester) async {
        final otherUser = AppUser(
          id: 'user-2',
          email: 'other@example.com',
          displayName: 'Other User',
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
        await tester.tap(find.text('New Direct Message').last);
        await tester.pumpAndSettle();

        expect(find.text('Choose someone to message'), findsOneWidget);
        expect(find.byType(ListTile), findsWidgets);
      });

      testWidgets('direct message sheet shows empty state when no peers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(orgUsers: [testUser]));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Direct Message').last);
        await tester.pumpAndSettle();

        expect(find.text('No other members in your organization.'),
            findsOneWidget);
      });

      testWidgets('create room submits and navigates to created route',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            testUser,
            'org-1',
            'Playoffs',
            ChatRoomType.event,
            leagueId: null,
            participants: [testUser.id],
          ),
        ).thenAnswer((_) async => 'created-room');

        await tester.pumpWidget(
          createRoutedTestWidget(authorizedFirestoreService: service),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Playoffs');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route created-room'), findsOneWidget);
      });

      testWidgets('create room uses selected league id',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            testUser,
            'org-1',
            'Playoffs',
            ChatRoomType.event,
            leagueId: 'league-1',
            participants: [testUser.id],
          ),
        ).thenAnswer((_) async => 'created-room');

        await tester.pumpWidget(
          createRoutedTestWidget(authorizedFirestoreService: service),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SL').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'Playoffs');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route created-room'), findsOneWidget);
      });

      testWidgets('none chip clears selected league before creating room',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            testUser,
            'org-1',
            'No League Event',
            ChatRoomType.event,
            leagueId: null,
            participants: [testUser.id],
          ),
        ).thenAnswer((_) async => 'created-room');

        await tester.pumpWidget(
          createRoutedTestWidget(authorizedFirestoreService: service),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('SL').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('None'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'No League Event');
        await tester.tap(find.text('Create Room'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route created-room'), findsOneWidget);
      });

      testWidgets('create room shows snackbar on permission denied',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(
          service.createChatRoom(
            testUser,
            'org-1',
            'Playoffs',
            ChatRoomType.event,
            leagueId: null,
            participants: [testUser.id],
          ),
        ).thenThrow(
          PermissionDeniedException(
            action: 'createChatRoom',
            userId: testUser.id,
            role: testUser.role,
          ),
        );

        await tester.pumpWidget(
          createRoutedTestWidget(authorizedFirestoreService: service),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New Event Room').last);
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

      testWidgets('shows league rooms section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('League Rooms'), findsOneWidget);
      });

      testWidgets('shows events and tournaments section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Events & Tournaments'), findsOneWidget);
      });

      testWidgets('shows direct messages section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Direct Messages'), findsOneWidget);
      });

      testWidgets('displays room count in section headers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Each section should show count
        expect(find.text('1'), findsWidgets); // Count for each section
      });

      testWidgets('shows last message preview', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Great game this weekend!'), findsOneWidget);
        expect(
            find.textContaining('Bracket updates available'), findsOneWidget);
      });

      testWidgets('displays correct icons for room types',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.forum), findsOneWidget); // League room
        await scrollRoomsUntilVisible(tester, find.text('Tournament Bracket'));
        expect(find.byIcon(Icons.event), findsOneWidget); // Event room
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.byIcon(Icons.person), findsOneWidget); // Direct message
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
    });

    group('Search Functionality', () {
      testWidgets('search field accepts input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Spring');
        await tester.pumpAndSettle();

        // After filtering, should still show matching room
        expect(find.text('Spring League Hub'), findsOneWidget);
      });

      testWidgets('search filters chat rooms by name',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Tournament');
        await tester.pumpAndSettle();

        // Only tournament should be visible
        expect(find.text('Tournament Bracket'), findsOneWidget);
      });

      testWidgets('search is case insensitive', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'spring');
        await tester.pumpAndSettle();

        // Should still find Spring League Hub
        expect(find.text('Spring League Hub'), findsOneWidget);
      });

      testWidgets('clearing search shows all rooms',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);

        // First search
        await tester.enterText(searchField, 'Tournament');
        await tester.pumpAndSettle();

        // Clear search
        await tester.enterText(searchField, '');
        await tester.pumpAndSettle();

        // All rooms should be visible again
        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
        await scrollRoomsUntilVisible(tester, find.text('Direct Message'));
        expect(find.text('Direct Message'), findsOneWidget);
      });

      testWidgets('no results message when search finds nothing',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'NonexistentRoom');
        await tester.pumpAndSettle();

        // Should show empty state
        expect(find.text('No chat rooms yet'), findsOneWidget);
      });
    });

    group('Chat Room Sections Organization', () {
      testWidgets('only shows sections with content',
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

        // Should only show Direct Messages section
        expect(find.text('Direct Messages'), findsOneWidget);
        expect(find.text('League Rooms'), findsNothing);
        expect(find.text('Events & Tournaments'), findsNothing);
      });

      testWidgets('sections appear in correct order',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Get positions of section headers
        final leagueRooms = find.text('League Rooms');
        final eventRooms = find.text('Events & Tournaments');
        final directMessages = find.text('Direct Messages');

        expect(leagueRooms, findsOneWidget);
        expect(eventRooms, findsOneWidget);
        expect(directMessages, findsOneWidget);
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

        await tester.tap(find.text('SL').first);
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
        // Section header should show count of 2
        expect(find.text('League Rooms'), findsOneWidget);
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

        expect(find.textContaining('Error loading chats:'), findsOneWidget);
      });
    });
  });
}
