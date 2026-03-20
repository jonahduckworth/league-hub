import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/edit_profile_screen.dart';
import 'package:league_hub/services/auth_service.dart';
import 'package:league_hub/services/firestore_service.dart';

AppUser _testUser() => AppUser(
      id: 'u1',
      email: 'test@example.com',
      displayName: 'Test User',
      role: UserRole.platformOwner,
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
      home: EditProfileScreen(),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
  });

  group('EditProfileScreen', () {
    testWidgets('renders profile edit form with user data', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
          authServiceProvider
              .overrideWithValue(AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
    });

    testWidgets('shows change password button', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
          authServiceProvider
              .overrideWithValue(AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('tapping Change Password opens dialog', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
          authServiceProvider
              .overrideWithValue(AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('validates empty display name on save', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
          authServiceProvider
              .overrideWithValue(AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // Clear the name field
      final nameField = find.widgetWithText(TextFormField, 'Display Name');
      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Display name is required'), findsOneWidget);
    });

    testWidgets('validates invalid email on save', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
          authServiceProvider
              .overrideWithValue(AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emailField, 'invalid');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('renders AvatarWidget', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider.overrideWithValue(
              FirestoreService(firestore: fakeFirestore)),
          authServiceProvider
              .overrideWithValue(AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // The AvatarWidget should show initials
      expect(find.text('TU'), findsOneWidget);
    });
  });
}
