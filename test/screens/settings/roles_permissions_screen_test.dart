import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/roles_permissions_screen.dart';

List<AppUser> _testUsers() => [
      AppUser(
          id: 'u1',
          email: 'owner@test.com',
          displayName: 'Owner',
          role: UserRole.platformOwner,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2025, 1, 1),
          isActive: true),
      AppUser(
          id: 'u2',
          email: 'admin@test.com',
          displayName: 'Admin',
          role: UserRole.superAdmin,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2025, 1, 1),
          isActive: true),
      AppUser(
          id: 'u3',
          email: 'manager@test.com',
          displayName: 'Manager',
          role: UserRole.managerAdmin,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2025, 1, 1),
          isActive: true),
      AppUser(
          id: 'u4',
          email: 'staff1@test.com',
          displayName: 'Staff 1',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2025, 1, 1),
          isActive: true),
      AppUser(
          id: 'u5',
          email: 'staff2@test.com',
          displayName: 'Staff 2',
          role: UserRole.staff,
          orgId: 'org-1',
          hubIds: [],
          teamIds: [],
          createdAt: DateTime(2025, 1, 1),
          isActive: true),
    ];

Widget _buildTestWidget({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: RolesPermissionsScreen(),
    ),
  );
}

void main() {
  group('RolesPermissionsScreen', () {
    testWidgets('renders assignable role cards', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Roles & Permissions'), findsOneWidget);
      expect(find.text('Platform Owner'), findsNothing);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Manager'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
      expect(find.textContaining('Ownership-level access'), findsNothing);
    });

    testWidgets('shows correct member counts per role', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 member'), findsNWidgets(2)); // admin and manager
      expect(find.text('2 members'), findsOneWidget); // 2 staff
    });

    testWidgets('expanding a role card shows permissions', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Admin'));
      await tester.pumpAndSettle();

      expect(find.text('PERMISSIONS'), findsOneWidget);
      expect(find.text('Manage leagues, hubs, and teams'), findsOneWidget);
      expect(find.text('All Manager permissions'), findsOneWidget);
    });

    testWidgets('renders role descriptions', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Manage leagues, hubs, teams'), findsOneWidget);
    });

    testWidgets('renders with empty user list', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('0 members'), findsNWidgets(3));
    });
  });
}
