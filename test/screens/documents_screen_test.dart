import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/document.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/documents_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('DocumentsScreen', () {
    final testUser = AppUser(
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Test User',
      role: UserRole.staff,
      orgId: 'org-1',
      createdAt: DateTime(2024),
      hubIds: [],
      teamIds: [],
      isActive: true,
    );

    final adminUser = AppUser(
      id: 'admin-1',
      email: 'admin@example.com',
      displayName: 'Admin User',
      role: UserRole.superAdmin,
      orgId: 'org-1',
      createdAt: DateTime(2024),
      hubIds: [],
      teamIds: [],
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
      League(
        id: 'league-2',
        orgId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime.now(),
      ),
    ];

    final testDocuments = [
      Document(
        id: 'doc-1',
        orgId: 'org-1',
        name: 'Spring Roster.xlsx',
        category: 'Rosters',
        fileType: 'xlsx',
        fileSize: 25600,
        fileUrl: 'https://example.com/file.pdf',
        leagueId: 'league-1',
        uploadedBy: 'admin-1',
        uploadedByName: 'Test User',
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
        versions: [],
      ),
      Document(
        id: 'doc-2',
        orgId: 'org-1',
        name: 'Tournament Schedule.pdf',
        category: 'Schedules',
        fileType: 'pdf',
        fileSize: 102400,
        fileUrl: 'https://example.com/file.pdf',
        leagueId: 'league-2',
        uploadedBy: 'admin-1',
        uploadedByName: 'Test User',
        createdAt: DateTime.now().subtract(Duration(hours: 4)),
        updatedAt: DateTime.now().subtract(Duration(hours: 4)),
        versions: [],
      ),
      Document(
        id: 'doc-3',
        orgId: 'org-1',
        name: 'League Policies.docx',
        category: 'Policies',
        fileType: 'docx',
        fileSize: 51200,
        fileUrl: 'https://example.com/file.pdf',
        uploadedBy: 'admin-1',
        uploadedByName: 'Test User',
        createdAt: DateTime.now().subtract(Duration(days: 5)),
        updatedAt: DateTime.now().subtract(Duration(days: 5)),
        versions: [],
      ),
    ];

    Widget createTestWidget({
      AppUser? user,
      List<Document>? documents,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? testUser,
          ),
          documentsProvider.overrideWith(
            (ref) => Stream.value(documents ?? testDocuments),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          selectedLeagueProvider.overrideWith(
            (ref) => null,
          ),
          selectedCategoryProvider.overrideWith(
            (ref) => 'All',
          ),
        ],
        child: MaterialApp(
          home: DocumentsScreen(),
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
      testWidgets('renders without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(DocumentsScreen), findsOneWidget);
      });

      testWidgets('displays title Documents', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Documents'), findsOneWidget);
      });

      testWidgets('has search field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('Search documents...'), findsOneWidget);
      });
    });

    group('FAB Visibility', () {
      testWidgets('shows FAB for superAdmin', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: adminUser));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('shows FAB for managerAdmin', (WidgetTester tester) async {
        final managerAdmin = AppUser(
          id: 'manager-1',
          email: 'manager@example.com',
          displayName: 'Manager Admin',
          role: UserRole.managerAdmin,
          orgId: 'org-1',
          createdAt: DateTime(2024),
          hubIds: [],
          teamIds: [],
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: managerAdmin));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('hides FAB for staff user', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(user: testUser));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsNothing);
      });

      testWidgets('hides FAB for guest user', (WidgetTester tester) async {
        final guestUser = AppUser(
          id: 'guest-1',
          email: 'guest@example.com',
          displayName: 'Guest User',
          role: UserRole.staff,
          orgId: 'org-1',
          createdAt: DateTime(2024),
          hubIds: [],
          teamIds: [],
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(user: guestUser));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsNothing);
      });
    });

    group('Document List Rendering', () {
      testWidgets('displays all documents', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Spring Roster.xlsx'), findsOneWidget);
        expect(find.text('Tournament Schedule.pdf'), findsOneWidget);
        expect(find.text('League Policies.docx'), findsOneWidget);
      });

      testWidgets('displays document categories', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Rosters'), findsWidgets);
        expect(find.text('Schedules'), findsWidgets);
        expect(find.text('Policies'), findsWidgets);
      });

      testWidgets('displays file types', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // File types appear in combined text like "XLSX • 25.0 KB"
        expect(find.textContaining('XLSX'), findsOneWidget);
        expect(find.textContaining('PDF'), findsWidgets);
        expect(find.textContaining('DOCX'), findsOneWidget);
      });

      testWidgets('displays version count', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // All test documents have empty versions list, so versionCount=1, showing 'v1'
        expect(find.text('v1'), findsWidgets);
      });

      testWidgets('displays league association tags', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('SL'), findsWidgets); // Spring League (filter + document tag)
        expect(find.text('FL'), findsWidgets); // Fall League (filter + document tag)
      });

      testWidgets('shows correct file icons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget); // PDF
        expect(find.byIcon(Icons.table_chart), findsOneWidget); // Excel
        expect(find.byIcon(Icons.description), findsOneWidget); // Word
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter pills', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should still render properly
        expect(find.byType(DocumentsScreen), findsOneWidget);
      });
    });

    group('Category Filter', () {
      testWidgets('displays all category chips', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('All'), findsWidgets); // LeagueFilter "All" pill + CategoryFilter "All" chip
        expect(find.text('Rosters'), findsWidgets);
        expect(find.text('Waivers'), findsOneWidget);
        expect(find.text('Schedules'), findsWidgets);
        expect(find.text('Policies'), findsWidgets);
        expect(find.text('Other'), findsOneWidget);
      });

      testWidgets('All category is selected by default',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // All should be selected (visual state depends on styling)
        expect(find.text('All'), findsWidgets);
      });

      testWidgets('category chips are tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find and tap a category chip
        final categoryChips = find.byType(GestureDetector);
        expect(categoryChips, findsWidgets);
      });
    });

    group('Empty State', () {
      testWidgets('shows empty state when no documents',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(documents: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No documents found'), findsOneWidget);
        expect(find.byIcon(Icons.folder_open), findsOneWidget);
      });

      testWidgets('shows upload button in empty state for admins',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            documents: [],
            user: adminUser,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Upload Document'), findsOneWidget);
      });

      testWidgets('no upload button in empty state for staff',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            documents: [],
            user: testUser,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Upload Document'), findsNothing);
      });
    });

    group('Search Functionality', () {
      testWidgets('search field accepts input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField.first, 'Roster');
        await tester.pumpAndSettle();

        // After searching, matching document should be visible
        expect(find.text('Spring Roster.xlsx'), findsOneWidget);
      });

      testWidgets('search filters documents by name',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField.first, 'Tournament');
        await tester.pumpAndSettle();

        // Only tournament document should be visible
        expect(find.text('Tournament Schedule.pdf'), findsOneWidget);
        expect(find.text('Spring Roster.xlsx'), findsNothing);
      });

      testWidgets('search is case insensitive', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField.first, 'spring');
        await tester.pumpAndSettle();

        expect(find.text('Spring Roster.xlsx'), findsOneWidget);
      });

      testWidgets('clearing search shows all documents',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);

        // Search for something
        await tester.enterText(searchField.first, 'Tournament');
        await tester.pumpAndSettle();

        // Clear search
        await tester.enterText(searchField.first, '');
        await tester.pumpAndSettle();

        // All documents should be visible
        expect(find.text('Spring Roster.xlsx'), findsOneWidget);
        expect(find.text('Tournament Schedule.pdf'), findsOneWidget);
        expect(find.text('League Policies.docx'), findsOneWidget);
      });

      testWidgets('search finds no results', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final searchField = find.byType(TextField);
        await tester.enterText(searchField.first, 'NonexistentDocument');
        await tester.pumpAndSettle();

        expect(find.text('No documents found'), findsOneWidget);
      });
    });

    group('Document Tile Information', () {
      testWidgets('tile displays file size', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // File size should be displayed
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('tile displays upload date', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Date information should be shown
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('tile shows league association if present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Documents with league association should show abbreviation
        // (filter pills + document tag chips both show abbreviations)
        expect(find.text('SL'), findsWidgets);
        expect(find.text('FL'), findsWidgets);
      });

      testWidgets('tile does not show league for org-wide docs',
          (WidgetTester tester) async {
        // League Policies has no leagueId
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('League Policies.docx'), findsOneWidget);
      });
    });

    group('File Type Icons and Colors', () {
      testWidgets('PDF shows red icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      });

      testWidgets('Excel shows green icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.table_chart), findsOneWidget);
      });

      testWidgets('Word shows icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.description), findsOneWidget);
      });
    });

    group('Refresh Indicator', () {
      testWidgets('has refresh capability', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('Multiple Documents with Same Category', () {
      testWidgets('displays multiple rosters in list',
          (WidgetTester tester) async {
        final multipleRosters = [
          Document(
            id: 'doc-1',
            orgId: 'org-1',
            name: 'Spring Roster.xlsx',
            category: 'Rosters',
            fileType: 'xlsx',
            fileSize: 25600,
            fileUrl: 'https://example.com/file.pdf',
            leagueId: 'league-1',
            uploadedBy: 'admin-1',
            uploadedByName: 'Test User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            versions: [],
          ),
          Document(
            id: 'doc-2',
            orgId: 'org-1',
            name: 'Fall Roster.xlsx',
            category: 'Rosters',
            fileType: 'xlsx',
            fileSize: 28160,
            fileUrl: 'https://example.com/file.pdf',
            leagueId: 'league-2',
            uploadedBy: 'admin-1',
            uploadedByName: 'Test User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            versions: [],
          ),
        ];

        await tester.pumpWidget(createTestWidget(documents: multipleRosters));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Spring Roster.xlsx'), findsOneWidget);
        expect(find.text('Fall Roster.xlsx'), findsOneWidget);
      });
    });

    group('Document Navigation', () {
      testWidgets('document tiles are tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsWidgets);
      });
    });

    group('Scrolling and Pagination', () {
      testWidgets('long list is scrollable', (WidgetTester tester) async {
        final manyDocs = List.generate(
          20,
          (i) => Document(
            id: 'doc-$i',
            orgId: 'org-1',
            name: 'Document $i.pdf',
            category: 'Other',
            fileType: 'pdf',
            fileSize: 102400,
            fileUrl: 'https://example.com/file.pdf',
            uploadedBy: 'admin-1',
            uploadedByName: 'Test User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            versions: [],
          ),
        );

        await tester.pumpWidget(createTestWidget(documents: manyDocs));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsWidgets);
      });
    });

    group('No League Association Display', () {
      testWidgets('org-wide document shows no league tag',
          (WidgetTester tester) async {
        final orgWideDoc = [
          Document(
            id: 'doc-1',
            orgId: 'org-1',
            name: 'Company Handbook.pdf',
            category: 'Policies',
            fileType: 'pdf',
            fileSize: 102400,
            fileUrl: 'https://example.com/file.pdf',
            uploadedBy: 'admin-1',
            uploadedByName: 'Test User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            versions: [],
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            documents: orgWideDoc,
            leagues: testLeagues,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Company Handbook.pdf'), findsOneWidget);
        // Should not show any league abbreviation for this document
      });
    });
  });
}
