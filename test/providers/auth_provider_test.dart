import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/services/auth_service.dart';
import 'package:league_hub/services/messaging_service.dart';
import 'package:league_hub/services/permission_service.dart';

import '../helpers/firebase_test_helper.dart';

void main() {
  setUpAll(FirebaseTestHelper.setupFirestore);

  group('Auth Providers', () {
    test('authServiceProvider can be overridden and read', () {
      final fakeAuth = MockFirebaseAuth();
      final fakeDb = FakeFirebaseFirestore();
      final service = AuthService(auth: fakeAuth, firestore: fakeDb);

      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      expect(container.read(authServiceProvider), same(service));
    });

    test('messagingServiceProvider can be overridden and read', () {
      final service = MessagingService();
      final container = ProviderContainer(
        overrides: [messagingServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      expect(container.read(messagingServiceProvider), same(service));
    });

    test('currentUserProvider returns null when overridden to null', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final user = await container.read(currentUserProvider.future);
      expect(user, isNull);
    });

    test('currentUserProvider returns user when overridden', () async {
      final testUser = AppUser(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test',
        role: UserRole.staff,
        orgId: 'org1',
        hubIds: [],
        teamIds: [],
        createdAt: DateTime(2024),
        isActive: true,
      );

      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) async => testUser),
        ],
      );
      addTearDown(container.dispose);

      final user = await container.read(currentUserProvider.future);
      expect(user, isNotNull);
      expect(user!.id, 'u1');
    });
  });

  group('Permission Provider', () {
    test('permissionServiceProvider returns a PermissionService', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(permissionServiceProvider);
      expect(service, isA<PermissionService>());
    });

    test('permissionServiceProvider returns same instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final a = container.read(permissionServiceProvider);
      final b = container.read(permissionServiceProvider);
      expect(identical(a, b), isTrue);
    });
  });
}
