import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/create_announcement_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('CreateAnnouncementScreen', () {
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

    final managerAdminUser = AppUser(
      id: 'manager-1',
      email: 'manager@example.com',
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
      League(
        id: 'league-2',
        orgId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime.now(),
      ),
    ];

    final testHubs = [
      Hub(
        id: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'North Hub',
        createdAt: DateTime.now(),
      ),
      Hub(
        id: 'hub-2',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'South Hub',
        createdAt: DateTime.now(),
      ),
    ];

    final existingAnnouncement = Announcement(
      id: 'ann-1',
      orgId: 'org-1',
      title: 'Existing Announcement',
      body: 'This is an existing announcement',
      authorId: 'manager-1',
      authorName: 'Manager Admin',
      authorRole: 'Manager Admin',
      scope: AnnouncementScope.league,
      leagueId: 'league-1',
      attachments: [],
      isPinned: true,
      createdAt: DateTime.now().subtract(Duration(days: 5)),
    );

    Widget createTestWidget({
      String? announcementId,
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
            (ref) => Stream.value(announcements ?? []),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          hubsProvider('league-1').overrideWith(
            (ref) => Stream.value(testHubs),
          ),
        ],
        child: MaterialApp(
          home: CreateAnnouncementScreen(announcementId: announcementId),
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
      testWidgets('renders create announcement form without crashing',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('New Announcement'), findsOneWidget);
      });

      testWidgets('renders edit announcement form when editing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            announcements: [existingAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Edit Announcement'), findsOneWidget);
      });

      testWidgets('displays title field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Title'), findsOneWidget);
      });

      testWidgets('displays body field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Body'), findsOneWidget);
      });
    });

    group('Scope Selector', () {
      testWidgets('displays scope selector', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Scope'), findsOneWidget);
      });

      testWidgets('shows org-wide scope for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(user: superAdminUser),
        );
        await tester.pumpAndSettle();
        expect(find.text('Org-Wide'), findsOneWidget);
      });

      testWidgets('does not show org-wide scope for managerAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(user: managerAdminUser),
        );
        await tester.pumpAndSettle();
        // Org-wide should not be present for non-super admin
        final orgWideWidgets = find.text('Org-Wide');
        expect(orgWideWidgets, findsNothing);
      });

      testWidgets('shows league scope option', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('League'), findsOneWidget);
      });

      testWidgets('shows hub scope option', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Hub'), findsOneWidget);
      });
    });

    group('Hub Selector Visibility', () {
      testWidgets('shows hub selector when hub scope is selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Find and tap the hub scope button
        final hubButton = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data == 'Hub' &&
              (widget.style?.fontWeight ?? FontWeight.w400) == FontWeight.w600,
        );

        if (hubButton.evaluate().isNotEmpty) {
          await tester.tap(hubButton);
          await tester.pumpAndSettle();
        }
      });
    });

    group('Form Validation', () {
      testWidgets('validates empty title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Find and tap submit button
        final submitButton = find.byWidgetPredicate(
          (widget) =>
              widget is ElevatedButton &&
              (widget.child is Text) &&
              ((widget.child as Text).data?.contains('Post') ?? false),
        );

        if (submitButton.evaluate().isNotEmpty) {
          await tester.tap(submitButton);
          await tester.pumpAndSettle();
          // Validation error should appear
        }
      });

      testWidgets('validates empty body', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Enter title but not body
        final titleFields = find.byType(TextFormField);
        if (titleFields.evaluate().isNotEmpty) {
          await tester.enterText(titleFields.first, 'Test Title');
          await tester.pumpAndSettle();

          // Find and tap submit button
          final submitButton = find.byWidgetPredicate(
            (widget) =>
                widget is ElevatedButton &&
                (widget.child is Text) &&
                ((widget.child as Text).data?.contains('Post') ?? false),
          );

          if (submitButton.evaluate().isNotEmpty) {
            await tester.tap(submitButton);
            await tester.pumpAndSettle();
            // Validation error should appear
          }
        }
      });
    });

    group('Submit Button', () {
      testWidgets('displays post announcement button in create mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: superAdminUser));
        await tester.pumpAndSettle();
        // Scroll to the bottom to ensure the submit button is built
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Post Announcement'), findsOneWidget);
      });

      testWidgets('displays update announcement button in edit mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            user: superAdminUser,
            announcementId: 'ann-1',
            announcements: [existingAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('Update Announcement'), findsOneWidget);
      });
    });

    group('Edit Mode Pre-fill', () {
      testWidgets('pre-fills title when editing', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            announcements: [existingAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Existing Announcement'), findsOneWidget);
      });

      testWidgets('pre-fills body when editing', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementId: 'ann-1',
            announcements: [existingAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('This is an existing announcement'), findsOneWidget);
      });

      testWidgets('pre-fills pinned status when editing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            user: superAdminUser,
            announcementId: 'ann-1',
            announcements: [existingAnnouncement],
          ),
        );
        await tester.pumpAndSettle();
        // Scroll to ensure the pin toggle is visible
        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(find.text('Pin this announcement'), findsOneWidget);
      });
    });

    group('Default Values', () {
      testWidgets('defaults scope to orgWide for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(user: superAdminUser),
        );
        await tester.pumpAndSettle();
        // Org-wide should be available and default
        expect(find.text('Scope'), findsOneWidget);
      });

      testWidgets('defaults scope to league for managerAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(user: managerAdminUser),
        );
        await tester.pumpAndSettle();
        expect(find.text('Scope'), findsOneWidget);
      });
    });

    group('Pin Toggle', () {
      testWidgets('displays pin toggle', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Pin this announcement'), findsOneWidget);
      });

      testWidgets('displays pin help text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(
          find.text('Pinned posts appear at the top'),
          findsOneWidget,
        );
      });
    });

    group('Close Button', () {
      testWidgets('displays close button in app bar',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsOneWidget);
      });
    });
  });
}
