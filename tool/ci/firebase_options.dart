// Non-production Firebase configuration used only by CI static analysis and tests.
// The real generated lib/firebase_options.dart remains git-ignored.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions currentPlatform = FirebaseOptions(
    apiKey: 'ci-placeholder',
    appId: '1:000000000000:android:ci-placeholder',
    messagingSenderId: '000000000000',
    projectId: 'league-hub-ci',
    storageBucket: 'league-hub-ci.invalid',
  );
}
