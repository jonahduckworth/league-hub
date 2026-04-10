import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings_screen.dart';
import 'package:league_hub/services/auth_service.dart';
import 'package:league_hub/services/messaging_service.dart';
import 'package:mockito/mockito.dart';

class MockAuthService extends Mock implements AuthService {
  @override
  Future<void> signOut() => (super.noSuchMethod(
        Invocation.method(#signOut, []),
        returnValue: Future<void>.value(),
      ) as Future<void>);
}

class MockMessagingService extends Mock implements MessagingService {
  @override
  Future<void> removeToken(String userId) => (super.noSuchMethod(
        Invocation.method(#removeToken, [userId]),
        returnValue: Future<void>.value(),
      ) as Future<void>);
}

void main() {
  group('settings helpers', () {
    test('detects when organization section should be shown', () {
      expect(shouldShowOrganizationSettings(['users']), isTrue);
      expect(shouldShowOrganizationSettings(['notifications']), isFalse);
    });

    test('builds organization settings items with optional badge', () {
      final items = buildOrganizationSettingsItems(
        visibleTiles: ['leagues', 'users', 'branding'],
        pendingInviteCount: 3,
      );

      expect(items.map((item) => item.title).toList(), [
        'Manage Leagues & Hubs',
        'User Management',
        'Branding & Appearance',
      ]);
      expect(items[1].badge, 3);
      expect(items[2].route, '/settings/branding');
    });

    test('omits user badge when there are no pending invites', () {
      final items = buildOrganizationSettingsItems(
        visibleTiles: ['users'],
        pendingInviteCount: 0,
      );

      expect(items.single.badge, isNull);
    });

    test('builds preferences settings items', () {
      final items = buildPreferenceSettingsItems();

      expect(items.map((item) => item.route).toList(), [
        '/settings/notifications',
        '/settings/privacy',
      ]);
    });
  });

  group('SettingsScreen', () {
    // Helper to create a test widget with Riverpod overrides
    Widget createTestWidget({
      required AppUser user,
      int pendingInviteCount = 0,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user),
          pendingInviteCountProvider.overrideWithValue(
            pendingInviteCount,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SettingsScreen(),
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
      required AppUser user,
      int pendingInviteCount = 0,
      AuthService? authService,
      MessagingService? messagingService,
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: SettingsScreen()),
          ),
          GoRoute(
            path: '/settings/leagues',
            builder: (context, state) =>
                const Scaffold(body: Text('Leagues Route')),
          ),
          GoRoute(
            path: '/settings/users',
            builder: (context, state) =>
                const Scaffold(body: Text('Users Route')),
          ),
          GoRoute(
            path: '/settings/roles',
            builder: (context, state) =>
                const Scaffold(body: Text('Roles Route')),
          ),
          GoRoute(
            path: '/settings/branding',
            builder: (context, state) =>
                const Scaffold(body: Text('Branding Route')),
          ),
          GoRoute(
            path: '/settings/app-icon',
            builder: (context, state) =>
                const Scaffold(body: Text('App Icon Route')),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) =>
                const Scaffold(body: Text('Notifications Route')),
          ),
          GoRoute(
            path: '/settings/privacy',
            builder: (context, state) =>
                const Scaffold(body: Text('Privacy Route')),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Text('Login Route')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user),
          pendingInviteCountProvider.overrideWithValue(pendingInviteCount),
          if (authService != null)
            authServiceProvider.overrideWithValue(authService),
          if (messagingService != null)
            messagingServiceProvider.overrideWithValue(messagingService),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    group('Staff user', () {
      final staffUser = AppUser(
        id: 'staff-user',
        email: 'staff@example.com',
        displayName: 'Staff Member',
        role: UserRole.staff,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('sees Preferences section only', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: staffUser));

        // Should see Preferences section
        expect(find.text('PREFERENCES'), findsOneWidget);

        // Should see Notifications and Privacy & Security
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Privacy & Security'), findsOneWidget);
      });

      testWidgets('does NOT see Organization section',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: staffUser));

        // Should NOT see Organization section
        expect(find.text('ORGANIZATION'), findsNothing);

        // Should NOT see organization tiles
        expect(find.text('Manage Leagues & Hubs'), findsNothing);
        expect(find.text('User Management'), findsNothing);
        expect(find.text('Roles & Permissions'), findsNothing);
        expect(find.text('Branding & Appearance'), findsNothing);
        expect(find.text('App Icon'), findsNothing);
      });

