import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/scroll_behavior.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/app_shell_scaffold.dart';

void main() {
  group('AppShellScaffold', () {
    testWidgets('uses the shared header content spacing by default',
        (WidgetTester tester) async {
      const topInset = 47.0;
      double? computedTopPadding;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: topInset),
            ),
            child: Builder(
              builder: (context) {
                computedTopPadding = appShellTopPadding(context);

                return const AppShellScaffold(
                  header: AppShellHeader(
                    title: 'Policy',
                    showBackButton: true,
                  ),
                  stickyContent: SizedBox(
                    key: Key('sticky-content'),
                    height: 36,
                  ),
                  child: SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expectedTop = topInset + 52 + appShellHeaderContentSpacing;
      expect(computedTopPadding, expectedTop);
      expect(
        tester.getTopLeft(find.byKey(const Key('sticky-content'))).dy,
        expectedTop,
      );
    });

    testWidgets(
        'bottom padding uses real safe area instead of scaffold padding',
        (WidgetTester tester) async {
      double? computedBottomPadding;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: 874),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: AppShellNavigationScope(
              bottomPadding: 84,
              child: Builder(
                builder: (context) {
                  computedBottomPadding = appShellBottomPadding(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      expect(computedBottomPadding, 34 + 84 + appShellScrollEndClearance + 8);
    });

    testWidgets('fades in content below the header',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShellScaffold(
            header: AppShellHeader(title: 'Policy'),
            stickyContent: SizedBox(
              key: Key('sticky-content'),
              height: 36,
            ),
            child: SizedBox.expand(key: Key('page-content')),
          ),
        ),
      );

      final stickyOpacityFinder = find
          .ancestor(
            of: find.byKey(const Key('sticky-content')),
            matching: find.byType(Opacity),
          )
          .first;
      final contentOpacityFinder = find
          .ancestor(
            of: find.byKey(const Key('page-content')),
            matching: find.byType(Opacity),
          )
          .first;

      expect(tester.widget<Opacity>(stickyOpacityFinder).opacity, 0);
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 0);

      await tester.pumpAndSettle();

      expect(tester.widget<Opacity>(stickyOpacityFinder).opacity, 1);
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);
    });

    testWidgets('restarts content fade when transition scope changes',
        (WidgetTester tester) async {
      Widget buildScopedShell(Object transitionKey) {
        return MaterialApp(
          home: AppShellContentFadeScope(
            transitionKey: transitionKey,
            child: const AppShellScaffold(
              header: AppShellHeader(title: 'Policy'),
              child: SizedBox.expand(key: Key('page-content')),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildScopedShell('policy-list'));
      var contentOpacityFinder = find
          .ancestor(
            of: find.byKey(const Key('page-content')),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 0);

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);

      await tester.pumpWidget(buildScopedShell('policy-detail'));
      contentOpacityFinder = find
          .ancestor(
            of: find.byKey(const Key('page-content')),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 0);

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);
    });

    testWidgets('route visual scope only affects page content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShellRouteVisualScope(
            contentOpacity: 0.25,
            showHeader: true,
            child: AppShellScaffold(
              header: AppShellHeader(title: 'Policy'),
              child: SizedBox.expand(key: Key('page-content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final contentOpacityFinder = find
          .ancestor(
            of: find.byKey(const Key('page-content')),
            matching: find.byType(Opacity),
          )
          .first;

      expect(find.text('Policy'), findsOneWidget);
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 0.25);
    });

    testWidgets('route visual scope can hide outgoing header only',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShellRouteVisualScope(
            contentOpacity: 1,
            showHeader: false,
            child: AppShellScaffold(
              header: AppShellHeader(title: 'Old Header'),
              pinnedContent: SizedBox(
                key: Key('pinned-content'),
                height: 40,
              ),
              pinnedContentHeight: 40,
              child: SizedBox.expand(key: Key('outgoing-content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Old Header'), findsNothing);
      expect(find.byKey(const Key('pinned-content')), findsNothing);
      expect(find.byKey(const Key('outgoing-content')), findsOneWidget);
    });

    testWidgets('applies clamping scroll behavior to page content',
        (WidgetTester tester) async {
      const scrollContentKey = Key('shell-scroll-content');

      await tester.pumpWidget(
        const MaterialApp(
          home: AppShellScaffold(
            header: AppShellHeader(title: 'Scrollable'),
            child: Builder(
              builder: _scrollBehaviorProbeBuilder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(scrollContentKey));
      final behavior = ScrollConfiguration.of(context);
      final physics = behavior.getScrollPhysics(context);

      expect(behavior, isA<LeagueHubScrollBehavior>());
      expect(physics, isA<ClampingScrollPhysics>());
    });
  });
}

Widget _scrollBehaviorProbeBuilder(BuildContext context) {
  return ListView(
    key: const Key('shell-scroll-content'),
    children: const [
      SizedBox(height: 1200),
    ],
  );
}
