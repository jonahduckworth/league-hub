import 'package:flutter/material.dart';

/// Shared visual and interaction tokens for the League Hub experience.
///
/// Keeping these values centralized prevents screens and shared widgets from
/// drifting into subtly different spacing, radius, and motion languages.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 1);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration emphasized = Duration(milliseconds: 240);
  static const Duration route = Duration(milliseconds: 280);
  static const Duration routeReverse = Duration(milliseconds: 240);

  static const Curve enter = Cubic(0.2, 0, 0, 1);
  static const Curve exit = Cubic(0.4, 0, 1, 1);
  static const Curve emphasizedCurve = enter;
  static const Curve screenFadeCurve = Cubic(0.33, 0, 0.67, 1);

  static Duration accessible(
    BuildContext context,
    Duration duration,
  ) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false
        ? instant
        : duration;
  }

  static AnimationStyle overlayStyle(BuildContext context) {
    return AnimationStyle(
      duration: accessible(context, emphasized),
      reverseDuration: accessible(context, standard),
    );
  }
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double control = 12;
  static const double card = 20;
  static const double feature = 24;
  static const double pill = 999;
}
