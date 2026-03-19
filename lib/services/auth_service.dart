import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/invitation.dart';
import '../core/constants.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    // Ensure Firestore user doc exists
    final uid = credential.user!.uid;
    final docRef = _db.collection(AppConstants.usersCollection).doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final user = AppUser(
        id: uid,
        email: email,
        displayName: credential.user!.displayName ?? email.split('@').first,
        role: UserRole.staff,
        hubIds: [],
        teamIds: [],
        createdAt: DateTime.now(),
        isActive: true,
      );
      await docRef.set(user.toJson());
    }
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserCredential> createAccount(
      String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);
    return credential;
  }

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc =
        await _db.collection(AppConstants.usersCollection).doc(user.uid).get();
    if (!doc.exists) return null;
    return AppUser.fromJson({'id': doc.id, ...doc.data()!});
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> createAccountFromInvite(
    String email,
    String password,
    String displayName,
    Invitation invitation,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);
    final uid = credential.user!.uid;
    final role = UserRole.values.firstWhere(
      (e) => e.name == invitation.role,
      orElse: () => UserRole.staff,
    );
    final user = AppUser(
      id: uid,
      email: email,
      displayName: displayName,
      role: role,
      orgId: invitation.orgId,
      hubIds: invitation.hubIds,
      teamIds: invitation.teamIds,
      createdAt: DateTime.now(),
      isActive: true,
    );
    await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(user.toJson());
  }
}
