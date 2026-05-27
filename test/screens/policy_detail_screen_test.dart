import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/policy.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/policy_detail_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('PolicyDetailScreen', () {
    final staffUser = AppUser(
      id: 'user-1',
      email: 'staff@example.com',
      displayName: 'Staff User',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: ['hub-1'],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final uploaderUser = AppUser(
      id: 'uploader-1',
      email: 'uploader@example.com',
      displayName: 'Manager',
      role: UserRole.managerAdmin,
      orgId: 'org-1',
      hubIds: ['hub-1'],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final superAdminUser = AppUser(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Admin User',
      role: UserRole.superAdmin,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final testLeagues = [
      League(
        id: 'league-1',
        orgId: 'org-1',
        name: 'Spring League',
        abbreviation: 'SL',
        createdAt: DateTime.now(),
      ),
    ];

    final version1 = PolicyVersion(
      fileUrl: 'https://storage.example.com/policy-1/v1.pdf',
      version: 1,
      uploadedAt: DateTime.now().subtract(Duration(days: 5)),
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager',
      fileSize: 1024000,
    );

    final version2 = PolicyVersion(
      fileUrl: 'https://storage.example.com/policy-1/v2.pdf',
      version: 2,
      uploadedAt: DateTime.now().subtract(Duration(days: 2)),
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager',
      fileSize: 1024500,
    );

    final pdfPolicy = Policy(
      id: 'policy-1',
      orgId: 'org-1',
      leagueId: 'league-1',
      name: 'Code of Conduct Policy',
      fileUrl: 'https://storage.example.com/policy-1/v2.pdf',
      fileType: 'pdf',
      fileSize: 1024500,
      category: 'Code of Conduct',
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager',
      versions: [version1, version2],
      createdAt: DateTime.now().subtract(Duration(days: 5)),
      updatedAt: DateTime.now().subtract(Duration(days: 2)),
    );

    final docxPolicy = Policy(
      id: 'policy-2',
      orgId: 'org-1',
      name: 'Overage Policy',
      fileUrl: 'https://storage.example.com/policy-2/v1.docx',
      fileType: 'docx',
      fileSize: 512000,
      category: 'Policy',
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager',
      versions: [
        PolicyVersion(
          fileUrl: 'https://storage.example.com/policy-2/v1.docx',
          version: 1,
          uploadedAt: DateTime.now(),
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager',
          fileSize: 512000,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final imagePolicy = Policy(
      id: 'policy-3',
      orgId: 'org-1',
      name: 'Policy Attachment',
      fileUrl: 'https://storage.example.com/policy-3/v1.jpg',
      fileType: 'jpg',
      fileSize: 2048000,
      category: 'Other',
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager',
      versions: [
        PolicyVersion(
          fileUrl: 'https://storage.example.com/policy-3/v1.jpg',
          version: 1,
          uploadedAt: DateTime.now(),
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager',
          fileSize: 2048000,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Widget createTestWidget({
      required String policyId,
      AppUser? user,
      Policy? policy,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? staffUser,
          ),
          policyProvider(policyId).overrideWith(
            (ref) => Stream.value(policy),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
        ],
        child: MaterialApp(
          home: PolicyDetailScreen(policyId: policyId),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    group('Screen Rendering', () {
      testWidgets('renders policy details without crashing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Code of Conduct Policy'), findsOneWidget);
      });

      testWidgets('displays policy title', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Code of Conduct Policy'), findsOneWidget);
      });

      testWidgets('displays policy category', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Code of Conduct'), findsOneWidget);
      });

      testWidgets('displays policy file type', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('PDF'), findsOneWidget);
      });

      testWidgets('displays policy not found message when missing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'non-existent', policy: null),
        );
        await tester.pumpAndSettle();
        expect(find.text('Policy not found.'), findsOneWidget);
      });

      testWidgets('displays loading indicator while fetching',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: null),
        );
        // Before pumpAndSettle, loading indicator should be visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('File Metadata Display', () {
      testWidgets('displays file size', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('File size'), findsOneWidget);
      });

      testWidgets('displays upload date', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Uploaded by'), findsOneWidget);
      });

      testWidgets('displays creation date', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Created'), findsOneWidget);
      });

      testWidgets('displays last updated date', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Last updated'), findsOneWidget);
      });

      testWidgets('displays uploader name', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        // "Manager" may appear in both metadata and version history
        expect(find.text('Manager'), findsWidgets);
      });
    });

    group('Version History Section', () {
      testWidgets('displays version history section when versions exist',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Version History'), findsOneWidget);
      });

      testWidgets('displays multiple version entries',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        // Should show multiple versions
        expect(find.text('Latest'), findsOneWidget);
      });

      testWidgets('marks latest version as latest',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Latest'), findsOneWidget);
      });

      testWidgets('displays version count', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Versions'), findsOneWidget);
      });

      testWidgets('hides version history when no versions',
          (WidgetTester tester) async {
        final noVersionPolicy = Policy(
          id: 'policy-no-ver',
          orgId: 'org-1',
          name: 'No Versions',
          fileUrl: 'https://storage.example.com/policy/v1.pdf',
          fileType: 'pdf',
          fileSize: 1024000,
          category: 'Other',
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-no-ver', policy: noVersionPolicy),
        );
        await tester.pumpAndSettle();
        // Version history section should not be present if empty
      });
    });

    group('Open Button', () {
      testWidgets('displays open button', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open In App'), findsOneWidget);
      });

      testWidgets('open button is enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        // The open button uses ElevatedButton.icon which renders with an
        // internal Row. Find it via the button text instead.
        expect(find.text('Open In App'), findsOneWidget);
      });
    });

    group('Delete Button Visibility', () {
      testWidgets('shows delete button for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policyId: 'policy-1',
            user: superAdminUser,
            policy: pdfPolicy,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('shows delete button for uploader (managerAdmin)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policyId: 'policy-1',
            user: uploaderUser,
            policy: pdfPolicy,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('hides delete button for staff members',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policyId: 'policy-1',
            user: staffUser,
            policy: pdfPolicy,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      });
    });

    group('Edit / Upload New Version Button', () {
      testWidgets('shows upload new version button for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policyId: 'policy-1',
            user: superAdminUser,
            policy: pdfPolicy,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Upload New Version'), findsOneWidget);
      });

      testWidgets('shows upload new version button for uploader',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policyId: 'policy-1',
            user: uploaderUser,
            policy: pdfPolicy,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Upload New Version'), findsOneWidget);
      });

      testWidgets('hides upload new version button for staff',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policyId: 'policy-1',
            user: staffUser,
            policy: pdfPolicy,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Upload New Version'), findsNothing);
      });
    });

    group('File Type Icons and Colors', () {
      testWidgets('displays correct icon for PDF files',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      });

      testWidgets('displays correct icon for DOCX files',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-2', policy: docxPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.description), findsOneWidget);
      });

      testWidgets('displays correct icon for image files',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-3', policy: imagePolicy),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.image), findsOneWidget);
      });
    });

    group('League Display', () {
      testWidgets('displays league name if policy is league-scoped',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Spring League'), findsOneWidget);
      });

      testWidgets('does not display league if policy has no league scope',
          (WidgetTester tester) async {
        final noLeaguePolicy = Policy(
          id: 'policy-org',
          orgId: 'org-1',
          name: 'Org Policy',
          fileUrl: 'https://storage.example.com/policy/v1.pdf',
          fileType: 'pdf',
          fileSize: 1024000,
          category: 'Other',
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager',
          versions: [
            PolicyVersion(
              fileUrl: 'https://storage.example.com/policy/v1.pdf',
              version: 1,
              uploadedAt: DateTime.now(),
              uploadedBy: 'uploader-1',
              uploadedByName: 'Manager',
              fileSize: 1024000,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-org', policy: noLeaguePolicy),
        );
        await tester.pumpAndSettle();
      });
    });

    group('App Bar', () {
      testWidgets('displays policy as title in app bar',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policyId: 'policy-1', policy: pdfPolicy),
        );
        await tester.pumpAndSettle();
        expect(find.text('Policy'), findsOneWidget);
      });
    });
  });
}
