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
              showBackButton: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppGlassSurface), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
      expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
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
