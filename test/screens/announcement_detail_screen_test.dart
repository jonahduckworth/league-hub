import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/announcement_detail_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('AnnouncementDetailScreen', () {
    final staffUser = AppUser(
      id: 'user-1',
      email: 'staff@example.com',
      displayName: 'Staff User',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: ['hub-1'],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final authorUser = AppUser(
      id: 'author-1',
      email: 'author@example.com',
      displayName: 'Manager Admin',
      role: UserRole.managerAdmin,
      orgId: 'org-1',
      hubIds: ['hub-1'],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final superAdminUser = AppUser(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Admin User',
      role: UserRole.superAdmin,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final testLeagues = [
      League(
        id: 'league-1',
        orgId: 'org-1',
        name: 'Spring League',
        abbreviation: 'SL',
        createdAt: DateTime.now(),
      ),
    ];

    final pinnedOrgWideAnnouncement = Announcement(
      id: 'ann-1',
      orgId: 'org-1',
      title: 'Welcome Announcement',
      body: 'Welcome to our league management platform',
      authorId: 'author-1',
      authorName: 'Manager Admin',
      authorRole: 'Manager Admin',
      scope: AnnouncementScope.orgWide,
      attachments: [],
      isPinned: true,
      createdAt: DateTime.now().subtract(Duration(days: 5)),
    );

    final leagueScopeAnnouncement = Announcement(
      id: 'ann-2',
      orgId: 'org-1',
      title: 'League Schedule Update',
      body: 'The spring tournament will be held from March 15 to April 20',
      authorId: 'author-1',
      authorName: 'Manager Admin',
      authorRole: 'Manager Admin',
      scope: AnnouncementScope.league,
      leagueId: 'league-1',
      attachments: [],
      isPinned: false,
      createdAt: DateTime.now().subtract(Duration(days: 2)),
    );

    final hubScopeAnnouncement = Announcement(
      id: 'ann-3',
      orgId: 'org-1',
      title: 'Hub Event',
      body: 'Hub event details here',
      authorId: 'author-1',
      authorName: 'Manager Admin',
      authorRole: 'Manager Admin',
      scope: AnnouncementScope.hub,
      hubId: 'hub-1',
      attachments: [],
      isPinned: false,
      createdAt: DateTime.now().subtract(Duration(hours: 1)),
    );

    Widget createTestWidget({
      required String announcementId,
      AppUser? user,
      List<Announcement>? announcements,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? staffUser,
          ),
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements ?? [pinnedOrgWideAnnouncement]),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
        ],
        child: MaterialApp(
          home: AnnouncementDetailScreen(announcementId: announcementId),
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
      testWidgets('renders announcement details without crashing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(announcementId: 'ann-1'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome Announcement'), findsOneWidget);
      });

      testWidgets('displays announcement title', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(announcementId: 'ann-1'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Welcome Announcement'), findsOneWidget);
      });

      testWidgets('displays announcement body', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(announcementId: 'ann-1'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Welcome to our league management platform'),
          findsOneWidget,
        );
      });

      testWidgets('displays author information', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(announcementId: 'ann-1'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Manager Admin'), findsWidgets);
      });

      testWidgets('displays announcement not found message when missing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'non-existent',
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Announcement not found.'), findsOneWidget);
      });
    });

    group('Scope Tag Display', () {
      testWidgets('displays org-wide scope tag', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Org-Wide'), findsOneWidget);
      });

      testWidgets('displays league scope tag with league name',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-2',
            announcements: [leagueScopeAnnouncement],
            leagues: testLeagues,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Spring League'), findsOneWidget);
      });

      testWidgets('displays hub scope tag', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-3',
            announcements: [hubScopeAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Hub'), findsOneWidget);
      });
    });

    group('Pinned Indicator', () {
      testWidgets('displays pinned banner for pinned announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pinned Announcement'), findsOneWidget);
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('does not display pinned banner for unpinned announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-2',
            announcements: [leagueScopeAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pinned Announcement'), findsNothing);
      });
    });

    group('Delete Button Visibility', () {
      testWidgets('shows delete button for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            user: superAdminUser,
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byIcon(Icons.delete_outline),
          findsOneWidget,
        );
      });

      testWidgets('shows delete button for author',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            user: authorUser,
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byIcon(Icons.delete_outline),
          findsOneWidget,
        );
      });

      testWidgets('hides delete button for staff members',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            user: staffUser,
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });
    });

    group('Edit Button Visibility', () {
      testWidgets('shows edit button for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            user: superAdminUser,
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      });

      testWidgets('shows edit button for author',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            user: authorUser,
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      });

      testWidgets('hides edit button for non-author staff',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            user: staffUser,
            announcements: [pinnedOrgWideAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.edit_outlined), findsNothing);
      });
    });

    group('Attachment Display', () {
      testWidgets('displays announcement without attachments',
          (WidgetTester tester) async {
        final announcementNoAttachments = Announcement(
          id: 'ann-no-attach',
          orgId: 'org-1',
          title: 'No Attachments',
          body: 'This announcement has no attachments',
          authorId: 'author-1',
          authorName: 'Manager Admin',
          authorRole: 'Manager Admin',
          scope: AnnouncementScope.orgWide,
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-no-attach',
            announcements: [announcementNoAttachments],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('No Attachments'), findsOneWidget);
      });
    });

    group('Loading States', () {
      testWidgets('shows loading indicator while fetching',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(announcementId: 'ann-1'),
        );
        // Before pumpAndSettle, loading indicator should be visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}
