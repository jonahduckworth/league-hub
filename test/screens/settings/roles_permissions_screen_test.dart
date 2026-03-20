import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/roles_permissions_screen.dart';

List<AppUser> _testUsers() => [
      AppUser(id: 'u1', email: 'owner@test.com', displayName: 'Owner', role: UserRole.platformOwner, orgId: 'org-1', hubIds: [], teamIds: [], createdAt: DateTime(2025, 1, 1), isActive: true),
      AppUser(id: 'u2', email: 'admin@test.com', displayName: 'Admin', role: UserRole.superAdmin, orgId: 'org-1', hubIds: [], teamIds: [], createdAt: DateTime(2025, 1, 1), isActive: true),
      AppUser(id: 'u3', email: 'manager@test.com', displayName: 'Manager', role: UserRole.managerAdmin, orgId: 'org-1', hubIds: [], teamIds: [], createdAt: DateTime(2025, 1, 1), isActive: true),
      AppUser(id: 'u4', email: 'staff1@test.com', displayName: 'Staff 1', role: UserRole.staff, orgId: 'org-1', hubIds: [], teamIds: [], createdAt: DateTime(2025, 1, 1), isActive: true),
      AppUser(id: 'u5', email: 'staff2@test.com', displayName: 'Staff 2', role: UserRole.staff, orgId: 'org-1', hubIds: [], teamIds: [], createdAt: DateTime(2025, 1, 1), isActive: true),
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
    testWidgets('renders all 4 role cards', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Roles & Permissions'), findsOneWidget);
      expect(find.text('Platform Owner'), findsOneWidget);
      expect(find.text('Super Admin'), findsOneWidget);
      expect(find.text('Manager Admin'), findsOneWidget);
      expect(find.text('Staff'), findsOneWidget);
    });

    testWidgets('shows correct member counts per role', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('1 member'), findsNWidgets(3)); // owner, superAdmin, manager each 1
      expect(find.text('2 members'), findsOneWidget); // 2 staff
    });

    testWidgets('expanding a role card shows permissions', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap Platform Owner to expand
      await tester.tap(find.text('Platform Owner'));
      await tester.pumpAndSettle();

      expect(find.text('Permissions'), findsOneWidget);
      expect(find.text('Manage organization settings'), findsOneWidget);
      expect(find.text('Delete organization'), findsOneWidget);
    });

    testWidgets('renders role descriptions', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(_testUsers())),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('Full access to all organization settings'),
          findsOneWidget);
    });

    testWidgets('renders with empty user list', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value(<AppUser>[])),
        ],
      ));
      await tester.pumpAndSettle();

      // All should show 0 members
      expect(find.text('0 members'), findsNWidgets(4));
    });
  });
}
