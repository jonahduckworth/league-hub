import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const String _projectId = 'jdb-league-hub';
const String _storageBucket = 'jdb-league-hub.appspot.com';

/// Provides setup and teardown helpers for Firebase emulator integration tests.
///
/// Usage:
/// ```dart
/// setUpAll(FirebaseTestHelper.setupAll);
/// tearDown(FirebaseTestHelper.clearData);
/// tearDownAll(FirebaseTestHelper.tearDownAll);
/// ```
class FirebaseTestHelper {
  static bool _initialized = false;

  /// Initialize Firebase once and connect all services to local emulators.
  /// Call this from [setUpAll].
  static Future<void> setupAll() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!_initialized) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:000000000000:android:0000000000000000',
          messagingSenderId: '000000000000',
          projectId: _projectId,
          storageBucket: _storageBucket,
        ),
      );
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFirestore.instance.settings = const Settings(
        host: 'localhost:8080',
        sslEnabled: false,
        persistenceEnabled: false,
      );
      await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      _initialized = true;
    }
  }

  /// Clear all Firestore documents via the emulator REST API.
  static Future<void> clearFirestore() async {
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse(
          'http://localhost:8080/emulator/v1/projects/$_projectId'
          '/databases/(default)/documents',
        ),
      );
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      await response.drain<void>();
    } on SocketException {
      // Emulator not running — tests will fail naturally; no need to rethrow here.
    } finally {
      client.close();
    }
  }

  /// Clear all Auth users via the emulator REST API.
  static Future<void> clearAuth() async {
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse(
          'http://localhost:9099/emulator/v1/projects/$_projectId/accounts',
        ),
      );
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      await response.drain<void>();
    } on SocketException {
      // Emulator not running.
    } finally {
      client.close();
    }
  }

  /// Clear Firestore and Auth data. Call from [setUp] or [tearDown].
  static Future<void> clearData() async {
    await Future.wait([clearFirestore(), clearAuth()]);
  }

  /// Full teardown — clear all data. Call from [tearDownAll].
  static Future<void> tearDownAll() async {
    await clearData();
  }
}
