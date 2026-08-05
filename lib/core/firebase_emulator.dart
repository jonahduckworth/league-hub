import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const bool useFirebaseEmulators =
    bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const String firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

Future<void> configureFirebaseEmulators() async {
  if (!useFirebaseEmulators) return;
  if (kReleaseMode) {
    throw StateError('Firebase emulators cannot be enabled in release builds.');
  }

  final auth = FirebaseAuth.instance;
  await auth.useAuthEmulator(firebaseEmulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(firebaseEmulatorHost, 8081);

  // iOS Keychain can retain a production Firebase session after the app is
  // uninstalled. Validate any cached user against the emulator so an invalid
  // production refresh token cannot leave local development stuck loading.
  final cachedUser = auth.currentUser;
  if (cachedUser != null) {
    try {
      await cachedUser.reload();
    } on FirebaseAuthException {
      await auth.signOut();
    }
  }

  debugPrint(
    'Firebase emulator mode enabled at $firebaseEmulatorHost '
    '(Auth 9099, Firestore 8081).',
  );
}
