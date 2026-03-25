import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _projectId = 'jdb-league-hub';
const String _storageBucket = 'jdb-league-hub.appspot.com';

/// Provides setup and teardown helpers for Firebase emulator integration tests.
///
/// Usage (Firestore-only tests):
/// ```dart
/// setUpAll(FirebaseTestHelper.setupFirestore);
/// setUp(FirebaseTestHelper.clearFirestore);
/// tearDownAll(FirebaseTestHelper.tearDownAll);
/// ```
///
/// Usage (Auth + Firestore tests — requires native platform channels):
/// ```dart
/// setUpAll(FirebaseTestHelper.setupAll);
/// setUp(FirebaseTestHelper.clearData);
/// tearDownAll(FirebaseTestHelper.tearDownAll);
/// ```
class FirebaseTestHelper {
  static bool _coreInitialized = false;
  static bool _authInitialized = false;
  static bool _storageInitialized = false;

  /// Initialize Firebase core and connect Firestore to the local emulator.
  ///
  /// Safe to call in headless [flutter test] environments — does NOT require
  /// native platform channels for Auth or Storage.
  static Future<void> setupFirestore() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _initializeCore();
    FirebaseFirestore.instance.settings = const Settings(
      host: 'localhost:8081',
      sslEnabled: false,
      persistenceEnabled: false,
    );
  }

  /// Initialize Firebase core, Firestore, Auth, and Storage emulators.
  ///
  /// Requires native platform channels (iOS/Android device or simulator).
  /// Auth and Storage setup failures are silenced gracefully so that tests
  /// that only use Firestore can still run in headless environments.
  static Future<void> setupAll() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _initializeCore();
    FirebaseFirestore.instance.settings = const Settings(
      host: 'localhost:8081',
      sslEnabled: false,
      persistenceEnabled: false,
    );
    if (!_authInitialized) {
      try {
        await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
        _authInitialized = true;
      } on PlatformException catch (e) {
        // ignore: avoid_print
        print('FirebaseAuth emulator unavailable (no native channel): ${e.message}');
      } catch (e) {
        // ignore: avoid_print
        print('FirebaseAuth emulator unavailable: $e');
      }
    }
    if (!_storageInitialized) {
      try {
        await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
        _storageInitialized = true;
      } on PlatformException catch (e) {
        // ignore: avoid_print
        print('FirebaseStorage emulator unavailable (no native channel): ${e.message}');
      } catch (e) {
        // ignore: avoid_print
        print('FirebaseStorage emulator unavailable: $e');
      }
    }
  }

  static Future<void> _initializeCore() async {
    setupFirebaseCoreMocks();
    if (!_coreInitialized) {
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'test-api-key',
            appId: '1:000000000000:android:0000000000000000',
            messagingSenderId: '000000000000',
            projectId: _projectId,
            storageBucket: _storageBucket,
          ),
        );
      } on FirebaseException catch (e) {
        // Ignore duplicate-app — the mock pre-initializes the default app.
        if (e.code != 'duplicate-app') rethrow;
      }
      _coreInitialized = true;
    }
  }

  /// Clear all Firestore documents via the emulator REST API.
  static Future<void> clearFirestore() async {
    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.parse(
          'http://localhost:8081/emulator/v1/projects/$_projectId'
          '/databases/(default)/documents',
        ),
      );
      request.headers.set('Content-Type', 'application/json');
      final response = await request.close();
      await response.drain<void>();
    } on SocketException {
      // Emulator not running — tests will fail naturally; no need to rethrow.
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
