import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../core/scroll_behavior.dart';
import 'app_glass.dart';
import 'glass_bottom_nav.dart';
import 'app_shell_header.dart';

const double appShellHeaderContentSpacing = 12;
const double appShellBottomNavSpacing = 20;
const double appShellScrollEndClearance = 40;
const _appShellContentFadeDuration = Duration(milliseconds: 620);
const _appShellRevealSoftness = 0.28;
const _appShellRevealLift = 8.0;
const _defaultAppShellContentFadeKey = Object();

double appShellBottomPadding(BuildContext context, {double extra = 8}) {
  return MediaQuery.viewPaddingOf(context).bottom +
      AppShellNavigationScope.bottomPaddingOf(context) +
      appShellScrollEndClearance +
      extra;
}

double appShellHeaderHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + 52;
}

double appShellTopPadding(
  BuildContext context, {
  double extra = appShellHeaderContentSpacing,
  double pinnedHeight = 0,
  double pinnedSpacing = 12,
  double stickyHeight = 0,
  double stickySpacing = 12,
}) {
  return appShellHeaderHeight(context) +
      extra +
      (pinnedHeight > 0 ? pinnedHeight + pinnedSpacing : 0) +
      (stickyHeight > 0 ? stickyHeight + stickySpacing : 0);
}

class AppShellScaffold extends StatelessWidget {
  final AppShellHeader header;
  final Widget child;
  final Widget? pinnedContent;
  final Widget? stickyContent;
  final Widget? floatingActionButton;
  final double topSpacing;
  final double pinnedContentHeight;
  final double pinnedSpacing;
  final double stickySpacing;
  final double topFadeHeight;

  const AppShellScaffold({
    super.key,
    required this.header,
    required this.child,
    this.pinnedContent,
    this.stickyContent,
    this.floatingActionButton,
    this.topSpacing = appShellHeaderContentSpacing,
    this.pinnedContentHeight = 0,
    this.pinnedSpacing = 12,
    this.stickySpacing = 12,
    this.topFadeHeight = 128,
  });

  @override
  Widget build(BuildContext context) {
    final fabBottom = MediaQuery.viewPaddingOf(context).bottom +
        AppShellNavigationScope.bottomPaddingOf(context) +
        44;
    final pinnedTop = appShellHeaderHeight(context) + topSpacing;
    final stickyTop = pinnedTop +
        (pinnedContent != null ? pinnedContentHeight + pinnedSpacing : 0);
    final routeVisual = AppShellRouteVisualScope.maybeOf(context);
    final showHeader = routeVisual?.showHeader ?? true;
    final contentOpacity = routeVisual?.contentOpacity ?? 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: _AppShellContentFade(
              routeOpacity: contentOpacity,
              child: ScrollConfiguration(
                behavior: const LeagueHubScrollBehavior(),
                child: child,
              ),
            ),
          ),
          if (showHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topFadeHeight,
              child: const _AppShellTopFade(),
            ),
          if (showHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: header,
            ),
          if (pinnedContent != null && showHeader)
            Positioned(
              top: pinnedTop,
              left: 0,
              right: 0,
              child: pinnedContent!,
            ),
          if (stickyContent != null)
            Positioned(
              top: stickyTop,
              left: 0,
              right: 0,
              child: _AppShellContentFade(
                routeOpacity: contentOpacity,
                child: stickyContent!,
              ),
            ),
          if (floatingActionButton != null)
            Positioned(
              right: 16,
              bottom: fabBottom,
              child: _AppShellContentFade(
                routeOpacity: contentOpacity,
                child: floatingActionButton!,
              ),
            ),
        ],
      ),
    );
  }
}

class _AppShellContentFade extends StatelessWidget {
  final Widget child;
  final double routeOpacity;

