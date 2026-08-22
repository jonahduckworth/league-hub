import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../core/design_system.dart';
import '../core/scroll_behavior.dart';
import 'app_glass.dart';
import 'glass_bottom_nav.dart';
import 'app_shell_header.dart';

// The 40pt header row already includes 12pt of bottom padding. Pull scrollable
// content into that padding so every primary page keeps the same compact 4pt
// header-to-content relationship as Home without touching the safe-area inset.
const double appShellHeaderContentSpacing = -AppSpacing.xs;
const double appShellBottomNavSpacing = 20;
const double appShellScrollEndClearance = 40;

double appShellBottomPadding(BuildContext context, {double extra = 8}) {
  return MediaQuery.viewPaddingOf(context).bottom +
      AppShellNavigationScope.bottomPaddingOf(context) +
      appShellScrollEndClearance +
      extra;
}

double appShellHeaderHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top +
      appShellHeaderRowHeight(context) +
      12;
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

class AppShellScaffold extends StatefulWidget {
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
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  final ValueNotifier<double> _verticalScrollOffset = ValueNotifier(0);

  @override
  void dispose() {
    _verticalScrollOffset.dispose();
    super.dispose();
  }

  bool _trackVerticalScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final pixels = notification.metrics.pixels;
    final nextOffset = pixels < 0 ? 0.0 : pixels;
    if ((_verticalScrollOffset.value - nextOffset).abs() >= 0.5) {
      _verticalScrollOffset.value = nextOffset;
    }
    return false;
  }

  Widget _scrollingTopLayer(Widget child) {
    return ValueListenableBuilder<double>(
      valueListenable: _verticalScrollOffset,
      child: child,
      builder: (context, offset, child) => Transform.translate(
        offset: Offset(0, -offset),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fabBottom = MediaQuery.viewPaddingOf(context).bottom +
        AppShellNavigationScope.bottomPaddingOf(context) +
        44;
    final pinnedTop = appShellHeaderHeight(context) + widget.topSpacing;
    final stickyTop = pinnedTop +
        (widget.pinnedContent != null
            ? widget.pinnedContentHeight + widget.pinnedSpacing
            : 0);
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
              child: NotificationListener<ScrollNotification>(
                onNotification: _trackVerticalScroll,
                child: ScrollConfiguration(
                  behavior: const LeagueHubScrollBehavior(),
                  child: widget.child,
                ),
              ),
            ),
          ),
          if (showHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: widget.topFadeHeight,
              child: _scrollingTopLayer(const _AppShellTopFade()),
            ),
          if (showHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _scrollingTopLayer(widget.header),
            ),
          if (widget.pinnedContent != null && showHeader)
            Positioned(
              top: pinnedTop,
              left: 0,
              right: 0,
              child: _scrollingTopLayer(widget.pinnedContent!),
            ),
          if (widget.stickyContent != null)
            Positioned(
              top: stickyTop,
              left: 0,
              right: 0,
              child: _scrollingTopLayer(
                _AppShellContentFade(
                  routeOpacity: contentOpacity,
                  child: widget.stickyContent!,
                ),
              ),
            ),
          if (widget.floatingActionButton != null)
            Positioned(
              right: 16,
              bottom: fabBottom,
              child: _AppShellContentFade(
                routeOpacity: contentOpacity,
                child: widget.floatingActionButton!,
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
    return Opacity(
      opacity: routeOpacity.clamp(0.0, 1.0).toDouble(),
      child: child,
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

/// Stable frame used for both forward and reverse shell route transitions.
///
/// Only the visual values change while navigating. Keeping this widget tree
/// intact prevents nested pages from remounting or restarting their reveal
/// animation when a pop begins.
class AppShellRouteTransitionFrame extends StatelessWidget {
  final double pageOpacity;
  final double contentOpacity;
  final bool showHeader;
  final Object transitionKey;
  final Offset translation;
  final double scale;
  final Widget child;

  const AppShellRouteTransitionFrame({
    super.key,
    required this.pageOpacity,
    required this.contentOpacity,
    required this.showHeader,
    required this.transitionKey,
    required this.translation,
    required this.scale,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: pageOpacity.clamp(0.0, 1.0).toDouble(),
      child: AppShellRouteVisualScope(
        contentOpacity: contentOpacity.clamp(0.0, 1.0).toDouble(),
        showHeader: showHeader,
        child: AppShellContentFadeScope(
          transitionKey: transitionKey,
          child: FractionalTranslation(
            translation: translation,
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        ),
      ),
    );
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
