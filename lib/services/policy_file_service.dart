import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/app_user.dart';
import '../models/policy.dart';
import 'permission_service.dart';

bool canExportPolicy(AppUser user, Policy policy) =>
    (user.role == UserRole.platformOwner || user.orgId == policy.orgId) &&
    const PermissionService().canViewPolicy(user,
        leagueId: policy.leagueId, hubId: policy.hubId, teamId: policy.teamId);

String policyFileExtension(String type, String url) {
  const types = {
    'application/pdf': 'pdf',
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'image/bmp': 'bmp',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'text/csv': 'csv',
  };
  final normalized = type.split(';').first.trim().toLowerCase();
  if (types.containsKey(normalized)) return types[normalized]!;
  if (RegExp(r'^\.?[a-z0-9]{1,8}$').hasMatch(normalized)) {
    return normalized.replaceFirst('.', '');
  }
  final path = Uri.decodeComponent(Uri.parse(url).path);
  return RegExp(r'\.([a-zA-Z0-9]{1,8})$')
          .firstMatch(path)
          ?.group(1)
          ?.toLowerCase() ??
      'bin';
}

bool policyFileCanPrint(String extension) => const [
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp'
    ].contains(extension);

String policyExportName(String title, String extension) {
  final safe = title.replaceAll(RegExp(r'[^\w\-. ]'), '_').trim();
  final name = safe.isEmpty ? 'League Hub Policy' : safe;
  return name.toLowerCase().endsWith('.$extension') ? name : '$name.$extension';
}

class PolicyExportFile {
  final Uint8List bytes;
  final String name;
  final String extension;
  const PolicyExportFile(this.bytes, this.name, this.extension);
  String get mimeType => switch (extension) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' =>
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'csv' => 'text/csv',
        _ => 'application/octet-stream',
      };
}

class PolicyFileService {
  Future<Policy> refresh(String orgId, String policyId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('organizations')
        .doc(orgId)
        .collection('policies')
        .doc(policyId)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) throw StateError('Policy no longer available.');
    final policy = Policy.fromJson({...snapshot.data()!, 'id': snapshot.id});
    if (policy.orgId != orgId) {
      throw StateError('Policy organization mismatch.');
    }
    return policy;
  }

  Future<PolicyExportFile> download(Policy policy, {String? versionUrl}) async {
    final url = versionUrl ?? policy.fileUrl;
    if (url != policy.fileUrl &&
        !policy.versions.any((v) => v.fileUrl == url)) {
      throw StateError('This document version is no longer available.');
    }
    final reference = FirebaseStorage.instance.refFromURL(url);
    final prefix = 'organizations/${policy.orgId}/policies/${policy.id}/';
    if (!reference.fullPath.startsWith(prefix)) {
      throw StateError('This file does not belong to the selected policy.');
    }
    // SDK downloads enforce Storage rules rather than exporting a public URL.
    final bytes = await reference.getData(25 * 1024 * 1024);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('The document is empty.');
    }
    final extension =
        policyFileExtension(url == policy.fileUrl ? policy.fileType : '', url);
    return PolicyExportFile(
        bytes, policyExportName(policy.name, extension), extension);
  }
}
