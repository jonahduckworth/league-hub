import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/app_shell_header.dart';

void main() {
  group('AppShellHeader', () {
    for (final route in ['/', '/schedule', '/contacts', '/info', '/policy/p']) {
      for (final custom in [false, true]) {
        testWidgets(
            'header at $route has no Profile shortcut with custom=$custom',
            (tester) async {
          final router = GoRouter(initialLocation: route, routes: [
            GoRoute(
                path: route,
                builder: (_, __) => Scaffold(
                    body: AppShellHeader(
                        title: 'Home',
                        content: custom ? const Text('Welcome') : null))),
            GoRoute(
                path: '/profile',
                builder: (_, __) =>
                    const Scaffold(body: Text('Member profile'))),
          ]);
          addTearDown(router.dispose);
          await tester.pumpWidget(MaterialApp.router(routerConfig: router));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Profile'), findsNothing);
          expect(find.byIcon(Icons.account_circle_outlined), findsNothing);
          expect(find.text(custom ? 'Welcome' : 'Home'), findsOneWidget);
        });
      }
    }

    testWidgets('keeps destination title and league mark borderless',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppShellHeader(
              title: 'Announcements',
              leadingIcon: Icons.campaign_outlined,
              leadingLabel: 'Spring League',
              showBackButton: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppGlassSurface), findsOneWidget);
      expect(find.byType(AppHeaderLogoMark), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('SL'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Announcements'),
          matching: find.byType(AppGlassSurface),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byType(AppHeaderLogoMark),
          matching: find.byType(AppGlassSurface),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byType(AppHeaderLogoMark)).dx,
        greaterThan(tester.getTopLeft(find.text('Announcements')).dx),
      );
      expect(
        tester.getTopRight(find.byType(AppHeaderLogoMark)).dx,
        closeTo(
            tester.view.physicalSize.width / tester.view.devicePixelRatio - 20,
            0.1),
      );

      final logoMark =
          tester.widget<AppHeaderLogoMark>(find.byType(AppHeaderLogoMark));
      expect(logoMark.size, 40);
      expect(logoMark.label, 'Spring League');

      final backSurfaceFinder = find
          .ancestor(
            of: find.byIcon(Icons.arrow_back_ios_new),
            matching: find.byType(AppGlassSurface),
          )
          .first;
      final backSurface = tester.widget<AppGlassSurface>(backSurfaceFinder);
      expect(backSurface.width, 40);
      expect(backSurface.height, 40);
      expect(backSurface.radius, 20);

      final titleText = tester.widget<Text>(find.text('Announcements'));
      expect(titleText.style?.fontSize, 15);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    });

    testWidgets('keeps custom home header content unwrapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppShellHeader(
              title: 'League Hub',
              content: Text('Custom header'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom header'), findsOneWidget);
      expect(find.byType(AppGlassSurface), findsNothing);
    });

    for (final size in [
      const Size(320, 640),
      const Size(375, 812),
      const Size(812, 375)
    ]) {
      testWidgets('keeps the header stable at maximum text size on $size',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(
                textScaler: TextScaler.linear(3.2), disableAnimations: true),
            child: MaterialApp(
              home: Scaffold(
                body: AppShellHeader(
                  title: 'Events and tournament announcements',
                  leadingIcon: Icons.campaign_outlined,
                  leadingLabel: 'Junior Prospects Hockey League',
                  showBackButton: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
            find.text('Events and tournament announcements'), findsOneWidget);
        expect(find.byType(AppHeaderLogoMark), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
