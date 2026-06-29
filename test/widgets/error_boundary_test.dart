import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/error_boundary.dart';

void main() {
  group('ErrorBoundary', () {
    late FlutterExceptionHandler? originalOnError;

    setUp(() {
      originalOnError = FlutterError.onError;
    });

    tearDown(() {
      FlutterError.onError = originalOnError;
    });

    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: Scaffold(
          body: ErrorBoundary(
            child: child ?? const Center(child: Text('Normal Content')),
          ),
        ),
      );
    }

    testWidgets('renders child widget when no error',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('shows fallback UI and retries after reported error',
        (WidgetTester tester) async {
      FlutterErrorDetails? forwardedError;
      FlutterError.onError = (details) {
        forwardedError = details;
      };

      await tester.pumpWidget(createTestWidget());

      final details = FlutterErrorDetails(
        exception: Exception('Boom'),
        stack: StackTrace.current,
      );
      FlutterError.reportError(details);

      await tester.pump();
      await tester.pump();

      expect(forwardedError, same(details));
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Exception: Boom'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('does not show fallback for keyboard key-up mismatch',
        (WidgetTester tester) async {
      FlutterErrorDetails? forwardedError;
      FlutterError.onError = (details) {
        forwardedError = details;
      };

      await tester.pumpWidget(createTestWidget());

      final details = FlutterErrorDetails(
        exception: FlutterError(
          'A KeyUpEvent is dispatched, but the state shows that the physical key is not pressed.',
        ),
        stack: StackTrace.current,
      );
      FlutterError.reportError(details);

      await tester.pump();
      await tester.pump();

      expect(forwardedError, same(details));
      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('does not show fallback for snackbar layout assertions',
        (WidgetTester tester) async {
      FlutterErrorDetails? forwardedError;
      FlutterError.onError = (details) {
        forwardedError = details;
      };

      await tester.pumpWidget(createTestWidget());

      final details = FlutterErrorDetails(
        exception: FlutterError('Floating SnackBar presented off screen.'),
        stack: StackTrace.current,
      );
      FlutterError.reportError(details);

      await tester.pump();
      await tester.pump();

      expect(forwardedError, same(details));
      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('does not show fallback for semantics layout assertions',
        (WidgetTester tester) async {
      FlutterErrorDetails? forwardedError;
      FlutterError.onError = (details) {
        forwardedError = details;
      };

      await tester.pumpWidget(createTestWidget());

      final details = FlutterErrorDetails(
        exception: FlutterError(
          "'package:flutter/src/rendering/object.dart': Failed assertion: line 5737 pos 14: '!childSemantics.renderObject._needsLayout': is not true.",
        ),
        stack: StackTrace.current,
      );
      FlutterError.reportError(details);

      await tester.pump();
      await tester.pump();

      expect(forwardedError, same(details));
      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('does not show fallback for RenderFlex overflow warnings',
        (WidgetTester tester) async {
      FlutterErrorDetails? forwardedError;
      FlutterError.onError = (details) {
        forwardedError = details;
      };

      await tester.pumpWidget(createTestWidget());

      final details = FlutterErrorDetails(
        exception: FlutterError(
          'A RenderFlex overflowed by 67 pixels on the bottom.',
        ),
        stack: StackTrace.current,
      );
      FlutterError.reportError(details);

      await tester.pump();
      await tester.pump();

      expect(forwardedError, same(details));
      expect(find.text('Normal Content'), findsOneWidget);
      expect(find.text('Something went wrong'), findsNothing);
    });

    testWidgets('restores previous FlutterError handler on dispose',
        (WidgetTester tester) async {
      void originalHandler(FlutterErrorDetails details) {}
      FlutterError.onError = originalHandler;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      expect(FlutterError.onError, same(originalHandler));
    });
  });

  group('appErrorWidget', () {
    testWidgets('renders fallback details', (WidgetTester tester) async {
      final details = FlutterErrorDetails(
        exception: StateError('Broken widget'),
        stack: StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: appErrorWidget(details),
        ),
      );

      expect(find.text('Oops! Something broke.'), findsOneWidget);
      expect(find.text('Bad state: Broken widget'), findsOneWidget);
      final icon =
          tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
      expect(icon.color, AppGlassColors.gold);
    });

    testWidgets('uses app background and muted detail styling',
        (WidgetTester tester) async {
      final details = FlutterErrorDetails(
        exception: Exception('Oops'),
        stack: StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: appErrorWidget(details),
        ),
      );

      final material = tester.widget<Material>(find.byType(Material).first);
      expect(material.color, Colors.transparent);

      final detailText = tester.widget<Text>(find.text('Exception: Oops'));
      expect(detailText.maxLines, 3);
      expect(detailText.overflow, TextOverflow.ellipsis);
    });
  });
}
