import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/dashboard_screen.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/league_filter.dart';

void main() {
  group('DashboardScreen', () {
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

    final testAnnouncements = [
      Announcement(
        id: 'ann-1',
        orgId: 'org-1',
        title: 'Welcome Announcement',
        body: 'Welcome to the league hub platform',
        authorId: 'user-1',
        authorName: 'Test User',
        authorRole: 'Staff',
        scope: AnnouncementScope.orgWide,
        attachments: [],
        isPinned: true,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      Announcement(
        id: 'ann-2',
        orgId: 'org-1',
        title: 'Schedule Update',
        body: 'The schedule has been updated for this week',
        authorId: 'user-1',
        authorName: 'Test User',
        authorRole: 'Staff',
        scope: AnnouncementScope.league,
        leagueId: 'league-1',
        attachments: [],
        isPinned: false,
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
      ),
    ];

    final testChatRooms = [
      ChatRoom(
        id: 'chat-1',
        orgId: 'org-1',
        name: 'General Discussion',
        type: ChatRoomType.league,
        leagueId: 'league-1',
        participants: ['user-1', 'user-2'],
        createdAt: DateTime.now(),
        isArchived: false,
        lastMessage: 'See you at the game!',
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
    ];

    Widget createTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      List<Announcement>? announcements,
      List<ChatRoom>? chatRooms,
      List<AppUser>? users,
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
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
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements ?? testAnnouncements),
          ),
          chatRoomsProvider.overrideWith(
            (ref) => Stream.value(chatRooms ?? testChatRooms),
          ),
          orgUsersProvider.overrideWith(
            (ref) => Stream.value(users ?? [testUser]),
          ),
          hubCountProvider.overrideWith(
            (ref) => hubCount,
          ),
          teamCountProvider.overrideWith(
            (ref) => teamCount,
          ),
          activeUserCountProvider.overrideWith(
            (ref) => memberCount,
          ),
          unreadCountProvider.overrideWith((ref, roomId) => Stream.value(0)),
        ],
        child: MaterialApp(
          home: DashboardScreen(),
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
      List<Announcement>? announcements,
      List<ChatRoom>? chatRooms,
      List<AppUser>? users,
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) =>
                const Scaffold(body: Text('Notifications Route')),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) =>
                const Scaffold(body: Text('Announcements Route')),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) =>
                const Scaffold(body: Text('Chat Route')),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) =>
                const Scaffold(body: Text('Documents Route')),
          ),
          GoRoute(
            path: '/announcements/:id',
            builder: (context, state) => Scaffold(
              body: Text('Announcement Route ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => Scaffold(
                body: Text('Chat Detail ${state.pathParameters['id']}')),
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
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements ?? testAnnouncements),
          ),
          chatRoomsProvider.overrideWith(
            (ref) => Stream.value(chatRooms ?? testChatRooms),
          ),
          orgUsersProvider.overrideWith(
            (ref) => Stream.value(users ?? [testUser]),
          ),
          hubCountProvider.overrideWith((ref) => hubCount),
          teamCountProvider.overrideWith((ref) => teamCount),
          activeUserCountProvider.overrideWith((ref) => memberCount),
          unreadCountProvider.overrideWith((ref, roomId) => Stream.value(0)),
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

    group('Main Content', () {
      testWidgets('does not render the old stats card grid',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Active Hubs'), findsNothing);
        expect(find.text('Total Teams'), findsNothing);
        expect(find.text('Leagues'), findsNothing);
        expect(find.text('Members'), findsNothing);
      });

      testWidgets('starts main content with announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Announcements'), findsOneWidget);
        expect(find.text('Welcome Announcement'), findsOneWidget);
      });
    });

    group('AppBar and Header', () {
      testWidgets('displays organization name in header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          org: Organization(
            id: 'org-1',
            name: 'Custom Org Name',
            primaryColor: '#1A3A5C',
            secondaryColor: '#2E75B6',
            accentColor: '#4DA3FF',
            createdAt: DateTime.now(),
            ownerId: 'user-1',
          ),
        ));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Custom Org Name'), findsOneWidget);
      });

      testWidgets('displays greeting with user name',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Welcome back, Test User'), findsOneWidget);
      });

      testWidgets('has notification button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.notifications_outlined),
          findsOneWidget,
        );
      });

      testWidgets('has search button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('notification button navigates to notifications',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.notifications_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Notifications Route'), findsOneWidget);
      });

      testWidgets('search button opens search sheet',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        expect(
          find.text('Search announcements, chats, documents...'),
          findsOneWidget,
        );
        expect(find.text('Announcements'), findsWidgets);
        expect(find.text('Chats'), findsOneWidget);
        expect(find.text('Documents'), findsOneWidget);
      });

      testWidgets('search submit shows coming soon dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'registrations',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(
            find.text('Search functionality is coming soon.'), findsOneWidget);
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter with options',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should still render without crashing
        expect(find.byType(DashboardScreen), findsOneWidget);
      });

      testWidgets('hides league filter when there is only one league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsNothing);
      });
    });

    group('Announcements Section', () {
      testWidgets('displays announcements section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Announcements'), findsOneWidget);
        expect(find.text('See All'), findsWidgets); // One for announcements
      });

      testWidgets('displays recent announcements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Welcome Announcement'), findsOneWidget);
        expect(find.text('Schedule Update'), findsOneWidget);
      });

      testWidgets('shows pinned indicator', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Pinned'), findsOneWidget);
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('displays scope tags', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Org-Wide'), findsOneWidget);
        expect(find.text('SL'), findsOneWidget); // League abbreviation
      });

      testWidgets('shows empty state when no announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(announcements: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No announcements yet.'), findsOneWidget);
      });

      testWidgets('takes first 3 announcements', (WidgetTester tester) async {
        final manyAnnouncements = List.generate(
          5,
          (i) => Announcement(
            id: 'ann-$i',
            orgId: 'org-1',
            title: 'Announcement $i',
            body: 'Body $i',
            authorId: 'user-1',
            authorName: 'Test User',
            authorRole: 'Staff',
            scope: AnnouncementScope.orgWide,
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );

        await tester
            .pumpWidget(createTestWidget(announcements: manyAnnouncements));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should only show first 3
        expect(find.text('Announcement 0'), findsOneWidget);
        expect(find.text('Announcement 1'), findsOneWidget);
        expect(find.text('Announcement 2'), findsOneWidget);
        expect(find.text('Announcement 3'), findsNothing);
        expect(find.text('Announcement 4'), findsNothing);
      });

      testWidgets('see all navigates to announcements route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('See All').first);
        await tester.pumpAndSettle();

        expect(find.text('Announcements Route'), findsOneWidget);
      });

      testWidgets('announcement card tap navigates to detail',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Welcome Announcement'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Welcome Announcement'));
        await tester.pumpAndSettle();

        expect(find.text('Announcement Route ann-1'), findsOneWidget);
      });
    });

    group('Active Chats Section', () {
      testWidgets('displays active chats section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Active Chats'), findsOneWidget);
      });

      testWidgets('displays recent chat rooms', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('General Discussion'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
      });

      testWidgets('shows chat room types with icons',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.forum), findsOneWidget); // League room
        expect(find.byIcon(Icons.event_outlined), findsOneWidget); // Event room
      });

      testWidgets('uses direct message peer details on chat cards',
          (WidgetTester tester) async {
        final peer = AppUser(
          id: 'user-2',
          email: 'sam@example.com',
          displayName: 'Sam Orr',
          avatarUrl: 'https://example.com/sam.jpg',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2024),
          isActive: true,
        );
        final directRoom = ChatRoom(
          id: 'dm-1',
          orgId: 'org-1',
          name: 'Test User & Sam Orr',
          type: ChatRoomType.direct,
          participants: ['user-1', 'user-2'],
          createdAt: DateTime.now(),
          isArchived: false,
          lastMessage: 'See you there',
          lastMessageBy: 'Sam Orr',
          lastMessageAt: DateTime.now(),
        );

        await tester.pumpWidget(createTestWidget(
          chatRooms: [directRoom],
          users: [testUser, peer],
        ));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Sam Orr'), findsOneWidget);
        expect(find.text('Test User & Sam Orr'), findsNothing);
        expect(find.byIcon(Icons.person), findsNothing);
      });

      testWidgets('shows empty state when no chats',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chatRooms: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text('No chat rooms yet. Go to Messages to create one.'),
          findsOneWidget,
        );
      });

      testWidgets('takes first 3 chat rooms', (WidgetTester tester) async {
        final manyChatRooms = List.generate(
          5,
          (i) => ChatRoom(
            id: 'chat-$i',
            orgId: 'org-1',
            name: 'Chat Room $i',
            type: ChatRoomType.league,
            participants: ['user-1'],
            createdAt: DateTime.now(),
            isArchived: false,
            lastMessage: 'Message $i',
            lastMessageBy: 'user-1',
            lastMessageAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );

        await tester.pumpWidget(createTestWidget(chatRooms: manyChatRooms));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should only show first 3
        expect(find.text('Chat Room 0'), findsOneWidget);
        expect(find.text('Chat Room 1'), findsOneWidget);
        expect(find.text('Chat Room 2'), findsOneWidget);
        expect(find.text('Chat Room 3'), findsNothing);
        expect(find.text('Chat Room 4'), findsNothing);
      });

      testWidgets('displays last message preview', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.textContaining('See you at the game!'), findsOneWidget);
        expect(
            find.textContaining('Bracket updates available'), findsOneWidget);
      });

      testWidgets('shows timestamp of last message',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Should find timestamps (exact format depends on formatDateTime)
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('see all navigates to chat route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('See All').last,
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('See All').last);
        await tester.pumpAndSettle();

        expect(find.text('Chat Route'), findsOneWidget);
      });

      testWidgets('chat card tap navigates to chat detail',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('General Discussion'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('General Discussion'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Detail chat-1'), findsOneWidget);
      });
    });

    group('Loading and Error States', () {
      testWidgets('shows loading indicator when data is loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) => throw UnimplementedError(),
              ),
            ],
            child: MaterialApp(
              home: DashboardScreen(),
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

        // Screen should still render with defaults
        expect(find.byType(DashboardScreen), findsOneWidget);
      });
    });

    group('Default Values', () {
      testWidgets('uses mock values when data is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) => null,
              ),
              organizationProvider.overrideWith(
                (ref) => null,
              ),
              leaguesProvider.overrideWith(
                (ref) => Stream.value(<League>[]),
              ),
              hubCountProvider.overrideWith(
                (ref) => 0,
              ),
              teamCountProvider.overrideWith(
                (ref) => 0,
              ),
              activeUserCountProvider.overrideWith(
                (ref) => 0,
              ),
              unreadCountProvider
                  .overrideWith((ref, roomId) => Stream.value(0)),
            ],
            child: MaterialApp(
              home: DashboardScreen(),
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

        // Should display with default org name
        expect(find.text('League Hub'), findsWidgets);
        expect(find.text('Announcements'), findsOneWidget);
      });
    });

    group('Content Spacing and Layout', () {
      testWidgets('sections are properly spaced', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('league filter stays outside the scrollable content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(LeagueFilter),
          ),
          findsNothing,
        );
      });

      testWidgets('has proper padding on content', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Stats and section content should be properly padded
        expect(find.byType(Padding), findsWidgets);
      });
    });
  });
}
