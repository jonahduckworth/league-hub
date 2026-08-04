import 'package:flutter/material.dart';

enum AppPopTransitionLayer {
  none,
  outgoing,
  revealed,
}

AppPopTransitionLayer appPopTransitionLayer({
  required AnimationStatus primaryStatus,
  required AnimationStatus secondaryStatus,
}) {
  if (primaryStatus == AnimationStatus.reverse) {
    return AppPopTransitionLayer.outgoing;
  }
  if (secondaryStatus == AnimationStatus.reverse) {
    return AppPopTransitionLayer.revealed;
  }
  return AppPopTransitionLayer.none;
}

double appPopPageOpacity({
  required AppPopTransitionLayer layer,
  required double primaryValue,
  required bool disableAnimations,
}) {
  switch (layer) {
    case AppPopTransitionLayer.none:
    case AppPopTransitionLayer.revealed:
      return 1;
    case AppPopTransitionLayer.outgoing:
      if (disableAnimations) return 0;
      return primaryValue.clamp(0.0, 1.0).toDouble();
  }
}
