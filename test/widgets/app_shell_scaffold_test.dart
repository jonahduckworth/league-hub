import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/scroll_behavior.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/app_shell_scaffold.dart';

void main() {
  group('AppShellScaffold', () {
    test('matches the Home header-to-content spacing', () {
      expect(appShellHeaderContentSpacing, -8);
    });

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

    testWidgets('header and top controls scroll away with page content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppShellScaffold(
            header: AppShellHeader(title: 'Messages'),
            stickyContent: SizedBox(
              key: Key('sticky-content'),
              height: 36,
            ),
            child: _ScrollableShellTestContent(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialHeaderTop = tester.getTopLeft(find.text('Messages')).dy;
      final initialStickyTop =
          tester.getTopLeft(find.byKey(const Key('sticky-content'))).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('Messages')).dy,
        lessThan(initialHeaderTop - 100),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('sticky-content'))).dy,
        lessThan(initialStickyTop - 100),
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

    testWidgets('does not stack a second fade under the route transition',
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

      expect(tester.widget<Opacity>(stickyOpacityFinder).opacity, 1);
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);

      await tester.pumpAndSettle();

      expect(tester.widget<Opacity>(stickyOpacityFinder).opacity, 1);
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);
    });

    testWidgets('transition scope changes do not restart scaffold content',
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
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);

      await tester.pumpWidget(buildScopedShell('policy-detail'));
      contentOpacityFinder = find
          .ancestor(
            of: find.byKey(const Key('page-content')),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(contentOpacityFinder).opacity, 1);

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

    testWidgets('route transition frame preserves page state during pop',
        (WidgetTester tester) async {
      var mountCount = 0;

      Widget buildFrame({required double pageOpacity}) {
        return MaterialApp(
          home: AppShellRouteTransitionFrame(
            pageOpacity: pageOpacity,
            contentOpacity: 1,
            showHeader: true,
            transitionKey: 'policy-detail',
            translation: Offset.zero,
            scale: 1,
            child: _MountProbe(onMount: () => mountCount += 1),
          ),
        );
      }

      await tester.pumpWidget(buildFrame(pageOpacity: 1));
      expect(mountCount, 1);

      await tester.pumpWidget(buildFrame(pageOpacity: 0.6));
      expect(mountCount, 1);
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

class _ScrollableShellTestContent extends StatelessWidget {
  const _ScrollableShellTestContent();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding:
          EdgeInsets.only(top: appShellTopPadding(context, stickyHeight: 36)),
      itemCount: 30,
      itemBuilder: (context, index) => SizedBox(
        height: 64,
        child: Text('Row $index'),
      ),
    );
  }
}

Widget _scrollBehaviorProbeBuilder(BuildContext context) {
  return ListView(
    key: const Key('shell-scroll-content'),
    children: const [
      SizedBox(height: 1200),
    ],
  );
}

class _MountProbe extends StatefulWidget {
  final VoidCallback onMount;

  const _MountProbe({required this.onMount});

  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