  const _AppShellContentFade({
    required this.child,
    required this.routeOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return Opacity(
        opacity: routeOpacity.clamp(0.0, 1.0).toDouble(),
        child: child,
      );
    }
    final transitionKey =
        AppShellContentFadeScope.maybeTransitionKeyOf(context) ??
            _defaultAppShellContentFadeKey;

    return TweenAnimationBuilder<double>(
      key: ValueKey(transitionKey),
      tween: Tween(begin: 0, end: 1),
      duration: _appShellContentFadeDuration,
      curve: Curves.easeOut,
      child: child,
      builder: (context, progress, child) {
        final revealOpacity = (progress * 1.25).clamp(0.0, 1.0).toDouble();
        final opacity =
            (routeOpacity * revealOpacity).clamp(0.0, 1.0).toDouble();
        final revealProgress = Curves.easeOutCubic.transform(progress);
        final lift = ui.lerpDouble(_appShellRevealLift, 0, revealProgress)!;

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, lift),
            child: _AppShellTopDownReveal(
              progress: revealProgress,
              child: child!,
            ),
          ),
        );
      },
    );
  }
}

class _AppShellTopDownReveal extends StatelessWidget {
  final double progress;
  final Widget child;

  const _AppShellTopDownReveal({
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return child;
    if (progress >= 1) return child;

    return ClipRect(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          final revealEdge = ui.lerpDouble(
            -_appShellRevealSoftness,
            1 + _appShellRevealSoftness,
            progress,
          )!;
          final fadeStart =
              (revealEdge - _appShellRevealSoftness).clamp(0.0, 1.0).toDouble();
          final fadeEnd = revealEdge.clamp(0.0, 1.0).toDouble();

          if (fadeEnd <= 0) {
            return const LinearGradient(
              colors: [Colors.transparent, Colors.transparent],
            ).createShader(bounds);
          }

          if (fadeStart >= 1) {
            return const LinearGradient(
              colors: [Colors.white, Colors.white],
            ).createShader(bounds);
          }

          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Colors.white,
              Colors.white,
              Colors.transparent,
              Colors.transparent,
            ],
            stops: [
              0,
              fadeStart,
              fadeEnd,
              1,
            ],
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

class AppShellRouteVisualScope extends InheritedWidget {
  final double contentOpacity;
  final bool showHeader;

  const AppShellRouteVisualScope({
    super.key,
    required this.contentOpacity,
    required this.showHeader,
    required super.child,
  });

  static AppShellRouteVisualScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppShellRouteVisualScope>();
  }

  @override
  bool updateShouldNotify(AppShellRouteVisualScope oldWidget) {
    return contentOpacity != oldWidget.contentOpacity ||
        showHeader != oldWidget.showHeader;
  }
}

class AppShellContentFadeScope extends InheritedWidget {
  final Object transitionKey;

  const AppShellContentFadeScope({
    super.key,
    required this.transitionKey,
    required super.child,
  });

  static Object? maybeTransitionKeyOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppShellContentFadeScope>()
        ?.transitionKey;
  }

  @override
  bool updateShouldNotify(AppShellContentFadeScope oldWidget) {
    return oldWidget.transitionKey != transitionKey;
  }
}

class AppShellNavigationScope extends InheritedWidget {
  final double bottomPadding;

  const AppShellNavigationScope({
    super.key,
    required super.child,
    this.bottomPadding =
        leagueHubGlassBottomNavBarHeight + appShellBottomNavSpacing,
  });

  static double bottomPaddingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppShellNavigationScope>()
            ?.bottomPadding ??
        0;
  }

  @override
  bool updateShouldNotify(AppShellNavigationScope oldWidget) {
    return bottomPadding != oldWidget.bottomPadding;
  }
}

class _AppShellTopFade extends StatelessWidget {
  const _AppShellTopFade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, 0.42, 1],
            ).createShader(bounds);
          },
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppGlassColors.pageTop,
                    Color(0xD902050B),
                    Color(0x5202050B),
                    Color(0x0002050B),
                  ],
                  stops: [0, 0.34, 0.72, 1],
                ),
              ),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
