import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/app_icon_screen.dart';
import 'package:league_hub/services/firestore_service.dart';

AppUser _adminUser() => AppUser(
      id: 'u1',
      email: 'admin@test.com',
      displayName: 'Admin',
      role: UserRole.platformOwner,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

AppUser _staffUser() => AppUser(
      id: 'u2',
      email: 'staff@test.com',
      displayName: 'Staff',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

Organization _testOrg() => Organization(
      id: 'org-1',
      name: 'Test League',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime(2025, 1, 1),
      ownerId: 'u1',
    );

Widget _buildTestWidget({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: AppIconScreen(),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('AppIconScreen', () {
    testWidgets('renders app icon selection grid', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => _testOrg()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('App Icon'), findsOneWidget);
      expect(find.text('Default'), findsAtLeastNWidgets(1));
      expect(find.text('Soccer'), findsOneWidget);
      expect(find.text('Basketball'), findsOneWidget);
    });

    testWidgets('shows Save button for admin users', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => _testOrg()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('hides Save button for staff users', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _staffUser()),
          organizationProvider.overrideWith((ref) async => _testOrg()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsNothing);
    });

    testWidgets('default icon shows correct description', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => _testOrg()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('The standard League Hub icon'), findsOneWidget);
    });

    testWidgets('tapping a different icon updates preview', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => _testOrg()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // Tap Soccer icon in the grid
      await tester.tap(find.text('Soccer').last);
      await tester.pumpAndSettle();

      expect(find.text('Soccer ball icon'), findsOneWidget);
    });

    testWidgets('renders 8 icon options', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => _testOrg()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // Count the icon names - there are 8 icons
      expect(find.text('Football'), findsOneWidget);
      expect(find.text('Baseball'), findsOneWidget);
      expect(find.text('Hockey'), findsOneWidget);
      expect(find.text('Tennis'), findsOneWidget);
      expect(find.text('Trophy'), findsOneWidget);
    });
  });
}
