import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/navigation/route_motion.dart';

void main() {
  group('appPopTransitionLayer', () {
    test('marks the reversing primary route as outgoing', () {
      expect(
        appPopTransitionLayer(
          primaryStatus: AnimationStatus.reverse,
          secondaryStatus: AnimationStatus.dismissed,
        ),
        AppPopTransitionLayer.outgoing,
      );
    });

    test('reveals the previous route immediately during pop', () {
      expect(
        appPopTransitionLayer(
          primaryStatus: AnimationStatus.completed,
          secondaryStatus: AnimationStatus.reverse,
        ),
        AppPopTransitionLayer.revealed,
      );
    });

    test('leaves forward navigation on the full motion path', () {
      expect(
        appPopTransitionLayer(
          primaryStatus: AnimationStatus.forward,
          secondaryStatus: AnimationStatus.dismissed,
        ),
        AppPopTransitionLayer.none,
      );
    });
  });

  testWidgets('hides the outgoing route immediately with reduced motion', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 140),
      value: 1,
    );
    animation.reverse();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              return buildAppPopTransition(
                context: context,
                animation: animation,
                secondaryAnimation: const AlwaysStoppedAnimation(0),
                child: const Text('Outgoing'),
              )!;
            },
          ),
        ),
      ),
    );

    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    animation.dispose();
  });
}