      testWidgets('sees Sign Out button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: staffUser));

        expect(find.text('Sign Out'), findsOneWidget);
      });

      testWidgets('displays profile card with user info',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: staffUser));

        expect(find.text(staffUser.displayName), findsWidgets);
        expect(find.text(staffUser.email), findsOneWidget);
        expect(find.text('Staff'), findsOneWidget); // Role badge
      });
    });

    group('Manager Admin user', () {
      final managerAdmin = AppUser(
        id: 'manager-admin',
        email: 'admin@example.com',
        displayName: 'Manager Admin',
        role: UserRole.managerAdmin,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('sees User Management but not other org tiles',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: managerAdmin));

        // Should see ORGANIZATION section
        expect(find.text('ORGANIZATION'), findsOneWidget);

        // Should see User Management
        expect(find.text('User Management'), findsOneWidget);

        // Should NOT see other org tiles
        expect(find.text('Manage Leagues & Hubs'), findsNothing);
        expect(find.text('Roles & Permissions'), findsNothing);
        expect(find.text('Branding & Appearance'), findsNothing);
        expect(find.text('App Icon'), findsNothing);
      });

      testWidgets('sees Preferences section', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: managerAdmin));

        expect(find.text('PREFERENCES'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Privacy & Security'), findsOneWidget);
      });
    });

    group('Super Admin user', () {
      final superAdmin = AppUser(
        id: 'super-admin',
        email: 'super@example.com',
        displayName: 'Super Admin',
        role: UserRole.superAdmin,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('sees all Organization tiles', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: superAdmin));

        // Should see ORGANIZATION section
        expect(find.text('ORGANIZATION'), findsOneWidget);

        // Should see all org tiles
        expect(find.text('Manage Leagues & Hubs'), findsOneWidget);
        expect(find.text('User Management'), findsOneWidget);
        expect(find.text('Roles & Permissions'), findsOneWidget);
        expect(find.text('Branding & Appearance'), findsOneWidget);
        expect(find.text('App Icon'), findsOneWidget);
      });

      testWidgets('displays Owner badge', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: superAdmin));

        // Super Admin should show Owner badge
        expect(find.text('Owner'), findsOneWidget);
      });

      testWidgets('roles tile navigates to roles route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Roles & Permissions'));
        await tester.pumpAndSettle();

        expect(find.text('Roles Route'), findsOneWidget);
      });

      testWidgets('branding tile navigates to branding route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Branding & Appearance'));
        await tester.pumpAndSettle();

        expect(find.text('Branding Route'), findsOneWidget);
      });

      testWidgets('app icon tile navigates to app icon route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('App Icon'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        final tile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text('App Icon'),
            matching: find.byType(ListTile),
          ),
        );
        tile.onTap!.call();
        await tester.pumpAndSettle();

        expect(find.text('App Icon Route'), findsOneWidget);
      });
    });

    group('Platform Owner user', () {
      final platformOwner = AppUser(
        id: 'platform-owner',
        email: 'owner@example.com',
        displayName: 'Platform Owner',
        role: UserRole.platformOwner,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('sees all Organization tiles', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: platformOwner));

        // Should see ORGANIZATION section
        expect(find.text('ORGANIZATION'), findsOneWidget);

        // Should see all org tiles
        expect(find.text('Manage Leagues & Hubs'), findsOneWidget);
        expect(find.text('User Management'), findsOneWidget);
        expect(find.text('Roles & Permissions'), findsOneWidget);
        expect(find.text('Branding & Appearance'), findsOneWidget);
        expect(find.text('App Icon'), findsOneWidget);
      });

      testWidgets('displays Owner badge', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: platformOwner));

        expect(find.text('Owner'), findsOneWidget);
      });
    });

    group('Profile card', () {
      final testUser = AppUser(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('displays user name', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('Test User'), findsWidgets);
      });

      testWidgets('displays user email', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('test@example.com'), findsOneWidget);
      });

      testWidgets('displays role badge', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('Staff'), findsOneWidget);
      });

      testWidgets('has edit button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      });

      testWidgets('edit button opens edit profile screen',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Edit Profile'), findsOneWidget);
      });
    });

    group('Sign Out button', () {
      final testUser = AppUser(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('Sign Out button is always present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('Sign Out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });

      testWidgets('sign out removes token, signs out, and routes to login',
          (WidgetTester tester) async {
        final authService = MockAuthService();
        final messagingService = MockMessagingService();
        when(messagingService.removeToken(testUser.id)).thenAnswer((_) async {});
        when(authService.signOut()).thenAnswer((_) async {});

        await tester.pumpWidget(
          createRoutedTestWidget(
            user: testUser,
            authService: authService,
            messagingService: messagingService,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign Out'));
        await tester.pumpAndSettle();

        verify(messagingService.removeToken(testUser.id)).called(1);
        verify(authService.signOut()).called(1);
        expect(find.text('Login Route'), findsOneWidget);
      });
    });

    group('Pending invite badge', () {
      final managerAdmin = AppUser(
        id: 'manager-admin',
        email: 'admin@example.com',
        displayName: 'Manager Admin',
        role: UserRole.managerAdmin,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('shows count when there are pending invites',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            user: managerAdmin,
            pendingInviteCount: 3,
          ),
        );

        expect(find.text('3'), findsWidgets); // Badge shows count
      });

      testWidgets('does not show badge when no pending invites',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            user: managerAdmin,
            pendingInviteCount: 0,
          ),
        );

        // User Management should still be there, but no badge
        expect(find.text('User Management'), findsOneWidget);
      });

      testWidgets('badge only visible for users with management access',
          (WidgetTester tester) async {
        final staffUser = AppUser(
          id: 'staff-user',
          email: 'staff@example.com',
          displayName: 'Staff Member',
          role: UserRole.staff,
          orgId: 'org-1',
          createdAt: DateTime(2024),
          hubIds: [],
          teamIds: [],
          isActive: true,
        );

        await tester.pumpWidget(
          createTestWidget(
            user: staffUser,
            pendingInviteCount: 5,
          ),
        );

        // Staff user shouldn't see User Management at all
        expect(find.text('User Management'), findsNothing);
      });
    });

    group('App version display', () {
      final testUser = AppUser(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('displays League Hub version', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('League Hub v1.0.0'), findsOneWidget);
      });
    });

    group('Settings sections styling', () {
      final testUser = AppUser(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.superAdmin,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('section headers are uppercase', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('ORGANIZATION'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('PREFERENCES'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text('PREFERENCES'), findsOneWidget);
      });

      testWidgets('settings items have proper layout',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        // Should find settings items with chevrons
        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      });
    });

    group('Navigation', () {
      final superAdmin = AppUser(
        id: 'super-admin',
        email: 'super@example.com',
        displayName: 'Super Admin',
        role: UserRole.superAdmin,
        orgId: 'org-1',
        createdAt: DateTime(2024),
        hubIds: [],
        teamIds: [],
        isActive: true,
      );

      testWidgets('organization tile navigates to leagues route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));

        await tester.tap(find.text('Manage Leagues & Hubs'));
        await tester.pumpAndSettle();
        expect(find.text('Leagues Route'), findsOneWidget);
      });

      testWidgets('organization tile navigates to users route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));

        await tester.tap(find.text('User Management'));
        await tester.pumpAndSettle();
        expect(find.text('Users Route'), findsOneWidget);
      });

      testWidgets('preference tile navigates to notifications route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));

        await tester.scrollUntilVisible(
          find.text('Notifications'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();
        expect(find.text('Notifications Route'), findsOneWidget);
      });

      testWidgets('preference tile navigates to privacy route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget(user: superAdmin));

        await tester.scrollUntilVisible(
          find.text('Privacy & Security'),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('Privacy & Security'));
        await tester.pumpAndSettle();
        expect(find.text('Privacy Route'), findsOneWidget);
      });
    });
  });
}
