import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/policy.dart';
import 'package:league_hub/services/policy_file_service.dart';

void main() {
  final policy = Policy(
      id: 'p',
      orgId: 'org',
      hubId: 'h',
      teamId: 't',
      name: 'Bench / Visor Policy',
      fileUrl: 'https://example.com/p.pdf',
      fileType: 'pdf',
      fileSize: 1,
      category: 'Policy',
      uploadedBy: 'admin',
      uploadedByName: 'Admin',
      versions: [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  for (final role in UserRole.values) {
    AppUser actor(
            {bool assigned = true, bool active = true, String org = 'org'}) =>
        AppUser(
            id: 'viewer',
            email: 'test@example.com',
            displayName: 'Viewer',
            role: role,
            orgId: org,
            hubIds: assigned ? ['h'] : [],
            teamIds: assigned ? ['t'] : [],
            isActive: active,
            createdAt: DateTime(2026));
    test('$role can export authorized policies only', () {
      expect(canExportPolicy(actor(), policy), isTrue);
      expect(canExportPolicy(actor(active: false), policy), isFalse);
      expect(canExportPolicy(actor(org: 'other'), policy),
          role == UserRole.platformOwner);
      expect(canExportPolicy(actor(assigned: false), policy),
          role == UserRole.platformOwner || role == UserRole.superAdmin);
    });
  }
  test('fresh export normalizes native timestamps including historical versions', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('organizations/org/policies/p').set({
      ...policy.toJson(), 'createdAt': Timestamp.fromDate(DateTime(2026)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 2)),
      'versions': [{'url': 'https://example.com/old.pdf', 'version': 1,
        'uploadedAt': Timestamp.fromDate(DateTime(2025)), 'fileSize': 10}],
    });
    final fresh = await PolicyFileService(firestore: firestore).refresh('org', 'p');
    expect(fresh.createdAt.year, 2026);
    expect(fresh.versions.single.uploadedAt.year, 2025);
    expect(fresh.id, 'p');
  });
  test('export filename cannot create another path', () {
    expect(policyExportName('../../Bench / Visor', 'pdf'),
        '.._.._Bench _ Visor.pdf');
    expect(policyExportName('Rules.PDF', 'pdf'), 'Rules.PDF');
    expect(policyExportName('', 'pdf'), 'League Hub Policy.pdf');
  });
  test('MIME types and encoded historical URLs choose correct extensions', () {
    expect(policyFileExtension('application/pdf; charset=utf-8', ''), 'pdf');
    expect(
        policyFileExtension(
            '', 'https://example.com/o/policies%2Fold.DOCX?token=x'),
        'docx');
    expect(policyFileExtension('pdf', 'https://example.com/current.docx'), 'docx');
    expect(policyFileExtension('docx', 'https://example.com/historical.pdf'), 'pdf');
    expect(policyFileCanPrint('docx'), isFalse);
    expect(policyFileCanPrint('pdf'), isTrue);
    expect(policyFileCanPrint('png'), isTrue);
  });
}
