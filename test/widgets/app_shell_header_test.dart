import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/app_shell_header.dart';

void main() {
  group('AppShellHeader', () {
    testWidgets('wraps destination header controls in glass surfaces',
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

      expect(find.byType(AppGlassSurface), findsNWidgets(3));
      expect(find.byType(AppHeaderLogoMark), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('SL'), findsOneWidget);
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
      expect(titleText.style?.fontSize, 14);
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
  });
}
