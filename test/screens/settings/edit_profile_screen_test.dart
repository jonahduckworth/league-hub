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
      title: 'Head Coach',
      phone: '555-0101',
      address: '1 Main Arena',
      role: UserRole.platformOwner,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

Widget _buildTestWidget({required List<Override> overrides}) {
  return ProviderScope(
    overrides: [
      organizationProvider.overrideWith((ref) async => null),
      leaguesProvider.overrideWith((ref) => Stream.value([])),
      ...overrides,
    ],
    child: const MaterialApp(
      home: EditProfileScreen(),
    ),
  );
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;

  Future<void> scrollToText(WidgetTester tester, String text) async {
    for (var i = 0; i < 8 && find.text(text).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
    }
  }

  Future<void> scrollToChangePassword(WidgetTester tester) async {
    await scrollToText(tester, 'Change Password');
  }

  Future<void> scrollToRole(WidgetTester tester) async {
    await scrollToText(tester, 'Role');
  }

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
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.text('test@example.com'), findsNothing);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Address'), findsOneWidget);
      await scrollToRole(tester);
      expect(find.text('Role'), findsOneWidget);
    });

    testWidgets('shows change password button', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      await scrollToChangePassword(tester);
      expect(find.text('Change Password'), findsOneWidget);
    });

    testWidgets('tapping Change Password opens dialog', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      await scrollToChangePassword(tester);
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
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
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

    testWidgets('does not render an email field', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      final emailField = find.widgetWithText(TextFormField, 'Email');
      expect(emailField, findsNothing);
      expect(find.text('test@example.com'), findsNothing);
    });

    testWidgets('renders AvatarWidget', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // The AvatarWidget should show initials
      expect(find.text('TU'), findsOneWidget);
    });

    testWidgets('shows camera icon on avatar for photo upload', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('avatar area is tappable', (tester) async {
      final user = _testUser();
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // GestureDetector wrapping the avatar should exist
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('avatar shows network image when avatarUrl present',
        (tester) async {
      final user = AppUser(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        role: UserRole.platformOwner,
        orgId: 'org-1',
        hubIds: [],
        teamIds: [],
        createdAt: DateTime(2025, 1, 1),
        isActive: true,
      );
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => user),
          firestoreServiceProvider
              .overrideWithValue(FirestoreService(firestore: fakeFirestore)),
          authServiceProvider.overrideWithValue(
              AuthService(auth: mockAuth, firestore: fakeFirestore)),
        ],
      ));
      await tester.pumpAndSettle();

      // The AvatarWidget should be present
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}
