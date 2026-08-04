import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_glass.dart';

void main() {
  group('AppGlassSurface', () {
    testWidgets('exposes button semantics and handles taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppGlassSurface(
              semanticLabel: 'Open card',
              onTap: () => taps += 1,
              child: const Text('Card'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Card')),
        matchesSemantics(
          label: 'Open card',
          isButton: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Card'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('shows restrained press feedback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AppGlassSurface(
              onTap: () {},
              child: const Text('Card'),
            ),
          ),
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Card')));
      await tester.pump(const Duration(milliseconds: 140));

      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('does not add interaction motion to static surfaces',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: AppGlassSurface(child: Text('Static card')),
          ),
        ),
      );

      expect(find.byType(AnimatedScale), findsNothing);
    });
  });
}
