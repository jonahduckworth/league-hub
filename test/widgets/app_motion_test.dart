import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/design_system.dart';
import 'package:league_hub/widgets/app_motion.dart';

void main() {
  test('back navigation uses the standard page speed', () {
    expect(AppMotion.routeReverse, AppMotion.standard);
  });

  group('AppMotionReveal', () {
    testWidgets('reveals content with opacity and movement', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AppMotionReveal(
            child: SizedBox(key: Key('content'), width: 80, height: 80),
          ),
        ),
      );

      final opacityFinder = find
          .ancestor(
            of: find.byKey(const Key('content')),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(opacityFinder).opacity, 0);

      await tester.pumpAndSettle();

      expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
    });

    testWidgets('skips motion when accessibility animations are disabled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: AppMotionReveal(
              index: 5,
              child: SizedBox(key: Key('content'), width: 80, height: 80),
            ),
          ),
        ),
      );

      final opacityFinder = find
          .ancestor(
            of: find.byKey(const Key('content')),
            matching: find.byType(Opacity),
          )
          .first;
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1);
    });
  });
}
