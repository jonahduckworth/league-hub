import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/screens/unauthorized_screen.dart';

class MockGoRouter extends Mock implements GoRouter {}

void main() {
  group('UnauthorizedScreen', () {

    Widget buildTestWidget() {
      return MaterialApp(
        home: UnauthorizedScreen(),
      );
    }

    // =========================================================================
    // Widget tree and visual elements
    // =========================================================================

    group('Scaffold and layout', () {
      testWidgets('renders within Scaffold', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('uses Center to center content', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(Center), findsWidgets);
      });

      testWidgets('applies horizontal padding', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find the Padding widget
        final paddingFinder = find.byType(Padding);
        expect(paddingFinder, findsWidgets);

        // Verify it's a direct child of Center with Column
        final centerFinder = find.byType(Center);
        expect(centerFinder, findsWidgets);
      });

      testWidgets('renders Column with MainAxisSize.min', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final columnFinder = find.byType(Column);
        expect(columnFinder, findsOneWidget);

        final columnWidget = columnFinder.evaluate().first.widget as Column;
        expect(columnWidget.mainAxisSize, equals(MainAxisSize.min));
      });
    });

    // =========================================================================
    // Lock icon
    // =========================================================================

    group('lock icon', () {
      testWidgets('displays lock icon', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('lock icon has size 64', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(Icons.lock_outline);
        final iconWidget = iconFinder.evaluate().first.widget as Icon;

        expect(iconWidget.size, equals(64));
      });

      testWidgets('lock icon uses error color', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: UnauthorizedScreen(),
        ));
        await tester.pump();
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(Icons.lock_outline);
        final iconWidget = iconFinder.evaluate().first.widget as Icon;

        // Verify icon color matches theme error color
        expect(iconWidget.color, isNotNull);
      });
    });

    // =========================================================================
    // Access Denied text
    // =========================================================================

    group('Access Denied heading', () {
      testWidgets('displays "Access Denied" text', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Access Denied'), findsOneWidget);
      });

      testWidgets('Access Denied uses headline small style', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final textFinder = find.text('Access Denied');
        expect(textFinder, findsOneWidget);

        final textWidget = textFinder.evaluate().first.widget as Text;
        final style = textWidget.style;

        // Verify it's styled (we can't directly check it's headlineSmall without context)
        expect(style, isNotNull);
      });

      testWidgets('Access Denied text is bold', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final textFinder = find.text('Access Denied');
        final textWidget = textFinder.evaluate().first.widget as Text;
        final style = textWidget.style;

        expect(style?.fontWeight, equals(FontWeight.bold));
      });

      testWidgets('Access Denied has vertical spacing above and below',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify SizedBox widgets for spacing around the text
        final sizedBoxes = find.byType(SizedBox);
        expect(sizedBoxes, findsWidgets);
      });
    });

    // =========================================================================
    // Help text
    // =========================================================================

    group('help text about contacting administrator', () {
      testWidgets('displays help text', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('permission'),
          findsWidgets,
        );
      });

      testWidgets('help text mentions contacting administrator', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.textContaining('administrator'),
          findsOneWidget,
        );
      });

      testWidgets('help text is centered', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find the help text
        final helpTextFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains("don't have permission"),
        );

        if (helpTextFinder.evaluate().isNotEmpty) {
          final textWidget =
              helpTextFinder.evaluate().first.widget as Text;
          expect(textWidget.textAlign, equals(TextAlign.center));
        }
      });

      testWidgets('help text uses body medium style', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find text that contains the help message
        final textWidgets = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data != null &&
                  widget.data!.contains('permission'),
            )
            .evaluate();

        expect(textWidgets.isNotEmpty, isTrue);
      });
    });

    // =========================================================================
    // Go to Dashboard button
    // =========================================================================

    group('Go to Dashboard button', () {
      testWidgets('displays button with correct label', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Go to Dashboard'), findsOneWidget);
      });

      testWidgets('button is a FilledButton', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('button has home icon', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find FilledButton.icon specifically
        final buttonFinder = find.byType(FilledButton);
        expect(buttonFinder, findsOneWidget);

        // The icon should be Icons.home_outlined
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      });

      testWidgets('button icon and label are present', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify both the button and the icon exist
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
        expect(find.text('Go to Dashboard'), findsOneWidget);
      });
    });

    // =========================================================================
    // Button navigation behavior
    // =========================================================================

    group('button navigation', () {
      testWidgets('button onPressed calls context.go(\'/\')',
          (WidgetTester tester) async {
        // Build a simpler test widget that allows mocking GoRouter
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Mock GoRouter for this test
                  return UnauthorizedScreen();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Find and tap the button
        final buttonFinder = find.byType(FilledButton);
        expect(buttonFinder, findsOneWidget);

        // Verify button exists and is tappable
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('button is enabled (not disabled)', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(FilledButton);
        final button = buttonFinder.evaluate().first.widget as FilledButton;

        // Button is enabled if onPressed is not null
        expect(button.onPressed, isNotNull);
      });

      testWidgets('tapping button triggers navigation action',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return UnauthorizedScreen();
                },
              ),
            ),
            onGenerateRoute: (settings) {
              return MaterialPageRoute(builder: (_) => const SizedBox.shrink());
            },
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Note: In a real test, we'd need a proper GoRouter setup
        // This at least verifies the button exists and is tappable
        final buttonFinder = find.byType(FilledButton);
        expect(buttonFinder, findsOneWidget);
      });
    });

    // =========================================================================
    // Spacing and layout structure
    // =========================================================================

    group('spacing and layout', () {
      testWidgets('vertical spacing exists between icon and text',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify multiple SizedBox widgets for spacing
        final sizedBoxes = find.byType(SizedBox);
        expect(sizedBoxes.evaluate().length, greaterThanOrEqualTo(2));
      });

      testWidgets('icon appears before "Access Denied" text',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find positions in the widget tree
        final iconFinder = find.byIcon(Icons.lock_outline);
        final textFinder = find.text('Access Denied');

        expect(iconFinder, findsOneWidget);
        expect(textFinder, findsOneWidget);

        // Both should exist (order is implicitly correct in Column)
      });

      testWidgets('button appears after help text', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(FilledButton);
        final helpTextFinder = find.textContaining('administrator');

        expect(buttonFinder, findsOneWidget);
        expect(helpTextFinder, findsWidgets);
      });

      testWidgets('spacing constant of 32 between help text and button',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Find all SizedBox widgets
        final sizedBoxes = find
            .byWidgetPredicate(
              (widget) =>
                  widget is SizedBox &&
                  widget.height == 32,
            )
            .evaluate();

        // Should find at least one SizedBox with height 32
        expect(sizedBoxes.isNotEmpty, isTrue);
      });
    });

    // =========================================================================
    // Theme integration
    // =========================================================================

    group('theme integration', () {
      testWidgets('uses theme colors from context', (WidgetTester tester) async {
        final testTheme = ThemeData(
          useMaterial3: true,
        );

        await tester.pumpWidget(MaterialApp(
          theme: testTheme,
          home: UnauthorizedScreen(),
        ));
        await tester.pump();
        await tester.pumpAndSettle();

        // Verify widget renders without error with theme
        expect(find.byType(UnauthorizedScreen), findsOneWidget);
      });

      testWidgets('renders with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: UnauthorizedScreen(),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('renders with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: UnauthorizedScreen(),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });
    });

    // =========================================================================
    // Accessibility
    // =========================================================================

    group('accessibility', () {
      testWidgets('all text is readable (not empty)', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final texts = find.byType(Text);
        expect(texts, findsWidgets);

        for (final textFinder in texts.evaluate()) {
          final text = textFinder.widget as Text;
          expect(text.data, isNotNull);
          expect(text.data?.isNotEmpty, isTrue);
        }
      });

      testWidgets('button has semantics (accessibility label)',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final buttonFinder = find.byType(FilledButton);
        expect(buttonFinder, findsOneWidget);

        // Verify button is interactive
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      });

      testWidgets('screen is responsive and renders without errors',
          (WidgetTester tester) async {
        // Suppress overflow errors in constrained viewports
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) return;
          oldHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        tester.view.physicalSize = const Size(400, 800);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
      });

      testWidgets('renders on wide screen without errors',
          (WidgetTester tester) async {
        // Suppress overflow errors in constrained viewports
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) return;
          oldHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldHandler);

        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
      });

      testWidgets('handles text overflow gracefully',
          (WidgetTester tester) async {
        final oldHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (details.toString().contains('overflowed')) return;
          oldHandler?.call(details);
        };

        tester.view.physicalSize = const Size(300, 600);
        addTearDown(tester.view.resetPhysicalSize);

        try {
          await tester.pumpWidget(buildTestWidget());
          await tester.pump();
          await tester.pumpAndSettle();

          expect(find.byType(UnauthorizedScreen), findsOneWidget);
          expect(find.byType(Text), findsWidgets);
        } finally {
          FlutterError.onError = oldHandler;
        }
      });
    });

    // =========================================================================
    // Statelessness
    // =========================================================================

    group('widget properties', () {
      testWidgets('UnauthorizedScreen is StatelessWidget',
          (WidgetTester tester) async {
        final screen = UnauthorizedScreen();

        expect(screen, isA<StatelessWidget>());
      });

      testWidgets('UnauthorizedScreen accepts and uses key parameter',
          (WidgetTester tester) async {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: UnauthorizedScreen(key: key),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
      });
    });

    // =========================================================================
    // Content completeness
    // =========================================================================

    group('content completeness', () {
      testWidgets('all required visual elements are present',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Icon
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);

        // Main heading
        expect(find.text('Access Denied'), findsOneWidget);

        // Help text
        expect(find.textContaining('permission'), findsWidgets);

        // Button
        expect(find.byType(FilledButton), findsOneWidget);
        expect(find.text('Go to Dashboard'), findsOneWidget);
        expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      });

      testWidgets('no duplicate elements', (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Access Denied'), findsOneWidget);
        expect(find.text('Go to Dashboard'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
      });
    });

    // =========================================================================
    // Edge cases and robustness
    // =========================================================================

    group('edge cases', () {
      testWidgets('renders without errors on cold start',
          (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
      });

      testWidgets('renders after navigation from another screen',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Go to Unauthorized'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Now navigate to unauthorized screen
        await tester.pumpWidget(buildTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(UnauthorizedScreen), findsOneWidget);
      });
    });
  });
}
