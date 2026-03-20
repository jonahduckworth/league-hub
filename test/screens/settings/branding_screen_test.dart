import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/branding_screen.dart';
import 'package:league_hub/services/firestore_service.dart';

Organization _testOrg() => Organization(
      id: 'org-1',
      name: 'Test League',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime(2025, 1, 1),
      ownerId: 'u1',
    );

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

Widget _buildTestWidget({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: BrandingScreen(),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('BrandingScreen', () {
    testWidgets('renders branding form with org data', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          organizationProvider.overrideWith((ref) async => _testOrg()),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Branding & Appearance'), findsOneWidget);
      expect(find.text('ORGANIZATION NAME'), findsOneWidget);
      expect(find.text('BRAND COLORS'), findsOneWidget);
      expect(find.text('PREVIEW'), findsOneWidget);
    });

    testWidgets('shows Save button for admin users', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          organizationProvider.overrideWith((ref) async => _testOrg()),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
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
          organizationProvider.overrideWith((ref) async => _testOrg()),
          currentUserProvider.overrideWith((ref) async => _staffUser()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsNothing);
    });

    testWidgets('shows color picker tiles', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          organizationProvider.overrideWith((ref) async => _testOrg()),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Primary Color'), findsOneWidget);
      expect(find.text('Secondary Color'), findsOneWidget);
      expect(find.text('Accent Color'), findsOneWidget);
    });

    testWidgets('preview section shows color buttons', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          organizationProvider.overrideWith((ref) async => _testOrg()),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Accent'), findsOneWidget);
    });
  });
}
