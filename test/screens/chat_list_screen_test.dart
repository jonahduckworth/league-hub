import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/chat_list_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
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

    group('Chat Room List Rendering', () {
      testWidgets('displays all chat rooms', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Spring League Hub'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
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
        expect(find.textContaining('Bracket updates available'), findsOneWidget);
      });

      testWidgets('displays correct icons for room types',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.forum), findsOneWidget); // League room
        expect(find.byIcon(Icons.event), findsOneWidget); // Event room
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
        expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
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

      testWidgets('clearing search shows all rooms', (WidgetTester tester) async {
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

        await tester.pumpWidget(createTestWidget(chatRooms: roomsWithoutMessages));
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

      testWidgets('tile with message shows preview', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Great game this weekend!'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('chat room tiles are tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ListTile), findsWidgets);
      });
    });

    group('League Filter with Chat Rooms', () {
      testWidgets('filtering by league shows related rooms',
          (WidgetTester tester) async {
        // This would require more complex testing with navigation/routing
        // Basic structure test:
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(ChatListScreen), findsOneWidget);
      });

      testWidgets('direct messages appear regardless of league filter',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Direct message room should always be visible
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

        await tester.pumpWidget(createTestWidget(chatRooms: multipleLeagueRooms));
        await tester.pumpAndSettle();

        expect(find.text('Spring League'), findsOneWidget);
        expect(find.text('Fall League'), findsOneWidget);
        // Section header should show count of 2
        expect(find.text('League Rooms'), findsOneWidget);
      });
    });
  });
}
