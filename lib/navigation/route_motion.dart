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

/// Returns a lightweight pop transition when the route stack is reversing.
///
/// The outgoing page is faded as one composited layer while the revealed page
/// is shown immediately. This avoids rebuilding glass-heavy descendants or
/// restarting their entrance animations during back navigation.
Widget? buildAppPopTransition({
  required BuildContext context,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final layer = appPopTransitionLayer(
    primaryStatus: animation.status,
    secondaryStatus: secondaryAnimation.status,
  );

  switch (layer) {
    case AppPopTransitionLayer.none:
      return null;
    case AppPopTransitionLayer.revealed:
      return child;
    case AppPopTransitionLayer.outgoing:
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
        return Opacity(opacity: 0, child: child);
      }
      return FadeTransition(
        opacity: animation,
        child: child,
      );
  }
}
