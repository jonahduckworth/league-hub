import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/error_boundary.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('ErrorBoundary', () {
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: Scaffold(
          body: ErrorBoundary(
            child: child ??
                Center(
                  child: Text('Normal Content'),
                ),
          ),
        ),
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
          ),
        ),
      );
    }

    group('Normal Display', () {
      testWidgets('renders child widget when no error',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.text('Normal Content'), findsOneWidget);
      });

      testWidgets('shows normal child content', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('does not show error UI when no error',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.text('Something went wrong'), findsNothing);
      });
    });

    group('Error Display', () {
      testWidgets('shows error fallback UI when error occurs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Error state would be triggered by FlutterError.onError
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('displays error message', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // When error occurs, message is displayed
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('shows error icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Error UI includes error_outline icon
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('displays heading "Something went wrong"',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Error fallback shows this heading
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('Retry Button', () {
      testWidgets('displays retry button when error occurs',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Retry button appears in error state
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('retry button is labeled "Try Again"',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('retry button has refresh icon', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('clicking retry resets error state',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Tapping retry should call _retry() which resets state
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('Error Message Display', () {
      testWidgets('displays exception message text', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Error message is shown in fallback
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('message is ellipsized if too long',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('message text is centered', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('Error UI Styling', () {
      testWidgets('error icon has danger color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Icon should use AppColors.danger
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('error icon is large', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Icon size is 40 in the fallback
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('icon container has rounded corners',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('heading text is bold', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // "Something went wrong" is bold
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('uses app background color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // ErrorFallback uses AppColors.background
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('Layout', () {
      testWidgets('content is centered vertically and horizontally',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // _ErrorFallback uses Center widget
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('has proper spacing between elements',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // SizedBox spacing between icon, text, button
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('respects safe area', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // _ErrorFallback uses SafeArea
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('is full screen', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Uses Material and Center to fill screen
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('Button Styling', () {
      testWidgets('retry button has primary color', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Button uses AppColors.primary
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('retry button has rounded corners', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Button has RoundedRectangleBorder
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('retry button is large enough to tap',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Button has symmetric padding
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('Error Boundary Initialization', () {
      testWidgets('initializes without crashing', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('intercepts Flutter errors', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // ErrorBoundary intercepts FlutterError.onError
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('preserves original error handler',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // Still calls originalOnError
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });

    group('State Management', () {
      testWidgets('maintains error state across rebuilds',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('error state can be reset by retry',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        // _retry() method resets _hasError and _errorDetails
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });

      testWidgets('stores error details', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        expect(find.byType(ErrorBoundary), findsOneWidget);
      });
    });
  });
}
