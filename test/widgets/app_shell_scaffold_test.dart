import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
