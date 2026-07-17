import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/design_system.dart';
import 'package:league_hub/widgets/app_motion.dart';

void main() {
  test('app motion uses a deliberate interaction hierarchy', () {
    expect(AppMotion.fast, const Duration(milliseconds: 160));
    expect(AppMotion.standard, const Duration(milliseconds: 200));
    expect(AppMotion.emphasized, const Duration(milliseconds: 240));
    expect(AppMotion.route, const Duration(milliseconds: 280));
    expect(AppMotion.routeReverse, const Duration(milliseconds: 240));
  });

  testWidgets('overlay motion has a polished enter and quicker exit',
      (tester) async {
    late AnimationStyle style;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            style = AppMotion.overlayStyle(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(style.duration, AppMotion.emphasized);
    expect(style.reverseDuration, AppMotion.standard);
  });

  testWidgets('overlay motion respects reduced motion', (tester) async {
    late AnimationStyle style;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              style = AppMotion.overlayStyle(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(style.duration, AppMotion.instant);
    expect(style.reverseDuration, AppMotion.instant);
  });

  group('AppMotionReveal', () {
    testWidgets('reveals content with a quiet fade', (tester) async {
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
