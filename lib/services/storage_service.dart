import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadFile({
    required File file,
    required String path,
    void Function(double)? onProgress,
  }) async {
    final ref = _storage.ref().child(path);
    final task = ref.putFile(file);
    StreamSubscription? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        },
        onError: (_) {}, // handled by await task below
      );
    }
    try {
      await task;
      return await ref.getDownloadURL();
    } finally {
      await sub?.cancel();
    }
  }

  Future<String> uploadBytes({
    required Uint8List bytes,
    required String path,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return await ref.getDownloadURL();
  }

  /// Uploads a policy file to organizations/{orgId}/policies/{policyId}/{filename}.
  /// Returns the download URL.
  Future<String> uploadPolicy(
    String orgId,
    String policyId,
    Uint8List bytes,
    String filename,
    String contentType, {
    void Function(double)? onProgress,
  }) async {
    final path = 'organizations/$orgId/policies/$policyId/$filename';
    final ref = _storage.ref().child(path);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    StreamSubscription? sub;
    if (onProgress != null) {
      sub = task.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
          }
        },
        onError: (_) {}, // handled by await task below
      );
    }
    try {
      await task;
      return await ref.getDownloadURL();
    } finally {
      await sub?.cancel();
    }
  }

  /// Deletes a policy file from Storage. Silently ignores if not found.
  Future<void> deletePolicyFile(
      String orgId, String policyId, String filename) async {
    final path = 'organizations/$orgId/policies/$policyId/$filename';
    try {
      await _storage.ref().child(path).delete();
    } catch (_) {}
  }

  Future<void> deleteFile(String path) async {
    await _storage.ref().child(path).delete();
  }

  Future<String> getDownloadUrl(String path) async {
    return await _storage.ref().child(path).getDownloadURL();
  }
}
