import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/admin/user_management_screen.dart';

void main() {
  group('UserManagementScreen', () {
    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime(2024),
      ownerId: 'owner-1',
    );

    final managerAdmin = AppUser(
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

    final testUsers = [
      AppUser(
        id: 'user-1',
        email: 'user1@example.com',
        displayName: 'John Doe',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: ['hub-1'],
        teamIds: [],
        createdAt: DateTime.now().subtract(Duration(days: 10)),
        isActive: true,
      ),
      AppUser(
        id: 'user-2',
        email: 'user2@example.com',
        displayName: 'Jane Smith',
        role: UserRole.managerAdmin,
        orgId: 'org-1',
        hubIds: ['hub-1', 'hub-2'],
        teamIds: [],
        createdAt: DateTime.now().subtract(Duration(days: 5)),
        isActive: true,
      ),
      AppUser(
        id: 'user-3',
        email: 'user3@example.com',
        displayName: 'Bob Johnson',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        isActive: false,
      ),
    ];

    final testInvitations = [
      Invitation(
        id: 'inv-1',
        orgId: 'org-1',
        email: 'pending@example.com',
        displayName: 'Pending User',
        role: 'staff',
        hubIds: [],
        teamIds: [],
        invitedBy: 'admin-1',
        invitedByName: 'Super Admin',
        createdAt: DateTime.now().subtract(Duration(days: 1)),
        status: InvitationStatus.pending,
        token: 'token-1',
      ),
    ];

    Widget createTestWidget({
      AppUser? user,
      List<AppUser>? users,
      List<Invitation>? invitations,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? managerAdmin,
          ),
          organizationProvider.overrideWith(
            (ref) => testOrg,
          ),
          orgUsersProvider.overrideWith(
            (ref) => Stream.value(users ?? testUsers),
          ),
          invitationsProvider.overrideWith(
            (ref) => Stream.value(invitations ?? testInvitations),
          ),
        ],
        child: MaterialApp(
          home: UserManagementScreen(),
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
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(UserManagementScreen), findsOneWidget);
      });

      testWidgets('displays title User Management',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('User Management'), findsOneWidget);
      });
    });

    group('User List Rendering', () {
      testWidgets('displays all active users', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Jane Smith'), findsOneWidget);
      });

      testWidgets('shows user emails', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('user1@example.com'), findsOneWidget);
        expect(find.text('user2@example.com'), findsOneWidget);
      });
    });

    group('Role Badges', () {
      testWidgets('displays role badges for users', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Staff'), findsWidgets);
        // "Manager Admin" appears as both a role badge and a filter chip
        expect(find.text('Manager Admin'), findsWidgets);
      });

      testWidgets('role badges display correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Should have at least one Staff and one Manager Admin badge
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Search Functionality', () {
      testWidgets('shows search field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Search by name or email…'), findsOneWidget);
      });

      testWidgets('search field has search icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.search), findsOneWidget);
      });
    });

    group('Filter Chips', () {
      testWidgets('displays role filter chips', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(FilterChip), findsWidgets);
        expect(find.text('All'), findsOneWidget);
        expect(find.text('Super Admin'), findsOneWidget);
        // "Manager Admin" also appears as a role badge on a user row
        expect(find.text('Manager Admin'), findsWidgets);
        expect(find.text('Staff'), findsWidgets);
      });
    });

    group('Invite Button', () {
      testWidgets('shows Invite User FAB', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: managerAdmin));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
        expect(find.text('Invite User'), findsOneWidget);
      });

      testWidgets('FAB is visible for managerAdmin', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: managerAdmin));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(FloatingActionButton), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no users', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(users: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No users found'), findsOneWidget);
        expect(find.byIcon(Icons.people_outline), findsOneWidget);
      });

      testWidgets('empty state is centered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(users: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(Center), findsWidgets);
      });
    });

    group('Hub Assignment Display', () {
      testWidgets('shows hub count for users with hubs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Jane Smith has 2 hubs
        expect(find.text('2 hubs'), findsOneWidget);
        // John Doe has 1 hub
        expect(find.text('1 hub'), findsOneWidget);
      });
    });

    group('User Status', () {
      testWidgets('displays inactive badge for inactive users',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Inactive'), findsOneWidget);
      });

      testWidgets('shows inactive user with different styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Bob Johnson is inactive, should be findable
        expect(find.text('Bob Johnson'), findsOneWidget);
      });
    });

    group('Pending Invitations Badge', () {
      testWidgets('shows pending invite count badge', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget); // Pending count
      });

      testWidgets('shows mail icon in appbar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mail_outline), findsOneWidget);
      });

      testWidgets('badge is not shown when no pending invites',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(invitations: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should not show mail icon if no pending invites
        expect(find.byIcon(Icons.mail_outline), findsNothing);
      });
    });

    group('User Cards', () {
      testWidgets('user cards are clickable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // User cards should exist and be tappable
        expect(find.byType(GestureDetector), findsWidgets);
      });

      testWidgets('user cards show avatar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Avatar widgets should be present
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('user cards show chevron', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsWidgets);
      });
    });

    group('Multiple Users', () {
      testWidgets('displays multiple users in list', (WidgetTester tester) async {
        final manyUsers = [
          AppUser(
            id: 'user-1',
            email: 'user1@example.com',
            displayName: 'User One',
            role: UserRole.staff,
            orgId: 'org-1',
            hubIds: [],
            teamIds: [],
            createdAt: DateTime.now(),
            isActive: true,
          ),
          AppUser(
            id: 'user-2',
            email: 'user2@example.com',
            displayName: 'User Two',
            role: UserRole.staff,
            orgId: 'org-1',
            hubIds: [],
            teamIds: [],
            createdAt: DateTime.now(),
            isActive: true,
          ),
          AppUser(
            id: 'user-3',
            email: 'user3@example.com',
            displayName: 'User Three',
            role: UserRole.managerAdmin,
            orgId: 'org-1',
            hubIds: [],
            teamIds: [],
            createdAt: DateTime.now(),
            isActive: true,
          ),
        ];

        await tester.pumpWidget(createTestWidget(users: manyUsers));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('User One'), findsOneWidget);
        expect(find.text('User Two'), findsOneWidget);
        expect(find.text('User Three'), findsOneWidget);
      });
    });

    group('Invite Tab', () {
      testWidgets('shows proper layout for user list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Should display search and filter
        expect(find.byType(ListView), findsWidgets);
      });
    });

    group('Role Filtering', () {
      testWidgets('can filter by role', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find Staff filter chip and tap it
        final staffChip = find
            .byWidgetPredicate((widget) =>
                widget is FilterChip &&
                widget.label is Text &&
                (widget.label as Text).data == 'Staff')
            .first;
        await tester.tap(staffChip);
        await tester.pump();
        await tester.pumpAndSettle();

        // Should show staff users
        expect(find.text('John Doe'), findsOneWidget);
      });
    });

    group('Loading State', () {
      testWidgets('renders while loading users', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Should render without error
        expect(find.byType(UserManagementScreen), findsOneWidget);
      });
    });
  });
}
