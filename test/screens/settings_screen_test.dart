import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('SettingsScreen', () {
    // Helper to create a test widget with Riverpod overrides
    Widget createTestWidget({
      required AppUser user,
      int pendingInviteCount = 0,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.override((ref) => AsyncValue.data(user)),
          pendingInviteCountProvider.override(
            (ref) => AsyncValue.data(pendingInviteCount),
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

    group('Staff user', () {
      final staffUser = AppUser(
        id: 'staff-user',
        email: 'staff@example.com',
        displayName: 'Staff Member',
        role: UserRole.staff,
        organizationId: 'org-1',
        isActive: true,
      );

      testWidgets('sees Preferences section only',
          (WidgetTester tester) async {
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
        organizationId: 'org-1',
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
        organizationId: 'org-1',
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
    });

    group('Platform Owner user', () {
      final platformOwner = AppUser(
        id: 'platform-owner',
        email: 'owner@example.com',
        displayName: 'Platform Owner',
        role: UserRole.platformOwner,
        organizationId: 'org-1',
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
        organizationId: 'org-1',
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
    });

    group('Sign Out button', () {
      final testUser = AppUser(
        id: 'test-user',
        email: 'test@example.com',
        displayName: 'Test User',
        role: UserRole.staff,
        organizationId: 'org-1',
        isActive: true,
      );

      testWidgets('Sign Out button is always present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('Sign Out'), findsOneWidget);
        expect(find.byIcon(Icons.logout), findsOneWidget);
      });
    });

    group('Pending invite badge', () {
      final managerAdmin = AppUser(
        id: 'manager-admin',
        email: 'admin@example.com',
        displayName: 'Manager Admin',
        role: UserRole.managerAdmin,
        organizationId: 'org-1',
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
          organizationId: 'org-1',
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
        organizationId: 'org-1',
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
        organizationId: 'org-1',
        isActive: true,
      );

      testWidgets('section headers are uppercase', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        expect(find.text('ORGANIZATION'), findsOneWidget);
        expect(find.text('PREFERENCES'), findsOneWidget);
      });

      testWidgets('settings items have proper layout',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));

        // Should find settings items with chevrons
        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      });
    });
  });
}
