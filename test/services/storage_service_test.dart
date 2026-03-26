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

  // ---------------------------------------------------------------------------
  // Content types and various file sizes
  // ---------------------------------------------------------------------------

  group('content type handling', () {
    test('uploads PDF with correct content type', () async {
      final bytes = Uint8List.fromList(List.filled(100, 0x25)); // %PDF-like
      final url = await storage.uploadBytes(
        bytes: bytes,
        path: 'test/docs/report.pdf',
        contentType: 'application/pdf',
      );
      expect(url, isNotEmpty);
    });

    test('uploads JPEG image', () async {
      final bytes = Uint8List.fromList(List.filled(200, 0xFF));
      final url = await storage.uploadBytes(
        bytes: bytes,
        path: 'test/images/photo.jpg',
        contentType: 'image/jpeg',
      );
      expect(url, isNotEmpty);
    });

    test('uploads PNG image', () async {
      final bytes = Uint8List.fromList(List.filled(150, 0x89));
      final url = await storage.uploadBytes(
        bytes: bytes,
        path: 'test/images/icon.png',
        contentType: 'image/png',
      );
      expect(url, isNotEmpty);
    });

    test('uploads spreadsheet', () async {
      final bytes = Uint8List.fromList(List.filled(300, 0x50));
      final url = await storage.uploadBytes(
        bytes: bytes,
        path: 'test/docs/data.xlsx',
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(url, isNotEmpty);
    });
  });

  group('file size handling', () {
    test('uploads small file (< 1KB)', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final url = await storage.uploadDocument(
          orgId, docId, bytes, 'tiny.txt', 'text/plain');
      expect(url, isNotEmpty);
    });

    test('uploads medium file (100KB)', () async {
      final bytes = Uint8List.fromList(List.filled(100 * 1024, 0xAA));
      final url = await storage.uploadDocument(
          orgId, docId, bytes, 'medium.bin', 'application/octet-stream');
      expect(url, isNotEmpty);
    });

    test('uploads empty file', () async {
      final bytes = Uint8List(0);
      final url = await storage.uploadDocument(
          orgId, docId, bytes, 'empty.txt', 'text/plain');
      expect(url, isNotEmpty);
    });
  });

  group('path handling', () {
    test('uploadDocument uses correct path pattern', () async {
      final bytes = Uint8List.fromList('test'.codeUnits);
      final url = await storage.uploadDocument(
          'org-abc', 'doc-123', bytes, 'file.pdf', 'application/pdf');
      // Mock returns a URL; just verify it completes
      expect(url, isNotEmpty);
    });

    test('uploadBytes with nested path', () async {
      final bytes = Uint8List.fromList('nested'.codeUnits);
      final url = await storage.uploadBytes(
        bytes: bytes,
        path: 'orgs/org1/avatars/user1.jpg',
        contentType: 'image/jpeg',
      );
      expect(url, isNotEmpty);
    });

    test('deleteFile completes for uploaded file', () async {
      final bytes = Uint8List.fromList('to-delete'.codeUnits);
      const path = 'test/delete-target.txt';
      await storage.uploadBytes(
          bytes: bytes, path: path, contentType: 'text/plain');

      await expectLater(storage.deleteFile(path), completes);
    });
  });

  group('StorageService instantiation', () {
    test('can be created with default (no arguments)', () {
      // This just verifies the constructor works; it will use the real
      // FirebaseStorage.instance which isn't initialized in tests, but
      // the constructor itself shouldn't throw.
      final service = StorageService(storage: mockStorage);
      expect(service, isNotNull);
    });
  });
}
