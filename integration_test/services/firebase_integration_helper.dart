import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

const String projectId = 'jdb-league-hub';
const String storageBucket = 'jdb-league-hub.appspot.com';

/// Provides setup and teardown helpers for Firebase emulator integration tests
/// that run via [IntegrationTestWidgetsFlutterBinding] on a real platform
/// (macOS, iOS, or Android).
class FirebaseIntegrationHelper {
  static bool _initialized = false;

  static Future<void> setupAll() async {
    if (!_initialized) {
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyA1rQiqR2WdUvbKtLaCt-OMdZurpwxWwlA',
            appId: '1:757767295888:ios:f11a0d4fcdd12a5a101915',
            messagingSenderId: '757767295888',
            projectId: projectId,
            storageBucket: storageBucket,
          ),
        );
      } on FirebaseException catch (e) {
        // Ignore duplicate-app — the native SDK may have auto-initialized.
        if (e.code != 'duplicate-app') rethrow;
      }
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFirestore.instance.settings = const Settings(
        host: 'localhost:8081',
        sslEnabled: false,
        persistenceEnabled: false,
      );
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      _initialized = true;
    }
  }

  static Future<void> clearFirestore() async {
    // 1. Terminate the Firestore SDK so no stale snapshots are delivered to
    //    stream listeners that are still subscribed from a previous test.
    try {
      await FirebaseFirestore.instance.terminate();
    } catch (_) {}
    // 2. Clear any on-disk or in-memory persistence so the next test starts
    //    with a fully empty cache.
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {}

    // 3. Delete all documents on the emulator via the REST API.
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse(
          'http://localhost:8081/emulator/v1/projects/$projectId'
          '/databases/(default)/documents',
        ),
      );
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('clearFirestore: unexpected status ${response.statusCode}');
      }
      await response.drain<void>();
    } catch (e) {
      // ignore: avoid_print
      print('clearFirestore failed: $e');
    } finally {
      client.close();
    }

    // 4. Reconfigure the SDK so it reconnects to the emulator on next use.
    FirebaseFirestore.instance.settings = const Settings(
      host: 'localhost:8081',
      sslEnabled: false,
      persistenceEnabled: false,
    );

    // 5. Allow the emulator a moment to settle and the SDK to reconnect.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> clearAuth() async {
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse(
          'http://localhost:9099/emulator/v1/projects/$projectId/accounts',
        ),
      );
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('clearAuth: unexpected status ${response.statusCode}');
      }
      await response.drain<void>();
    } catch (e) {
      // ignore: avoid_print
      print('clearAuth failed: $e');
    } finally {
      client.close();
    }
  }

  static Future<void> clearData() async {
    await Future.wait([clearFirestore(), clearAuth()]);
  }

  static Future<void> tearDownAll() async {
    await clearData();
  }
}
