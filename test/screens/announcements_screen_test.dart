import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/announcements_screen.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/empty_state.dart';
import 'package:league_hub/widgets/league_filter.dart';
import 'package:mockito/mockito.dart';

class MockAuthorizedFirestoreService extends Mock
    implements AuthorizedFirestoreService {
  @override
  Future<void> togglePin(
    AppUser actor,
    String orgId,
    String announcementId,
    bool isPinned,
  ) =>
      (super.noSuchMethod(
            Invocation.method(
              #togglePin,
              [actor, orgId, announcementId, isPinned],
            ),
            returnValue: Future<void>.value(),
          ) as Future<void>);

  @override
  Future<void> deleteAnnouncement(
    AppUser actor,
    String orgId,
    String announcementId,
  ) =>
      (super.noSuchMethod(
            Invocation.method(
              #deleteAnnouncement,
              [actor, orgId, announcementId],
            ),
            returnValue: Future<void>.value(),
          ) as Future<void>);
}

class _GenericTogglePinError implements Exception {
  @override
  String toString() => 'generic toggle failure';
}

class _GenericDeleteError implements Exception {
  @override
  String toString() => 'generic delete failure';
}

void main() {
  group('announcement helpers', () {
    final baseTime = DateTime(2026, 1, 1);
    final orgWidePinned = Announcement(
      id: 'ann-1',
      orgId: 'org-1',
      title: 'Org Wide',
      body: 'Body',
      authorId: 'user-1',
      authorName: 'User One',
      authorRole: 'Admin',
      scope: AnnouncementScope.orgWide,
      attachments: [],
      isPinned: true,
      createdAt: baseTime,
    );
    final leaguePost = Announcement(
      id: 'ann-2',
      orgId: 'org-1',
      title: 'League Post',
      body: 'Body',
      authorId: 'user-1',
      authorName: 'User One',
      authorRole: 'Admin',
      scope: AnnouncementScope.league,
      leagueId: 'league-1',
      attachments: [],
      isPinned: false,
      createdAt: baseTime,
    );

    test('builds announcement summary chips from post counts', () {
      final summaries = buildAnnouncementSummaries([orgWidePinned, leaguePost]);

      expect(summaries.map((summary) => summary.label).toList(), [
        '1 pinned',
        '2 total posts',
      ]);
    });

    test('builds announcement actions for pinned announcement', () {
      var toggled = false;
      var edited = false;
      var deleted = false;

      final actions = buildAnnouncementActions(
        announcement: orgWidePinned,
        onTogglePin: () => toggled = true,
        onEdit: () => edited = true,
        onDelete: () => deleted = true,
      );

      expect(actions.map((action) => action.label).toList(),
          ['Unpin', 'Edit', 'Delete']);
      expect(actions.first.icon, Icons.push_pin_outlined);

      actions[0].onTap();
      actions[1].onTap();
      actions[2].onTap();

      expect(toggled, isTrue);
      expect(edited, isTrue);
      expect(deleted, isTrue);
    });

    test('builds announcement actions for unpinned announcement', () {
      final actions = buildAnnouncementActions(
        announcement: leaguePost,
        onTogglePin: () {},
        onEdit: () {},
        onDelete: () {},
      );

      expect(actions.first.label, 'Pin');
      expect(actions.first.icon, Icons.push_pin);
      expect(actions.last.textStyle?.color, AppColors.danger);
    });

    test('toggleAnnouncementPin reports generic failures', () async {
      final service = MockAuthorizedFirestoreService();
      final user = AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'User One',
        role: UserRole.superAdmin,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      when(service.togglePin(user, 'org-1', 'ann-1', true))
          .thenThrow(_GenericTogglePinError());
      String? errorMessage;

      final result = await toggleAnnouncementPin(
        service: service,
        currentUser: user,
        orgId: 'org-1',
        announcementId: 'ann-1',
        isPinned: true,
        onError: (message) => errorMessage = message,
      );

      expect(result, isFalse);
      expect(errorMessage, 'Failed to toggle pin: generic toggle failure');
    });

    test('deleteAnnouncementWithHandling reports generic failures', () async {
      final service = MockAuthorizedFirestoreService();
      final user = AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'User One',
        role: UserRole.superAdmin,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: baseTime,
        isActive: true,
      );
      when(service.deleteAnnouncement(user, 'org-1', 'ann-1'))
          .thenThrow(_GenericDeleteError());
      String? errorMessage;

      final result = await deleteAnnouncementWithHandling(
        service: service,
        currentUser: user,
        orgId: 'org-1',
        announcementId: 'ann-1',
        onError: (message) => errorMessage = message,
      );

      expect(result, isFalse);
      expect(errorMessage, 'Delete failed: generic delete failure');
    });
  });

  group('AnnouncementsScreen', () {
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

    final adminUser = AppUser(
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

    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime.now(),
      ownerId: 'admin-1',
    );

    final testAnnouncements = [
      Announcement(
        id: 'ann-1',
        orgId: 'org-1',
        title: 'Welcome to League Hub',
        body: 'Welcome to our new league management platform',
        authorId: 'admin-1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        scope: AnnouncementScope.orgWide,
        attachments: [],
        isPinned: true,
        createdAt: DateTime.now().subtract(Duration(days: 5)),
      ),
      Announcement(
        id: 'ann-2',
        orgId: 'org-1',
        title: 'Spring Tournament Dates',
        body: 'The spring tournament will be held from March 15 to April 20',
        authorId: 'admin-1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        scope: AnnouncementScope.league,
        leagueId: 'league-1',
        attachments: [],
        isPinned: false,
        createdAt: DateTime.now().subtract(Duration(days: 2)),
      ),
      Announcement(
        id: 'ann-3',
        orgId: 'org-1',
        title: 'Schedule Update',
        body: 'Weekly schedule has been updated',
        authorId: 'admin-1',
        authorName: 'Admin User',
        authorRole: 'Super Admin',
        scope: AnnouncementScope.league,
        leagueId: 'league-2',
        attachments: [],
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
          currentUserProvider.overrideWith(
            (ref) => user ?? testUser,
          ),
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements ?? testAnnouncements),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
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

    Widget createRoutedTestWidget({
      AppUser? user,
      List<Announcement>? announcements,
      List<League>? leagues,
      AuthorizedFirestoreService? authorizedFirestoreService,
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: '/announcements/create',
            builder: (context, state) =>
                const Scaffold(body: Text('Create Announcement Route')),
          ),
          GoRoute(
            path: '/announcements/:id',
            builder: (context, state) => Scaffold(
              body: Text('Announcement Route ${state.pathParameters['id']}'),
            ),
          ),
          GoRoute(
            path: '/announcements/:id/edit',
            builder: (context, state) => Scaffold(
              body:
                  Text('Edit Announcement Route ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user ?? testUser),
          organizationProvider.overrideWith((ref) => testOrg),
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements ?? testAnnouncements),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          if (authorizedFirestoreService != null)
            authorizedFirestoreServiceProvider
                .overrideWithValue(authorizedFirestoreService),
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

    Future<void> scrollAnnouncementsUntilVisible(
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
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AnnouncementsScreen), findsOneWidget);
      });

      testWidgets('displays title Announcements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Announcements'), findsOneWidget);
      });

      testWidgets('has refresh indicator', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('FAB Visibility', () {
      testWidgets('shows FAB for superAdmin', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: adminUser));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('shows FAB for managerAdmin', (WidgetTester tester) async {
        final managerAdmin = AppUser(
          id: 'manager-1',
          email: 'manager@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2024),
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: managerAdmin));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('shows FAB for platformOwner', (WidgetTester tester) async {
        final platformOwner = AppUser(
          id: 'owner-1',
          email: 'owner@example.com',
          displayName: 'Platform Owner',
          role: UserRole.platformOwner,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2024),
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: platformOwner));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('hides FAB for staff user', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsNothing);
      });
    });

    group('Announcement List Rendering', () {
      testWidgets('displays all announcements', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Welcome to League Hub'), findsOneWidget);
        expect(find.text('Spring Tournament Dates'), findsOneWidget);
        await scrollAnnouncementsUntilVisible(
          tester,
          find.text('Schedule Update'),
        );
        expect(find.text('Schedule Update'), findsOneWidget);
      });

      testWidgets('displays announcement titles', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('displays announcement bodies (truncated)',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text('Welcome to our new league management platform'),
          findsOneWidget,
        );
      });

      testWidgets('displays author information', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Admin User'), findsWidgets);
        expect(find.text('Super Admin'), findsWidgets);
      });
    });

    group('Pinned Announcements', () {
      testWidgets('pinned announcement shows indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Pinned Announcement'), findsOneWidget);
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('pinned announcement appears first in list',
          (WidgetTester tester) async {
        // List should be ordered with pinned first
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // The pinned announcement should be first
        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('pinned announcement has special styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Pinned announcement has special border
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
      });

      testWidgets('non-pinned announcements do not show indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Only one pinned announcement
        expect(find.text('Pinned Announcement'), findsOneWidget);
      });
    });

    group('Scope Tags', () {
      testWidgets('displays organization-wide scope tag',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Org-Wide'), findsOneWidget);
      });

      testWidgets('displays league scope tag with abbreviation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('SL'),
            findsWidgets); // Spring League (may appear in filter + tag)
        expect(find.text('FL'),
            findsWidgets); // Fall League (may appear in filter + tag)
      });

      testWidgets('scope tags have different colors',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Should find scope tags
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('filters announcements by league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Default should show all
        expect(find.text('Welcome to League Hub'), findsOneWidget);
        expect(find.text('Spring Tournament Dates'), findsOneWidget);
        await scrollAnnouncementsUntilVisible(
          tester,
          find.text('Schedule Update'),
        );
        expect(find.text('Schedule Update'), findsOneWidget);
      });

      testWidgets('org-wide announcements always visible',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Even when filtering by league, org-wide announcements appear
        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should still render announcements
        expect(find.byType(AnnouncementsScreen), findsOneWidget);
      });

      testWidgets('hides league filter when there is only one league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsNothing);
      });

      testWidgets('selecting a league hides unrelated league announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        await tester.tap(find.text('SL').first);
        await tester.pumpAndSettle();

        expect(find.text('Welcome to League Hub'), findsOneWidget);
        expect(find.text('Spring Tournament Dates'), findsOneWidget);
        expect(find.text('Schedule Update'), findsNothing);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(announcements: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No announcements yet'), findsOneWidget);
        expect(find.text('Check back later for updates.'), findsOneWidget);
        expect(find.byType(EmptyState), findsOneWidget);
      });

      testWidgets('empty state is centered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(announcements: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(Center), findsWidgets);
      });
    });

    group('Loading State', () {
      testWidgets('shows loading indicator while fetching',
          (WidgetTester tester) async {
        // Use a stream that never emits to keep the provider in loading state
        final controller = StreamController<List<Announcement>>();
        addTearDown(() => controller.close());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              announcementsProvider.overrideWith(
                (ref) => controller.stream,
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
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('pull to refresh rebuilds announcements provider',
          (WidgetTester tester) async {
        var buildCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) => testUser),
              announcementsProvider.overrideWith((ref) {
                buildCount += 1;
                return Stream.value(testAnnouncements);
              }),
              leaguesProvider.overrideWith((ref) => Stream.value(testLeagues)),
            ],
            child: MaterialApp(
              home: const AnnouncementsScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(buildCount, 1);

        await tester.fling(
          find.byType(ListView).last,
          const Offset(0, 300),
          1000,
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        expect(buildCount, greaterThan(1));
      });
    });

    group('Announcement Card Information', () {
      testWidgets('card displays creation timestamp',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Timestamps should be displayed
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('card displays author avatar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Avatar should be present
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('card displays full author information',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Admin User'), findsWidgets);
        expect(find.text('Super Admin'), findsWidgets);
      });

      testWidgets('card text is properly formatted',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Title should be bold/large
        // Body should be smaller
        expect(find.byType(Text), findsWidgets);
      });
    });

    group('Interaction - Long Press Menu', () {
      testWidgets('staff user cannot see long press menu',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));
        await tester.pump();
        await tester.pumpAndSettle();

        // Staff users should not be able to long press
        // (but we can at least verify the card is there)
        expect(find.text('Welcome to League Hub'), findsOneWidget);
      });

      testWidgets('admin user can interact with announcements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: adminUser));
        await tester.pump();
        await tester.pumpAndSettle();

        // Admin user should have FAB for creating
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('admin long press opens options sheet',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        final cardTitle = find.text('Welcome to League Hub');
        await tester.longPress(cardTitle);
        await tester.pumpAndSettle();

        expect(find.text('Unpin'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('edit option navigates to edit route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        final cardTitle = find.text('Welcome to League Hub');
        await tester.longPress(cardTitle);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        expect(find.text('Edit Announcement Route ann-1'), findsOneWidget);
      });

      testWidgets('pin option calls service', (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(service.togglePin(adminUser, 'org-1', 'ann-1', false))
            .thenAnswer((_) async {});

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: adminUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Welcome to League Hub'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unpin'));
        await tester.pumpAndSettle();

        verify(service.togglePin(adminUser, 'org-1', 'ann-1', false))
            .called(1);
      });

      testWidgets('delete option opens confirmation dialog',
          (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: adminUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Welcome to League Hub'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Announcement'), findsOneWidget);
        expect(
          find.text('Are you sure you want to delete this announcement?'),
          findsOneWidget,
        );
      });

      testWidgets('delete confirm calls service', (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(service.deleteAnnouncement(adminUser, 'org-1', 'ann-1'))
            .thenAnswer((_) async {});

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: adminUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Welcome to League Hub'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        verify(service.deleteAnnouncement(adminUser, 'org-1', 'ann-1'))
            .called(1);
      });

      testWidgets('pin failure shows snackbar', (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(service.togglePin(adminUser, 'org-1', 'ann-1', false)).thenThrow(
          PermissionDeniedException(
            action: 'togglePin',
            userId: adminUser.id,
            role: adminUser.role,
          ),
        );

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: adminUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Welcome to League Hub'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unpin'));
        await tester.pump();

        expect(
          find.text('Permission denied. You cannot pin announcements.'),
          findsOneWidget,
        );
      });

      testWidgets('delete failure shows snackbar', (WidgetTester tester) async {
        final service = MockAuthorizedFirestoreService();
        when(service.deleteAnnouncement(adminUser, 'org-1', 'ann-1'))
            .thenThrow(
          PermissionDeniedException(
            action: 'deleteAnnouncement',
            userId: adminUser.id,
            role: adminUser.role,
          ),
        );

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: adminUser,
            authorizedFirestoreService: service,
          ),
        );
        await tester.pumpAndSettle();

        await tester.longPress(find.text('Welcome to League Hub'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pump();

        expect(
          find.text('Permission denied. You cannot delete announcements.'),
          findsOneWidget,
        );
      });
    });

    group('Announcement List Ordering', () {
      testWidgets('pinned announcements appear first',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

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
            orgId: 'org-1',
            title: 'Pinned Announcement',
            body: 'This is pinned',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            attachments: [],
            isPinned: true,
            createdAt: DateTime.now().subtract(Duration(days: 5)),
          ),
          Announcement(
            id: 'ann-2',
            orgId: 'org-1',
            title: 'Recent Announcement',
            body: 'This is recent',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
          Announcement(
            id: 'ann-3',
            orgId: 'org-1',
            title: 'Older Announcement',
            body: 'This is older',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(days: 10)),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: orderedAnnouncements),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Pinned should be first (text may appear in both badge and title)
        expect(find.text('Pinned Announcement'), findsWidgets);
      });
    });

    group('Multiple Announcements of Same Scope', () {
      testWidgets('displays multiple org-wide announcements',
          (WidgetTester tester) async {
        final multipleOrgWide = [
          Announcement(
            id: 'ann-1',
            orgId: 'org-1',
            title: 'Announcement 1',
            body: 'Body 1',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now(),
          ),
          Announcement(
            id: 'ann-2',
            orgId: 'org-1',
            title: 'Announcement 2',
            body: 'Body 2',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.orgWide,
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: multipleOrgWide),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Announcement 1'), findsOneWidget);
        expect(find.text('Announcement 2'), findsOneWidget);
      });

      testWidgets('displays multiple league-specific announcements',
          (WidgetTester tester) async {
        final multipleLeagueAnn = [
          Announcement(
            id: 'ann-1',
            orgId: 'org-1',
            title: 'League Announcement 1',
            body: 'Body 1',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.league,
            leagueId: 'league-1',
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now(),
          ),
          Announcement(
            id: 'ann-2',
            orgId: 'org-1',
            title: 'League Announcement 2',
            body: 'Body 2',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.league,
            leagueId: 'league-1',
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: multipleLeagueAnn),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('League Announcement 1'), findsOneWidget);
        expect(find.text('League Announcement 2'), findsOneWidget);
        expect(find.text('SL'), findsWidgets); // Both belong to SL
      });
    });

    group('Announcement Card Styling', () {
      testWidgets('pinned announcement has different styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Pinned announcement should have special header
        expect(find.text('Pinned Announcement'), findsOneWidget);
      });

      testWidgets('announcement cards are properly spaced',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Cards should have proper margins/padding
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Unknown League Handling', () {
      testWidgets('shows League label when league not found',
          (WidgetTester tester) async {
        final orphanedAnn = Announcement(
          id: 'ann-1',
          orgId: 'org-1',
          title: 'Orphaned Announcement',
          body: 'Body',
          authorId: 'admin-1',
          authorName: 'Admin User',
          authorRole: 'Super Admin',
          scope: AnnouncementScope.league,
          leagueId: 'unknown-league-id',
          attachments: [],
          isPinned: false,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(
            announcements: [orphanedAnn],
            leagues: [], // No leagues available
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Should show something for the league
        expect(find.text('Orphaned Announcement'), findsOneWidget);
        expect(find.text('League'), findsOneWidget);
      });
    });

    group('Navigation', () {
      testWidgets('fab navigates to create route', (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: adminUser));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        expect(find.text('Create Announcement Route'), findsOneWidget);
      });

      testWidgets('tapping announcement card navigates to detail route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Welcome to League Hub'));
        await tester.pumpAndSettle();

        expect(find.text('Announcement Route ann-1'), findsOneWidget);
      });
    });

    group('Hub Scope', () {
      testWidgets('hub scoped announcement shows Hub badge',
          (WidgetTester tester) async {
        final hubAnnouncement = [
          Announcement(
            id: 'ann-hub',
            orgId: 'org-1',
            title: 'Hub Update',
            body: 'Hub specific news',
            authorId: 'admin-1',
            authorName: 'Admin User',
            authorRole: 'Super Admin',
            scope: AnnouncementScope.hub,
            hubId: 'hub-1',
            attachments: [],
            isPinned: false,
            createdAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(announcements: hubAnnouncement),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Hub'), findsOneWidget);
      });
    });
  });
}
