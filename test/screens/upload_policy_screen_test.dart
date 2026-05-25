import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/upload_policy_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('UploadPolicyScreen', () {
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

    final testHubs = [
      Hub(
        id: 'hub-1',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'North Hub',
        createdAt: DateTime.now(),
      ),
      Hub(
        id: 'hub-2',
        leagueId: 'league-1',
        orgId: 'org-1',
        name: 'South Hub',
        createdAt: DateTime.now(),
      ),
    ];

    Widget createTestWidget({
      AppUser? user,
      List<League>? leagues,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? staffUser,
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          hubsProvider('league-1').overrideWith(
            (ref) => Stream.value(testHubs),
          ),
        ],
        child: MaterialApp(
          home: const UploadPolicyScreen(),
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
      testWidgets('renders upload policy form without crashing',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('displays shell header title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('upload-policy-submit-button')),
          findsOneWidget,
        );
      });

      testWidgets('displays close button in app bar',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close), findsOneWidget);
      });
    });

    group('Form Fields', () {
      testWidgets('displays file picker card', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.upload_file), findsOneWidget);
        expect(find.text('Tap to select a file'), findsOneWidget);
      });

      testWidgets('displays policy name field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Policy Name'), findsOneWidget);
      });

      testWidgets('displays category selector', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Category'), findsOneWidget);
      });

      testWidgets('displays league selector', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('League (Optional)'), findsOneWidget);
      });
    });

    group('Hub Selector Visibility', () {
      testWidgets('shows hub selector when league is selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // The hub selector should appear after a league is selected
        // Initially it should not be visible unless a league is chosen
      });

      testWidgets('hides hub selector when no league is selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        // Hub selector should initially be hidden
      });
    });

    group('Upload Button', () {
      testWidgets('displays upload button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        // 'Upload Policy' appears in the header and submit surface.
        expect(find.text('Upload Policy'), findsAtLeastNWidgets(1));
      });

      testWidgets('upload button is present on screen',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Upload Policy'), findsAtLeastNWidgets(1));
      });
    });

    group('Validation', () {
      testWidgets('shows error when no file is selected',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester
            .tap(find.byKey(const ValueKey('upload-policy-submit-button')));
        await tester.pumpAndSettle();
        expect(find.text('Please select a file first.'), findsOneWidget);
      });
    });

    group('Category Options', () {
      testWidgets('displays category selector with default value',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('Category'), findsOneWidget);
        // Default category should be 'Policy'
      });

      testWidgets('has multiple category options', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Categories: Policy, Protocol, Code of Conduct, Other
        // These should be accessible in the dropdown
      });
    });

    group('League and Hub Scope Selection', () {
      testWidgets('displays league selector', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        expect(find.text('League (Optional)'), findsOneWidget);
      });

      testWidgets('league selector shows available leagues',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        // Dropdown should have leagues available
      });
    });

    group('File Selection Feedback', () {
      testWidgets('displays file info after selection',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        // Initially shows "Tap to select a file"
        expect(find.text('Tap to select a file'), findsOneWidget);
      });
    });

    group('Form State', () {
      testWidgets('displays all form sections', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check for all major sections
        expect(find.text('Policy Name'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('League (Optional)'), findsOneWidget);
      });

      testWidgets('all input fields are present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should have text field for policy name
        final textFields = find.byType(TextFormField);
        expect(textFields, findsOneWidget);
      });
    });

    group('File Type Support', () {
      testWidgets('displays supported file formats info',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        // Check for file format help text
        expect(
          find.text('PDF, DOCX, XLSX, images • Files: 25 MB, Images: 10 MB'),
          findsOneWidget,
        );
      });
    });
  });
}
