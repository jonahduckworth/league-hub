import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/services/auth_service.dart';
import 'package:league_hub/services/firestore_service.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late FakeFirebaseFirestore fakeFirestore;
  late AuthService auth;
  late FirestoreService firestore;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    fakeFirestore = FakeFirebaseFirestore();
    auth = AuthService(auth: mockAuth, firestore: fakeFirestore);
    firestore = FirestoreService(firestore: fakeFirestore);
  });

  // ---------------------------------------------------------------------------
  // createAccount
  // ---------------------------------------------------------------------------

  group('createAccount', () {
    test('creates a Firebase Auth user', () async {
      final credential = await auth.createAccount(
        'alice@example.com',
        'password123',
        'Alice',
      );

      expect(credential.user, isNotNull);
      expect(credential.user!.email, 'alice@example.com');
    });

    test('created user has displayName set', () async {
      final credential = await auth.createAccount(
        'bob@example.com',
        'password123',
        'Bob Smith',
      );
      expect(credential.user!.displayName, 'Bob Smith');
    });
  });

  // ---------------------------------------------------------------------------
  // signInWithEmail
  // ---------------------------------------------------------------------------

  group('signInWithEmail', () {
    setUp(() async {
      await auth.createAccount('carol@example.com', 'password123', 'Carol');
      await auth.signOut();
    });

    test('signs in with correct credentials', () async {
      final credential =
          await auth.signInWithEmail('carol@example.com', 'password123');

      expect(credential.user, isNotNull);
      expect(credential.user!.email, 'carol@example.com');
      expect(auth.currentUser, isNotNull);
    });

    test('auto-creates Firestore user doc on first sign-in if missing',
        () async {
      final credential =
          await auth.signInWithEmail('carol@example.com', 'password123');
      final uid = credential.user!.uid;

      final appUser = await firestore.getUser(uid);
      expect(appUser, isNotNull);
      expect(appUser!.email, 'carol@example.com');
    });
  });

  // ---------------------------------------------------------------------------
  // signOut
  // ---------------------------------------------------------------------------

  group('signOut', () {
    test('clears currentUser after sign-out', () async {
      await auth.createAccount('dave@example.com', 'password123', 'Dave');
      expect(auth.currentUser, isNotNull);

      await auth.signOut();
      expect(auth.currentUser, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // createAccountFromInvite
  // ---------------------------------------------------------------------------

  group('createAccountFromInvite', () {
    test('creates Auth user and writes Firestore doc with invite data',
        () async {
      const orgId = 'invite-org';
      final invitation = Invitation(
        id: 'inv-1',
        orgId: orgId,
        email: 'eve@example.com',
        displayName: 'Eve',
        role: 'managerAdmin',
        hubIds: ['hub-a', 'hub-b'],
        teamIds: ['team-x'],
        invitedBy: 'admin-1',
        invitedByName: 'Admin',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        token: 'abc123',
      );

      await auth.createAccountFromInvite(
        'eve@example.com',
        'password123',
        'Eve',
        invitation,
      );

      final uid = auth.currentUser!.uid;
      final appUser = await firestore.getUser(uid);
      expect(appUser, isNotNull);
      expect(appUser!.email, 'eve@example.com');
      expect(appUser.orgId, orgId);
      expect(appUser.hubIds, ['hub-a', 'hub-b']);
      expect(appUser.teamIds, ['team-x']);
      expect(appUser.role.name, 'managerAdmin');
    });
  });

  // ---------------------------------------------------------------------------
  // authStateChanges stream
  // ---------------------------------------------------------------------------

  group('authStateChanges', () {
    test('emits non-null user after sign-in and null after sign-out', () async {
      await auth.createAccount('frank@example.com', 'password123', 'Frank');

      final events = <bool>[];
      final subscription =
          auth.authStateChanges.listen((user) => events.add(user != null));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await subscription.cancel();

      expect(events, contains(true));
      expect(events, contains(false));
    });
  });

  // ---------------------------------------------------------------------------
  // getCurrentAppUser
  // ---------------------------------------------------------------------------

  group('getCurrentAppUser', () {
    test('returns null when no user is signed in', () async {
      final result = await auth.getCurrentAppUser();
      expect(result, isNull);
    });

    test('returns AppUser after sign-in with existing Firestore doc', () async {
      await auth.createAccount('grace@example.com', 'password123', 'Grace');
      await auth.signInWithEmail('grace@example.com', 'password123');

      // Ensure Firestore doc exists (signInWithEmail creates it if missing).
      final appUser = await auth.getCurrentAppUser();
      expect(appUser, isNotNull);
      expect(appUser!.email, 'grace@example.com');
    });
  });
}
