import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/invitation.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/organization.dart';
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

    test('signInWithEmail creates user doc if not exists', () async {
      final credential =
          await auth.signInWithEmail('carol@example.com', 'password123');
      final uid = credential.user!.uid;

      final appUser = await firestore.getUser(uid);
      expect(appUser, isNotNull);
      expect(appUser!.email, 'carol@example.com');
    });

    test('signInWithEmail does NOT overwrite existing user doc', () async {
      // First sign-in creates the doc
      final credential =
          await auth.signInWithEmail('carol@example.com', 'password123');
      final uid = credential.user!.uid;

      // Manually update the Firestore doc
      await firestore.updateUserFields(uid, {'displayName': 'Carol Updated'});

      // Sign out and sign in again
      await auth.signOut();
      await auth.signInWithEmail('carol@example.com', 'password123');

      // Verify the updated displayName is preserved
      final appUser = await firestore.getUser(uid);
      expect(appUser!.displayName, 'Carol Updated');
    });
  });

  // ---------------------------------------------------------------------------
  // signOut
  // ---------------------------------------------------------------------------

  group('signOut', () {
    test('signOut calls Firebase signOut', () async {
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
      // Hub IDs don't map to real hubs, so leagueIds should be empty.
      expect(appUser.leagueIds, isEmpty);

      final rawDoc = await fakeFirestore.collection('users').doc(uid).get();
      expect(rawDoc.data()!['acceptedInvitationId'], 'inv-1');
    });

    test('derives leagueIds from hubIds when hubs exist', () async {
      const orgId = 'league-org';

      // Seed org, league, and hub in Firestore.
      await firestore.createOrganization(Organization(
        id: orgId,
        name: 'League Org',
        primaryColor: '#000',
        secondaryColor: '#111',
        accentColor: '#222',
        createdAt: DateTime.now(),
        ownerId: 'admin',
      ));
      await firestore.createLeague(
          orgId,
          League(
            id: 'lg1',
            orgId: orgId,
            name: 'North',
            abbreviation: 'N',
            createdAt: DateTime.now(),
          ));
      await firestore.createHub(
          orgId,
          'lg1',
          Hub(
            id: 'hub-x',
            leagueId: 'lg1',
            orgId: orgId,
            name: 'Hub X',
            createdAt: DateTime.now(),
          ));

      // Sign out any prior user first.
      await auth.signOut();
      // Reset auth for fresh user.
      mockAuth = MockFirebaseAuth();
      auth = AuthService(auth: mockAuth, firestore: fakeFirestore);

      final invitation = Invitation(
        id: 'inv-2',
        orgId: orgId,
        email: 'frank@example.com',
        displayName: 'Frank',
        role: 'staff',
        hubIds: ['hub-x'],
        teamIds: [],
        invitedBy: 'admin',
        invitedByName: 'Admin',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        token: 'xyz789',
      );

      await auth.createAccountFromInvite(
        'frank@example.com',
        'password123',
        'Frank',
        invitation,
      );

      final uid = auth.currentUser!.uid;
      final appUser = await firestore.getUser(uid);
      expect(appUser, isNotNull);
      expect(appUser!.hubIds, ['hub-x']);
      expect(appUser.leagueIds, ['lg1']);
    });

    test('leagueIds empty when invitation has no hubIds', () async {
      await auth.signOut();
      mockAuth = MockFirebaseAuth();
      auth = AuthService(auth: mockAuth, firestore: fakeFirestore);

      final invitation = Invitation(
        id: 'inv-3',
        orgId: 'org1',
        email: 'nohubs@example.com',
        displayName: 'No Hubs',
        role: 'staff',
        hubIds: [],
        teamIds: [],
        invitedBy: 'admin',
        invitedByName: 'Admin',
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        token: 'token3',
      );

      await auth.createAccountFromInvite(
        'nohubs@example.com',
        'password123',
        'No Hubs',
        invitation,
      );

      final uid = auth.currentUser!.uid;
      final appUser = await firestore.getUser(uid);
      expect(appUser!.leagueIds, isEmpty);
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
    test('getCurrentAppUser returns null when not logged in', () async {
      final result = await auth.getCurrentAppUser();
      expect(result, isNull);
    });

    test('getCurrentAppUser returns AppUser when logged in and doc exists',
        () async {
      await auth.createAccount('grace@example.com', 'password123', 'Grace');
      await auth.signInWithEmail('grace@example.com', 'password123');

      final appUser = await auth.getCurrentAppUser();
      expect(appUser, isNotNull);
      expect(appUser!.email, 'grace@example.com');
    });

    test('getCurrentAppUser returns null when logged in but no doc', () async {
      // Create and sign in
      await auth.createAccount('helen@example.com', 'password123', 'Helen');
      await auth.signInWithEmail('helen@example.com', 'password123');

      // Manually delete the Firestore doc
      final uid = auth.currentUser!.uid;
      await fakeFirestore.collection('users').doc(uid).delete();

      // Now getting the app user should return null
      final appUser = await auth.getCurrentAppUser();
      expect(appUser, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // sendPasswordResetEmail
  // ---------------------------------------------------------------------------

  group('sendPasswordResetEmail', () {
    test('sendPasswordResetEmail calls Firebase method', () async {
      // This test just verifies the method is callable without error
      await auth.sendPasswordResetEmail('test@example.com');
      // If no exception is thrown, the test passes
      expect(true, true);
    });
  });
}
