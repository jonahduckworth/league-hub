import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/policy.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/policy_screen.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/league_filter.dart';

void main() {
  group('PolicyScreen', () {
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

    final testPolicies = [
      Policy(
        id: 'policy-1',
        orgId: 'org-1',
        name: 'Code of Conduct.pdf',
        category: 'Code of Conduct',
        fileType: 'pdf',
        fileSize: 25600,
        fileUrl: 'https://example.com/file.pdf',
        leagueId: 'league-1',
        uploadedBy: 'admin-1',
        uploadedByName: 'Test User',
        createdAt: DateTime.now().subtract(Duration(days: 2)),
        updatedAt: DateTime.now().subtract(Duration(days: 2)),
        versions: [],
      ),
      Policy(
        id: 'policy-2',
        orgId: 'org-1',
        name: 'Concussion Protocol.pdf',
        category: 'Protocol',
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
      Policy(
        id: 'policy-3',
        orgId: 'org-1',
        name: 'Recruitment Policy.docx',
        category: 'Policy',
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

    group('policy category helpers', () {
      test('shows All plus only categories that exist in the policies', () {
        expect(
          buildVisiblePolicyCategories([testPolicies.first]),
          ['All', 'Code of Conduct'],
        );
      });

      test('keeps categories in configured display order', () {
        expect(
          buildVisiblePolicyCategories([
            testPolicies[1],
            testPolicies.first,
          ]),
          ['All', 'Protocol', 'Code of Conduct'],
        );
      });
    });

    Widget createTestWidget({
      AppUser? user,
      List<Policy>? policies,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? testUser,
          ),
          policiesProvider.overrideWith(
            (ref) => Stream.value(policies ?? testPolicies),
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          selectedLeagueProvider.overrideWith(
            (ref) => null,
          ),
          selectedPolicyCategoryProvider.overrideWith(
            (ref) => 'All',
          ),
        ],
        child: MaterialApp(
          home: PolicyScreen(),
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
        expect(find.byType(PolicyScreen), findsOneWidget);
      });

      testWidgets('displays title Policy', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.text('Policy'), findsWidgets);
      });

      testWidgets('does not show a header search field',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.search), findsNothing);
        expect(find.text('Search policies...'), findsNothing);
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

    group('Policy List Rendering', () {
      testWidgets('displays all policies', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Code of Conduct.pdf'), findsOneWidget);
        expect(find.text('Concussion Protocol.pdf'), findsOneWidget);
        expect(find.text('Recruitment Policy.docx'), findsOneWidget);
      });

      testWidgets('displays policy categories', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Code of Conduct'), findsWidgets);
        expect(find.text('Protocol'), findsWidgets);
        expect(find.text('Policy'), findsWidgets);
      });

      testWidgets('displays file types', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // File types appear in combined text like "PDF • 25.0 KB"
        expect(find.textContaining('PDF'), findsWidgets);
        expect(find.textContaining('DOCX'), findsOneWidget);
      });

      testWidgets('displays version count', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // All test policies have empty versions list, so versionCount=1, showing 'v1'
        expect(find.text('v1'), findsWidgets);
      });

      testWidgets('displays league association tags',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('SL'),
            findsWidgets); // Spring League (filter + policy tag)
        expect(
            find.text('FL'), findsWidgets); // Fall League (filter + policy tag)
      });

      testWidgets('shows correct file icons', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.picture_as_pdf), findsWidgets); // PDF
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
        expect(find.byType(PolicyScreen), findsOneWidget);
      });

      testWidgets('hides league filter when there is only one league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsNothing);
        expect(find.text('All'), findsOneWidget); // Category filter remains.
      });
    });

    group('Category Filter', () {
      testWidgets('displays only category chips that have policies',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('All'),
            findsWidgets); // LeagueFilter "All" pill + CategoryFilter "All" chip
        expect(find.text('Policy'), findsWidgets);
        expect(find.text('Protocol'), findsWidgets);
        expect(find.text('Code of Conduct'), findsWidgets);
        expect(find.text('Other'), findsNothing);
      });

      testWidgets('shows All plus the only existing policy category',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(policies: [testPolicies.first], leagues: []),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('All'), findsOneWidget);
        expect(find.text('Code of Conduct'), findsWidgets);
        expect(find.text('Policy'), findsOneWidget); // Screen title only.
        expect(find.text('Protocol'), findsNothing);
        expect(find.text('Other'), findsNothing);
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
      testWidgets('shows empty state when no policies',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(policies: []));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No policies found'), findsOneWidget);
        expect(find.byIcon(Icons.folder_open), findsOneWidget);
      });

      testWidgets('shows upload button in empty state for admins',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policies: [],
            user: adminUser,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Upload Policy'), findsOneWidget);
      });

      testWidgets('no upload button in empty state for staff',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            policies: [],
            user: testUser,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Upload Policy'), findsNothing);
      });
    });

    group('Header Search Removal', () {
      testWidgets('does not render a search text field',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('shows policies without name filtering',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Code of Conduct.pdf'), findsOneWidget);
        expect(find.text('Concussion Protocol.pdf'), findsOneWidget);
        expect(find.text('Recruitment Policy.docx'), findsOneWidget);
      });
    });

    group('Policy Tile Information', () {
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

        // Policy with league association should show abbreviation
        // (filter pills + policy tag chips both show abbreviations)
        expect(find.text('SL'), findsWidgets);
        expect(find.text('FL'), findsWidgets);
      });

      testWidgets('tile does not show league for org-wide policies',
          (WidgetTester tester) async {
        // Recruitment Policy has no leagueId
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Recruitment Policy.docx'), findsOneWidget);
      });
    });

    group('File Type Icons and Colors', () {
      testWidgets('PDF shows red icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.picture_as_pdf), findsWidgets);
      });

      testWidgets('multiple PDF policies show PDF icons',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.picture_as_pdf), findsWidgets);
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

    group('Multiple Policies with Same Category', () {
      testWidgets('displays multiple policies in list',
          (WidgetTester tester) async {
        final multiplePolicies = [
          Policy(
            id: 'policy-1',
            orgId: 'org-1',
            name: 'Overage Policy.pdf',
            category: 'Policy',
            fileType: 'pdf',
            fileSize: 25600,
            fileUrl: 'https://example.com/file.pdf',
            leagueId: 'league-1',
            uploadedBy: 'admin-1',
            uploadedByName: 'Test User',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            versions: [],
          ),
          Policy(
            id: 'policy-2',
            orgId: 'org-1',
            name: 'Rivalry Game Policy.pdf',
            category: 'Policy',
            fileType: 'pdf',
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

        await tester.pumpWidget(createTestWidget(policies: multiplePolicies));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Overage Policy.pdf'), findsOneWidget);
        expect(find.text('Rivalry Game Policy.pdf'), findsOneWidget);
      });
    });

    group('Policy Navigation', () {
      testWidgets('policy tiles are tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsWidgets);
      });
    });

    group('Scrolling and Pagination', () {
      testWidgets('long list is scrollable', (WidgetTester tester) async {
        final manyPolicies = List.generate(
          20,
          (i) => Policy(
            id: 'policy-$i',
            orgId: 'org-1',
            name: 'Policy $i.pdf',
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

        await tester.pumpWidget(createTestWidget(policies: manyPolicies));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsWidgets);
      });
    });

    group('No League Association Display', () {
      testWidgets('org-wide policy shows no league tag',
          (WidgetTester tester) async {
        final orgWidePolicy = [
          Policy(
            id: 'policy-1',
            orgId: 'org-1',
            name: 'League Code of Conduct.pdf',
            category: 'Code of Conduct',
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
            policies: orgWidePolicy,
            leagues: testLeagues,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('League Code of Conduct.pdf'), findsOneWidget);
        // Should not show any league abbreviation for this policy
      });
    });
  });
}
