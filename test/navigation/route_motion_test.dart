import 'package:flutter/animation.dart';
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
}
