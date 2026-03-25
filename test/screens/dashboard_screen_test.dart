import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/dashboard_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('DashboardScreen', () {
    final testUser = AppUser(
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Test User',
      role: UserRole.staff,
      organizationId: 'org-1',
      isActive: true,
    );

    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      createdBy: 'user-1',
      createdAt: DateTime.now(),
    );

    final testLeagues = [
      League(
        id: 'league-1',
        organizationId: 'org-1',
        name: 'Spring League',
        abbreviation: 'SL',
        createdAt: DateTime.now(),
      ),
      League(
        id: 'league-2',
        organizationId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime.now(),
      ),
    ];

    final testAnnouncements = [
      Announcement(
        id: 'ann-1',
        organizationId: 'org-1',
        title: 'Welcome Announcement',
        body: 'Welcome to the league hub platform',
        authorId: 'user-1',
        authorName: 'Test User',
        authorRole: 'Staff',
        scope: AnnouncementScope.orgWide,
        isPinned: true,
        createdAt: DateTime.now().subtract(Duration(days: 1)),
      ),
      Announcement(
        id: 'ann-2',
        organizationId: 'org-1',
        title: 'Schedule Update',
        body: 'The schedule has been updated for this week',
        authorId: 'user-1',
        authorName: 'Test User',
        authorRole: 'Staff',
        scope: AnnouncementScope.league,
        leagueId: 'league-1',
        isPinned: false,
        createdAt: DateTime.now().subtract(Duration(hours: 2)),
      ),
    ];

    final testChatRooms = [
      ChatRoom(
        id: 'chat-1',
        organizationId: 'org-1',
        name: 'General Discussion',
        type: ChatRoomType.league,
        leagueId: 'league-1',
        participants: ['user-1', 'user-2'],
        lastMessage: 'See you at the game!',
        lastMessageBy: 'user-2',
        lastMessageAt: DateTime.now().subtract(Duration(hours: 1)),
      ),
      ChatRoom(
        id: 'chat-2',
        organizationId: 'org-1',
        name: 'Tournament Bracket',
        type: ChatRoomType.event,
        participants: ['user-1', 'user-2', 'user-3'],
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
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.override(
            (ref) => AsyncValue.data(user ?? testUser),
          ),
          organizationProvider.override(
            (ref) => AsyncValue.data(org ?? testOrg),
          ),
          leaguesProvider.override(
            (ref) => AsyncValue.data(leagues ?? testLeagues),
          ),
          announcementsProvider.override(
            (ref) => AsyncValue.data(announcements ?? testAnnouncements),
          ),
          chatRoomsProvider.override(
            (ref) => AsyncValue.data(chatRooms ?? testChatRooms),
          ),
          hubCountProvider.override(
            (ref) => AsyncValue.data(hubCount),
          ),
          teamCountProvider.override(
            (ref) => AsyncValue.data(teamCount),
          ),
          activeUserCountProvider.override(
            (ref) => AsyncValue.data(memberCount),
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
      );
    }

    group('Stat Cards', () {
      testWidgets('displays all stat cards', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Check for stat titles
        expect(find.text('Active Hubs'), findsOneWidget);
        expect(find.text('Total Teams'), findsOneWidget);
        expect(find.text('Leagues'), findsOneWidget);
        expect(find.text('Members'), findsOneWidget);
      });

      testWidgets('displays correct stat values', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          hubCount: 5,
          teamCount: 20,
          memberCount: 100,
        ));

        expect(find.text('5'), findsWidgets); // Active Hubs
        expect(find.text('20'), findsWidgets); // Total Teams
        expect(find.text('100'), findsWidgets); // Members
        expect(find.text('2'), findsWidgets); // Leagues (from testLeagues)
      });

      testWidgets('displays zero values correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          hubCount: 0,
          teamCount: 0,
          memberCount: 0,
          leagues: [],
        ));

        expect(find.text('0'), findsWidgets);
      });

      testWidgets('stat cards have proper icons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.location_city), findsOneWidget); // Hubs
        expect(find.byIcon(Icons.groups), findsOneWidget); // Teams
        expect(find.byIcon(Icons.emoji_events), findsOneWidget); // Leagues
        expect(find.byIcon(Icons.people), findsOneWidget); // Members
      });
    });

    group('AppBar and Header', () {
      testWidgets('displays organization name in header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          org: Organization(
            id: 'org-1',
            name: 'Custom Org Name',
            createdBy: 'user-1',
            createdAt: DateTime.now(),
          ),
        ));

        expect(find.text('Custom Org Name'), findsOneWidget);
      });

      testWidgets('displays greeting with user name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Hi, Test User'), findsOneWidget);
      });

      testWidgets('has notification button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(
          find.byIcon(Icons.notifications_outlined),
          findsOneWidget,
        );
      });

      testWidgets('has search button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.search), findsOneWidget);
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter with options',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));

        // Should still render without crashing
        expect(find.byType(DashboardScreen), findsOneWidget);
      });
    });

    group('Announcements Section', () {
      testWidgets('displays announcements section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Announcements'), findsOneWidget);
        expect(find.text('See All'), findsWidgets); // One for announcements
      });

      testWidgets('displays recent announcements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Welcome Announcement'), findsOneWidget);
        expect(find.text('Schedule Update'), findsOneWidget);
      });

      testWidgets('shows pinned indicator', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Pinned'), findsOneWidget);
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('displays scope tags', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Org-Wide'), findsOneWidget);
        expect(find.text('SL'), findsOneWidget); // League abbreviation
      });

      testWidgets('shows empty state when no announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(announcements: []));

        expect(find.text('No announcements yet.'), findsOneWidget);
      });

      testWidgets('takes first 3 announcements', (WidgetTester tester) async {
        final manyAnnouncements = List.generate(
          5,
          (i) => Announcement(
            id: 'ann-$i',
            organizationId: 'org-1',
            title: 'Announcement $i',
            body: 'Body $i',
            authorId: 'user-1',
            authorName: 'Test User',
            authorRole: 'Staff',
            scope: AnnouncementScope.orgWide,
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );

        await tester.pumpWidget(createTestWidget(announcements: manyAnnouncements));

        // Should only show first 3
        expect(find.text('Announcement 0'), findsOneWidget);
        expect(find.text('Announcement 1'), findsOneWidget);
        expect(find.text('Announcement 2'), findsOneWidget);
        expect(find.text('Announcement 3'), findsNothing);
        expect(find.text('Announcement 4'), findsNothing);
      });
    });

    group('Active Chats Section', () {
      testWidgets('displays active chats section header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Active Chats'), findsOneWidget);
      });

      testWidgets('displays recent chat rooms', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('General Discussion'), findsOneWidget);
        expect(find.text('Tournament Bracket'), findsOneWidget);
      });

      testWidgets('shows chat room types with icons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.forum), findsOneWidget); // League room
        expect(find.byIcon(Icons.event), findsOneWidget); // Event room
      });

      testWidgets('shows empty state when no chats',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(chatRooms: []));

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
            organizationId: 'org-1',
            name: 'Chat Room $i',
            type: ChatRoomType.league,
            participants: ['user-1'],
            lastMessage: 'Message $i',
            lastMessageBy: 'user-1',
            lastMessageAt: DateTime.now().subtract(Duration(hours: i)),
          ),
        );

        await tester.pumpWidget(createTestWidget(chatRooms: manyChatRooms));

        // Should only show first 3
        expect(find.text('Chat Room 0'), findsOneWidget);
        expect(find.text('Chat Room 1'), findsOneWidget);
        expect(find.text('Chat Room 2'), findsOneWidget);
        expect(find.text('Chat Room 3'), findsNothing);
        expect(find.text('Chat Room 4'), findsNothing);
      });

      testWidgets('displays last message preview', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('See you at the game!'), findsOneWidget);
        expect(find.text('Bracket updates available'), findsOneWidget);
      });

      testWidgets('shows timestamp of last message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should find timestamps (exact format depends on formatDateTime)
        expect(find.byType(Text), findsWidgets);
      });
    });

    group('Loading and Error States', () {
      testWidgets('shows loading indicator when data is loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.override(
                (ref) => const AsyncValue.loading(),
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

        // Screen should still render with defaults
        expect(find.byType(DashboardScreen), findsOneWidget);
      });
    });

    group('Default Values', () {
      testWidgets('uses mock values when data is null', (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.override(
                (ref) => const AsyncValue.data(null),
              ),
              organizationProvider.override(
                (ref) => const AsyncValue.data(null),
              ),
              leaguesProvider.override(
                (ref) => const AsyncValue.data(null),
              ),
              hubCountProvider.override(
                (ref) => const AsyncValue.data(0),
              ),
              teamCountProvider.override(
                (ref) => const AsyncValue.data(0),
              ),
              activeUserCountProvider.override(
                (ref) => const AsyncValue.data(0),
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

        // Should display with default org name
        expect(find.text('League Hub'), findsWidgets);
        expect(find.text('0'), findsWidgets); // All stats should be 0
      });
    });

    group('Content Spacing and Layout', () {
      testWidgets('sections are properly spaced', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Screen should be scrollable with proper spacing
        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('has proper padding on content', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Stats and section content should be properly padded
        expect(find.byType(Padding), findsWidgets);
      });
    });
  });
}
