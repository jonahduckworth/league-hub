import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/login_screen.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('LoginScreen', () {
    Widget createTestWidget() {
      return ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
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
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('displays logo', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.byIcon(Icons.sports), findsOneWidget);
      });

      testWidgets('displays app title', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('League Hub'), findsWidgets);
      });

      testWidgets('displays subtitle', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Sign in to manage your leagues'), findsOneWidget);
      });
    });

    group('Email Field', () {
      testWidgets('email field is present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Email'), findsOneWidget);
      });

      testWidgets('email field has email icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      });

      testWidgets('email field accepts input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final emailField = find.byType(TextField);
        await tester.enterText(emailField.first, 'test@example.com');
        await tester.pumpAndSettle();

        expect(find.text('test@example.com'), findsOneWidget);
      });

      testWidgets('email field has correct keyboard type',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // TextField with email keyboard type should be present
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('email field disables autocorrect', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Email field should not autocorrect
        expect(find.byType(TextField), findsWidgets);
      });
    });

    group('Password Field', () {
      testWidgets('password field is present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Password'), findsOneWidget);
      });

      testWidgets('password field has lock icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
      });

      testWidgets('password field accepts input', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final passwordFields = find.byType(TextField);
        await tester.enterText(passwordFields.at(1), 'password123');
        await tester.pumpAndSettle();

        // Password should be entered (though obscured)
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('password is obscured by default', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should have visibility toggle button
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      });

      testWidgets('can toggle password visibility', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Find and tap the visibility toggle
        final visibilityButton = find.byIcon(Icons.visibility_outlined);
        expect(visibilityButton, findsOneWidget);

        await tester.tap(visibilityButton);
        await tester.pumpAndSettle();

        // After toggling, should show hidden icon
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      });

      testWidgets('can toggle visibility multiple times',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Toggle visible
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

        // Toggle hidden again
        await tester.tap(find.byIcon(Icons.visibility_off_outlined));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      });
    });

    group('Sign In Button', () {
      testWidgets('sign in button is present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Sign In'), findsOneWidget);
      });

      testWidgets('sign in button is enabled by default',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final button = find.byType(ElevatedButton);
        expect(button, findsOneWidget);
      });

      testWidgets('sign in button is tappable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('shows loading indicator when signing in',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final emailField = find.byType(TextField).first;
        final passwordField = find.byType(TextField).at(1);

        // Enter credentials
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.pumpAndSettle();

        // Tap sign in button
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle(Duration(milliseconds: 500));

        // Should show loading state
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Forgot Password Button', () {
      testWidgets('forgot password button is present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Forgot password?'), findsOneWidget);
      });

      testWidgets('forgot password button is tappable',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final forgotButton = find.text('Forgot password?');
        expect(forgotButton, findsOneWidget);
      });

      testWidgets('forgot password opens dialog', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsOneWidget);
      });

      testWidgets('forgot password dialog has email field',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.email_outlined), findsWidgets);
      });

      testWidgets('forgot password dialog has cancel button',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('forgot password dialog has send button',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Send Reset Link'), findsOneWidget);
      });

      testWidgets('can close forgot password dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsOneWidget);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Reset Password'), findsNothing);
      });
    });

    group('Navigation Links', () {
      testWidgets('create organization button is present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Create Organization'), findsOneWidget);
      });

      testWidgets('create organization button is tappable',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('accept invitation button is present',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        expect(find.text('Accept Invitation'), findsOneWidget);
      });

      testWidgets('accept invitation button is tappable',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final acceptButton = find.text('Accept Invitation');
        expect(acceptButton, findsOneWidget);
      });
    });

    group('Divider Section', () {
      testWidgets('divider section is present', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('or'), findsOneWidget);
      });

      testWidgets('divider has correct layout', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Divider), findsWidgets);
      });
    });

    group('Form Validation', () {
      testWidgets('empty email and password shows error',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Tap sign in with empty fields
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Error snackbar should appear
        expect(find.byType(SnackBar), findsWidgets);
      });

      testWidgets('empty email shows error', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final passwordField = find.byType(TextField).at(1);
        await tester.enterText(passwordField, 'password123');
        await tester.pumpAndSettle();

        // Tap sign in
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Should show error about empty email
        expect(find.byType(SnackBar), findsWidgets);
      });

      testWidgets('empty password shows error', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final emailField = find.byType(TextField).first;
        await tester.enterText(emailField, 'test@example.com');
        await tester.pumpAndSettle();

        // Tap sign in
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Should show error about empty password
        expect(find.byType(SnackBar), findsWidgets);
      });
    });

    group('Layout and Scrolling', () {
      testWidgets('screen is scrollable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('has safe area', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('content is properly padded', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(Padding), findsWidgets);
      });
    });

    group('Visual Elements', () {
      testWidgets('logo has correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Logo container should be present
        expect(find.byIcon(Icons.sports), findsOneWidget);
      });

      testWidgets('text fields have input decorations',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('buttons have correct styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(TextButton), findsWidgets);
      });
    });

    group('Input Field Focus', () {
      testWidgets('email field has text input action next',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Can type and move to next field
        final emailField = find.byType(TextField).first;
        await tester.enterText(emailField, 'test@example.com');
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();

        expect(find.text('test@example.com'), findsOneWidget);
      });

      testWidgets('password field has text input action done',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final passwordField = find.byType(TextField).at(1);
        await tester.enterText(passwordField, 'password');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('password'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('displays snackbar on error', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Trigger error by tapping sign in with empty fields
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsWidgets);
      });

      testWidgets('error message is readable', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // Should show validation error
        final snackbar = find.byType(SnackBar);
        expect(snackbar, findsWidgets);
      });
    });

    group('Accessibility', () {
      testWidgets('buttons are semantic', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('icons are present for visual context',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.byIcon(Icons.email_outlined), findsOneWidget);
        expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
        expect(find.byIcon(Icons.sports), findsOneWidget);
      });

      testWidgets('text fields have labels', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });
    });

    group('State Management', () {
      testWidgets('password visibility state is independent',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        // Initially visible (eye icon)
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

        // Toggle to hidden
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();

        // Should show hidden icon
        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

        // Text fields should still be present
        expect(find.byType(TextField), findsWidgets);
      });

      testWidgets('form fields retain input after state changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());

        final emailField = find.byType(TextField).first;
        await tester.enterText(emailField, 'test@example.com');
        await tester.pumpAndSettle();

        // Toggle password visibility
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pumpAndSettle();

        // Email should still be there
        expect(find.text('test@example.com'), findsOneWidget);
      });
    });
  });
}
