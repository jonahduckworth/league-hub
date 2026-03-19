import 'dart:typed_data';

import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/storage_service.dart';

void main() {
  late MockFirebaseStorage mockStorage;
  late StorageService storage;

  const orgId = 'test-org-storage';
  const docId = 'test-doc-001';

  setUp(() {
    mockStorage = MockFirebaseStorage();
    storage = StorageService(storage: mockStorage);
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
    });

    test('upload without progress callback completes', () async {
      final bytes = Uint8List.fromList(List.filled(1024, 0));

      final url = await storage.uploadDocument(
        orgId,
        docId,
        bytes,
        'large.bin',
        'application/octet-stream',
      );

      expect(url, isNotEmpty);
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
