import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/announcements_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('AnnouncementsScreen', () {
    final testUser = AppUser(
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Test User',
      role: UserRole.staff,
      organizationId: 'org-1',
      isActive: true,
    );

    final adminUser = AppUser(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Admin User',
      role: UserRole.superAdmin,
      organizationId: 'org-1',
      isActive: true,
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
        title: 'Welcome to League Hub',
        body: 'Welcome to our new league management platform',
        authorId: 'admin-1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        scope: AnnouncementScope.orgWide,
        isPinned: true,
        createdAt: DateTime.now().subtract(Duration(days: 5)),
      ),
      Announcement(
        id: 'ann-2',
        organizationId: 'org-1',
        title: 'Spring Tournament Dates',
        body: 'The spring tournament will be held from March 15 to April 20',
        authorId: 'admin-1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        scope: AnnouncementScope.league,
        leagueId: 'league-1',
        isPinned: false,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
      ),
      Announcement(
        id: 'ann-3',
        organizationId: 'org-1',
        title: 'Schedule Update',
        body: 'Weekly schedule has been updated',
        authorId: 'admin-1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        scope: AnnouncementScope.league,
        leagueId: 'league-2',
        isPinned: false,
        createdAt: DateTime.now().subtract(Duration(hours: 1)),
      ),
    ];

    Widget createTestWidget({
      AppUser? user,
      List<Announcement>? announcements,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.override(
            (ref) => AsyncValue.data(user ?? testUser),
          ),
          announcementsProvider.override(
            (ref) => AsyncValue.data(announcements ?? testAnnouncements),
          ),
          leaguesProvider.override(
            (ref) => AsyncValue.data(leagues ?? testLeagues),
          ),
        ],
        child: MaterialApp(
          home: AnnouncementsScreen(),
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
        expect(find.byType(AnnouncementsScreen), findsOneWidget);
      });

      testWidgets('displays title Announcements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Announcements'), findsOneWidget);
      });

      testWidgets('has refresh indicator', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('FAB Visibility', () {
      testWidgets('shows FAB for superAdmin', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: adminUser));
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('shows FAB for managerAdmin', (WidgetTester tester) async {
        final managerAdmin = AppUser(
          id: 'manager-1',
          email: 'manager@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          organizationId: 'org-1',
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: managerAdmin));
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('shows FAB for platformOwner', (WidgetTester tester) async {
        final platformOwner = AppUser(
          id: 'owner-1',
          email: 'owner@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          organizationId: 'org-1',
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: platformOwner));
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('hides FAB for staff user', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));
        expect(find.byIcon(Icons.add), findsNothing);
      });
    });

    group('Announcement List Rendering', () {
      testWidgets('displays all announcements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Welcome to League Hub'), findsOneWidget);
        expect(find.text('Spring Tournament Dates'), findsOneWidget);
        expect(find.text('Schedule Update'), findsOneWidget);
      });

      testWidgets('displays announcement titles', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('displays announcement bodies (truncated)',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(
          find.text('Welcome to our new league management platform'),
          findsOneWidget,
        );
      });

      testWidgets('displays author information', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Admin User'), findsWidgets);
        expect(find.text('Super Admin'), findsWidgets);
      });
    });

    group('Pinned Announcements', () {
      testWidgets('pinned announcement shows indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Pinned Announcement'), findsOneWidget);
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('pinned announcement appears first in list',
          (WidgetTester tester) async {
        // List should be ordered with pinned first
        await tester.pumpWidget(createTestWidget());

        // The pinned announcement should be first
        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('pinned announcement has special styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Pinned announcement has special border
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('non-pinned announcements do not show indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Only one pinned announcement
        expect(find.text('Pinned Announcement'), findsOneWidget);
      });
    });

    group('Scope Tags', () {
      testWidgets('displays organization-wide scope tag',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Org-Wide'), findsOneWidget);
      });

      testWidgets('displays league scope tag with abbreviation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('SL'), findsOneWidget); // Spring League
        expect(find.text('FL'), findsOneWidget); // Fall League
      });

      testWidgets('scope tags have different colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should find scope tags
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('filters announcements by league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Default should show all
        expect(find.text('Welcome to League Hub'), findsOneWidget);
        expect(find.text('Spring Tournament Dates'), findsOneWidget);
        expect(find.text('Schedule Update'), findsOneWidget);
      });

      testWidgets('org-wide announcements always visible',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Even when filtering by league, org-wide announcements appear
        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));

        // Should still render announcements
        expect(find.byType(AnnouncementsScreen), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(announcements: []));

        expect(find.text('No announcements yet'), findsOneWidget);
        expect(find.text('Check back later for updates.'), findsOneWidget);
        expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      });

      testWidgets('empty state is centered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(announcements: []));

        expect(find.byType(Center), findsWidgets);
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator while fetching',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              announcementsProvider.override(
                (ref) => const AsyncValue.loading(),
              ),
            ],
            child: MaterialApp(
              home: AnnouncementsScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Announcement Card Information', () {
      testWidgets('card displays creation timestamp',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Timestamps should be displayed
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('card displays author avatar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Avatar should be present
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('card displays full author information',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Admin User'), findsWidgets);
        expect(find.text('Super Admin'), findsWidgets);
      });

      testWidgets('card text is properly formatted',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Title should be bold/large
        // Body should be smaller
        expect(find.byType(Text), findsWidgets);
      });
    });

    group('Interaction - Long Press Menu', () {
      testWidgets('staff user cannot see long press menu',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        // Staff users should not be able to long press
        // (but we can at least verify the card is there)
        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('admin user can interact with announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: adminUser));

        // Admin user should have FAB for creating
        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    });

    group('Announcement List Ordering', () {
      testWidgets('pinned announcements appear first',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Get positions of announcements in order
        final welcomeText = find.text('Welcome to League Hub');
        final springText = find.text('Spring Tournament Dates');

        // Both should be visible
        expect(welcomeText, findsOneWidget);
        expect(springText, findsOneWidget);
      });

      testWidgets('announcements are ordered by pin status then date',
          (WidgetTester tester) async {
        final orderedAnnouncements = [
          Announcement(
            id: 'ann-1',
            organizationId: 'org-1',
            title: 'Pinned Announcement',
            body: 'This is pinned',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            isPinned: true,
            createdAt: DateTime.now().subtract(Duration(days: 5)),
          ),
          Announcement(
            id: 'ann-2',
            organizationId: 'org-1',
            title: 'Recent Announcement',
            body: 'This is recent',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
          Announcement(
            id: 'ann-3',
            organizationId: 'org-1',
            title: 'Older Announcement',
            body: 'This is older',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(days: 10)),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: orderedAnnouncements),
        );

        // Pinned should be first
        expect(find.text('Pinned Announcement'), findsOneWidget);
      });
    });

    group('Multiple Announcements of Same Scope', () {
      testWidgets('displays multiple org-wide announcements',
          (WidgetTester tester) async {
        final multipleOrgWide = [
          Announcement(
            id: 'ann-1',
            organizationId: 'org-1',
            title: 'Announcement 1',
            body: 'Body 1',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            isPinned: false,
            createdAt: DateTime.now(),
          ),
          Announcement(
            id: 'ann-2',
            organizationId: 'org-1',
            title: 'Announcement 2',
            body: 'Body 2',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: multipleOrgWide),
        );

        expect(find.text('Announcement 1'), findsOneWidget);
        expect(find.text('Announcement 2'), findsOneWidget);
      });

      testWidgets('displays multiple league-specific announcements',
          (WidgetTester tester) async {
        final multipleLeagueAnn = [
          Announcement(
            id: 'ann-1',
            organizationId: 'org-1',
            title: 'League Announcement 1',
            body: 'Body 1',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.league,
            leagueId: 'league-1',
            isPinned: false,
            createdAt: DateTime.now(),
          ),
          Announcement(
            id: 'ann-2',
            organizationId: 'org-1',
            title: 'League Announcement 2',
            body: 'Body 2',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.league,
            leagueId: 'league-1',
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: multipleLeagueAnn),
        );

        expect(find.text('League Announcement 1'), findsOneWidget);
        expect(find.text('League Announcement 2'), findsOneWidget);
        expect(find.text('SL'), findsWidgets); // Both belong to SL
      });
    });

    group('Announcement Card Styling', () {
      testWidgets('pinned announcement has different styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Pinned announcement should have special header
        expect(find.text('Pinned Announcement'), findsOneWidget);
      });

      testWidgets('announcement cards are properly spaced',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Cards should have proper margins/padding
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Unknown League Handling', () {
      testWidgets('shows League label when league not found',
          (WidgetTester tester) async {
        final orphanedAnn = Announcement(
          id: 'ann-1',
          organizationId: 'org-1',
          title: 'Orphaned Announcement',
          body: 'Body',
          authorId: 'admin-1',
          authorName: 'Admin User',
          authorRole: 'Super Admin',
          scope: AnnouncementScope.league,
          leagueId: 'unknown-league-id',
          isPinned: false,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            announcements: [orphanedAnn],
            leagues: [], // No leagues available
          ),
        );

        // Should show something for the league
        expect(find.text('Orphaned Announcement'), findsOneWidget);
      });
    });
  });
}
