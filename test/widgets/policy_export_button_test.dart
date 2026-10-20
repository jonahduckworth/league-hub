import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/policy.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/services/policy_file_service.dart';
import 'package:league_hub/widgets/policy_export_button.dart';
import 'package:league_hub/widgets/app_glass.dart';

class ExportProbe extends PolicyFileService {
  final Policy fresh;
  int downloads = 0;
  ExportProbe(this.fresh);
  @override
  Future<Policy> refresh(String orgId, String policyId) async => fresh;
  @override
  Future<PolicyExportFile> download(Policy policy, {String? versionUrl}) async {
    downloads++;
    return PolicyExportFile(Uint8List.fromList([1]), 'Policy.pdf', 'pdf');
  }
}

void main() {
  Policy policy({String hub = 'mine'}) => Policy(
      id: 'p',
      orgId: 'org',
      hubId: hub,
      name: 'Policy',
      fileUrl: 'https://example.com/p.pdf',
      fileType: 'pdf',
      fileSize: 1,
      category: 'Policy',
      uploadedBy: 'admin',
      uploadedByName: 'Admin',
      versions: [],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  testWidgets('fresh scope denial stops before file download or native export',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final probe = ExportProbe(policy(hub: 'other'));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => AppUser(
              id: 'u',
              email: 'u@example.com',
              displayName: 'Member',
              role: UserRole.staff,
              orgId: 'org',
              hubIds: ['mine'],
              teamIds: [],
              createdAt: DateTime(2026),
              isActive: true)),
          organizationProvider.overrideWith((ref) => Organization(
              id: 'org',
              name: 'Org',
              primaryColor: '#000000',
              secondaryColor: '#000000',
              accentColor: '#000000',
              createdAt: DateTime(2026),
              ownerId: 'admin')),
          policyProvider('p').overrideWith((ref) => Stream.value(policy())),
          policyFileServiceProvider.overrideWithValue(probe),
        ],
        child: const MaterialApp(
            home: Scaffold(body: PolicyExportButton(policyId: 'p')))));
    await tester.pumpAndSettle();
    final button = find.byTooltip('Share, save or print policy');
    expect(tester.getSize(button), const Size(48, 48));
    expect(tester.getSemantics(button).flagsCollection.isButton, isTrue);
    final icon = tester.widget<Icon>(find.byIcon(Icons.ios_share_rounded));
    expect(icon.color, AppGlassColors.ink);
    expect(tester.getCenter(find.byIcon(Icons.ios_share_rounded)),
        tester.getCenter(find.byType(AppGlassSurface)));
    expect(find.byType(AppGlassSurface), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Print'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(probe.downloads, 0);
    expect(find.textContaining('Could not export this policy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
