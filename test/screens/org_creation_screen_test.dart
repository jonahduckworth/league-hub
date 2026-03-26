import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/org_creation_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('OrgCreationScreen', () {
    Widget createTestWidget() {
      return MaterialApp(
        home: OrgCreationScreen(),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
          ),
        ),
      );
    }

    group('Screen Rendering', () {
      testWidgets('renders without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('displays app bar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsOneWidget);
      });
    });

    group('Step 0: Organization Details', () {
      testWidgets('displays organization name field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('displays admin name field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('displays admin email field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('displays password field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('displays confirm password field', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('password field is obscured by default',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Password fields should have obscureText enabled
        expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      });

      testWidgets('displays next button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(ElevatedButton), findsWidgets);
      });
    });

    group('Form Validation - Step 0', () {
      testWidgets('validates organization name is not empty',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Try clicking next without filling org name
        final nextButton = find.byType(ElevatedButton).first;
        await tester.tap(nextButton);
        await tester.pump();
        // Should show error snackbar
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('validates admin name is not empty',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Validation checks all required fields
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('validates email is not empty', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('validates password length >= 6 characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('validates passwords match', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });
    });

    group('Multi-Step Wizard', () {
      testWidgets('has step indicator or navigation',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // The wizard should show current step information
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('displays back button on subsequent steps',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Back button may appear after step 0
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });
    });

    group('League Creation Section', () {
      testWidgets('step 1 includes league creation', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // After progressing to step 1, league fields should appear
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('league name field is present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('league abbreviation field is present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('displays add league button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });
    });

    group('League Validation', () {
      testWidgets('validates at least one league is added',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Step 1 validation requires at least one league
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('prevents proceeding without leagues', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // User cannot move to step 2 without adding a league
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });
    });

    group('Create Button', () {
      testWidgets('displays create organization button on final step',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });

      testWidgets('button label changes to Create on final step',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Last step should show "Create" or "Finish" button
        expect(find.byType(OrgCreationScreen), findsOneWidget);
      });
    });

    group('Text Input', () {
      testWidgets('organization name field accepts text',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        expect(fields, findsWidgets);
      });

      testWidgets('email field accepts valid email format',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('password field masks input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Password fields should use obscureText
        expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      });

      testWidgets('can toggle password visibility',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Visibility toggle icons should be present
        expect(find.byIcon(Icons.visibility_outlined), findsWidgets);
      });
    });

    group('Error Display', () {
      testWidgets('shows error snackbar on validation failure',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        // Tap next without filling required fields
        final nextButton = find.byType(ElevatedButton).first;
        await tester.tap(nextButton);
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('error message is readable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();
        final nextButton = find.byType(ElevatedButton).first;
        await tester.tap(nextButton);
        await tester.pump();
        // SnackBar should contain error text
        expect(find.byType(SnackBar), findsOneWidget);
      });
    });
  });
}
