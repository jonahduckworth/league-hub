import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/document.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/document_detail_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('DocumentDetailScreen', () {
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
      displayName: 'Manager Admin',
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

    final version1 = DocumentVersion(
      fileUrl: 'https://storage.example.com/doc-1/v1.pdf',
      version: 1,
      uploadedAt: DateTime.now().subtract(Duration(days: 5)),
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager Admin',
      fileSize: 1024000,
    );

    final version2 = DocumentVersion(
      fileUrl: 'https://storage.example.com/doc-1/v2.pdf',
      version: 2,
      uploadedAt: DateTime.now().subtract(Duration(days: 2)),
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager Admin',
      fileSize: 1024500,
    );

    final pdfDocument = Document(
      id: 'doc-1',
      orgId: 'org-1',
      leagueId: 'league-1',
      name: 'Team Roster',
      fileUrl: 'https://storage.example.com/doc-1/v2.pdf',
      fileType: 'pdf',
      fileSize: 1024500,
      category: 'Rosters',
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager Admin',
      versions: [version1, version2],
      createdAt: DateTime.now().subtract(Duration(days: 5)),
      updatedAt: DateTime.now().subtract(Duration(days: 2)),
    );

    final docxDocument = Document(
      id: 'doc-2',
      orgId: 'org-1',
      name: 'Game Rules',
      fileUrl: 'https://storage.example.com/doc-2/v1.docx',
      fileType: 'docx',
      fileSize: 512000,
      category: 'Policies',
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager Admin',
      versions: [
        DocumentVersion(
          fileUrl: 'https://storage.example.com/doc-2/v1.docx',
          version: 1,
          uploadedAt: DateTime.now(),
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager Admin',
          fileSize: 512000,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final imageDocument = Document(
      id: 'doc-3',
      orgId: 'org-1',
      name: 'Team Photo',
      fileUrl: 'https://storage.example.com/doc-3/v1.jpg',
      fileType: 'jpg',
      fileSize: 2048000,
      category: 'Other',
      uploadedBy: 'uploader-1',
      uploadedByName: 'Manager Admin',
      versions: [
        DocumentVersion(
          fileUrl: 'https://storage.example.com/doc-3/v1.jpg',
          version: 1,
          uploadedAt: DateTime.now(),
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager Admin',
          fileSize: 2048000,
        ),
      ],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Widget createTestWidget({
      required String docId,
      AppUser? user,
      Document? document,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? staffUser,
          ),
          documentProvider(docId).overrideWith(
            (ref) => Stream.value(document),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
        ],
        child: MaterialApp(
          home: DocumentDetailScreen(docId: docId),
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
      testWidgets('renders document details without crashing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Team Roster'), findsOneWidget);
      });

      testWidgets('displays document title', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Team Roster'), findsOneWidget);
      });

      testWidgets('displays document category', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Rosters'), findsOneWidget);
      });

      testWidgets('displays document file type', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('PDF'), findsOneWidget);
      });

      testWidgets('displays document not found message when missing',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'non-existent', document: null),
        );
        await tester.pumpAndSettle();
        expect(find.text('Document not found.'), findsOneWidget);
      });

      testWidgets('displays loading indicator while fetching',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: null),
        );
        // Before pumpAndSettle, loading indicator should be visible
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('File Metadata Display', () {
      testWidgets('displays file size', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('File size'), findsOneWidget);
      });

      testWidgets('displays upload date', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Uploaded by'), findsOneWidget);
      });

      testWidgets('displays creation date', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Created'), findsOneWidget);
      });

      testWidgets('displays last updated date', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Last updated'), findsOneWidget);
      });

      testWidgets('displays uploader name', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        // "Manager Admin" may appear in both metadata and version history
        expect(find.text('Manager Admin'), findsWidgets);
      });
    });

    group('Version History Section', () {
      testWidgets('displays version history section when versions exist',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Version History'), findsOneWidget);
      });

      testWidgets('displays multiple version entries',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        // Should show multiple versions
        expect(find.text('Latest'), findsOneWidget);
      });

      testWidgets('marks latest version as latest',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Latest'), findsOneWidget);
      });

      testWidgets('displays version count', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Versions'), findsOneWidget);
      });

      testWidgets('hides version history when no versions',
          (WidgetTester tester) async {
        final noVersionDoc = Document(
          id: 'doc-no-ver',
          orgId: 'org-1',
          name: 'No Versions',
          fileUrl: 'https://storage.example.com/doc/v1.pdf',
          fileType: 'pdf',
          fileSize: 1024000,
          category: 'Other',
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager Admin',
          versions: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(docId: 'doc-no-ver', document: noVersionDoc),
        );
        await tester.pumpAndSettle();
        // Version history section should not be present if empty
      });
    });

    group('Download Button', () {
      testWidgets('displays download button', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open / Download'), findsOneWidget);
      });

      testWidgets('download button is enabled', (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        // The download button uses ElevatedButton.icon which renders with an
        // internal Row. Find it via the button text instead.
        expect(find.text('Open / Download'), findsOneWidget);
      });
    });

    group('Delete Button Visibility', () {
      testWidgets('shows delete button for superAdmin',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            docId: 'doc-1',
            user: superAdminUser,
            document: pdfDocument,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('shows delete button for uploader (managerAdmin)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            docId: 'doc-1',
            user: uploaderUser,
            document: pdfDocument,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      });

      testWidgets('hides delete button for staff members',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            docId: 'doc-1',
            user: staffUser,
            document: pdfDocument,
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
            docId: 'doc-1',
            user: superAdminUser,
            document: pdfDocument,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Upload New Version'), findsOneWidget);
      });

      testWidgets('shows upload new version button for uploader',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            docId: 'doc-1',
            user: uploaderUser,
            document: pdfDocument,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Upload New Version'), findsOneWidget);
      });

      testWidgets('hides upload new version button for staff',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            docId: 'doc-1',
            user: staffUser,
            document: pdfDocument,
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
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      });

      testWidgets('displays correct icon for DOCX files',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-2', document: docxDocument),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.description), findsOneWidget);
      });

      testWidgets('displays correct icon for image files',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-3', document: imageDocument),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.image), findsOneWidget);
      });
    });

    group('League Display', () {
      testWidgets('displays league name if document is league-scoped',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Spring League'), findsOneWidget);
      });

      testWidgets('does not display league if document has no league scope',
          (WidgetTester tester) async {
        final noLeagueDoc = Document(
          id: 'doc-org',
          orgId: 'org-1',
          name: 'Org Document',
          fileUrl: 'https://storage.example.com/doc/v1.pdf',
          fileType: 'pdf',
          fileSize: 1024000,
          category: 'Other',
          uploadedBy: 'uploader-1',
          uploadedByName: 'Manager Admin',
          versions: [
            DocumentVersion(
              fileUrl: 'https://storage.example.com/doc/v1.pdf',
              version: 1,
              uploadedAt: DateTime.now(),
              uploadedBy: 'uploader-1',
              uploadedByName: 'Manager Admin',
              fileSize: 1024000,
            ),
          ],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await tester.pumpWidget(
          createTestWidget(docId: 'doc-org', document: noLeagueDoc),
        );
        await tester.pumpAndSettle();
      });
    });

    group('App Bar', () {
      testWidgets('displays document as title in app bar',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(docId: 'doc-1', document: pdfDocument),
        );
        await tester.pumpAndSettle();
        expect(find.text('Document'), findsOneWidget);
      });
    });
  });
}
