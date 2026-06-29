import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/scroll_behavior.dart';

void main() {
  group('LeagueHubScrollBehavior', () {
    testWidgets('uses clamping physics to avoid iOS over-bounce',
        (tester) async {
      const behavior = LeagueHubScrollBehavior();

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: behavior,
          home: const SizedBox.shrink(key: Key('scroll-test-root')),
        ),
      );

      final physics = behavior.getScrollPhysics(
        tester.element(find.byKey(const Key('scroll-test-root'))),
      );

      expect(physics, isA<ClampingScrollPhysics>());
    });
  });
}
