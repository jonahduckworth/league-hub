/// Firebase emulator integration tests for StorageService.
///
/// Run via:
///   firebase emulators:exec --only auth,firestore,storage \
///     --project jdb-league-hub \
///     "flutter test integration_test/services/storage_service_test.dart -d macos"
@Tags(['emulator'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:league_hub/services/storage_service.dart';

import 'firebase_integration_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  const orgId = 'test-org-storage';
  const docId = 'test-doc-001';

  setUpAll(FirebaseIntegrationHelper.setupAll);
  setUp(FirebaseIntegrationHelper.clearData);
  tearDownAll(FirebaseIntegrationHelper.tearDownAll);

  setUp(() {
    storage = StorageService();
  });

  // ---------------------------------------------------------------------------
  // uploadDocument
  // ---------------------------------------------------------------------------

  group('uploadDocument', () {
    test('uploads bytes and returns a non-empty download URL', () async {
      final bytes = Uint8List.fromList('hello world'.codeUnits);

      final url = await storage.uploadDocument(
        orgId,
        docId,
        bytes,
        'test.txt',
        'text/plain',
      );

      expect(url, isNotEmpty);
      expect(url, contains('localhost'));
    });

    test('progress callback is invoked', () async {
      final bytes = Uint8List.fromList(List.filled(1024, 0));
      double? lastProgress;

      await storage.uploadDocument(
        orgId,
        docId,
        bytes,
        'large.bin',
        'application/octet-stream',
        onProgress: (p) => lastProgress = p,
      );

      expect(lastProgress, isNotNull);
      expect(lastProgress, greaterThanOrEqualTo(0.0));
    });
  });

  // ---------------------------------------------------------------------------
  // uploadBytes
  // ---------------------------------------------------------------------------

  group('uploadBytes', () {
    test('uploads bytes to a custom path and returns a URL', () async {
      final bytes = Uint8List.fromList('raw bytes'.codeUnits);

      final url = await storage.uploadBytes(
        bytes: bytes,
        path: 'test/$orgId/raw.txt',
        contentType: 'text/plain',
      );

      expect(url, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteDocumentFile
  // ---------------------------------------------------------------------------

  group('deleteDocumentFile', () {
    test('deletes an existing file without error', () async {
      final bytes = Uint8List.fromList('to delete'.codeUnits);
      await storage.uploadDocument(orgId, docId, bytes, 'delete-me.txt',
          'text/plain');

      await expectLater(
        storage.deleteDocumentFile(orgId, docId, 'delete-me.txt'),
        completes,
      );
    });

    test('does not throw when file does not exist', () async {
      await expectLater(
        storage.deleteDocumentFile(orgId, docId, 'nonexistent.txt'),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getDownloadUrl
  // ---------------------------------------------------------------------------

  group('getDownloadUrl', () {
    test('returns URL for an existing file', () async {
      final bytes = Uint8List.fromList('content'.codeUnits);
      const path = 'test/$orgId/url-test.txt';
      await storage.uploadBytes(
          bytes: bytes, path: path, contentType: 'text/plain');

      final url = await storage.getDownloadUrl(path);
      expect(url, isNotEmpty);
    });
  });
}
