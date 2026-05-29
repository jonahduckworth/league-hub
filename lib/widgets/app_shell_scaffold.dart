import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'app_glass.dart';
import 'app_shell_header.dart';

const double appShellHeaderContentSpacing = 12;

double appShellBottomPadding(BuildContext context, {double extra = 8}) {
  return MediaQuery.paddingOf(context).bottom + extra;
}

double appShellHeaderHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + 52;
}

double appShellTopPadding(
  BuildContext context, {
  double extra = appShellHeaderContentSpacing,
  double stickyHeight = 0,
  double stickySpacing = 12,
}) {
  return appShellHeaderHeight(context) +
      extra +
      (stickyHeight > 0 ? stickyHeight + stickySpacing : 0);
}

class AppShellScaffold extends StatelessWidget {
  final AppShellHeader header;
  final Widget child;
  final Widget? stickyContent;
  final Widget? floatingActionButton;
  final double topSpacing;
  final double stickySpacing;
  final double topFadeHeight;

  const AppShellScaffold({
    super.key,
    required this.header,
    required this.child,
    this.stickyContent,
    this.floatingActionButton,
    this.topSpacing = appShellHeaderContentSpacing,
    this.stickySpacing = 12,
    this.topFadeHeight = 128,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final stickyTop = appShellHeaderHeight(context) + topSpacing;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: child),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topFadeHeight,
            child: const _AppShellTopFade(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: header,
          ),
          if (stickyContent != null)
            Positioned(
              top: stickyTop,
              left: 0,
              right: 0,
              child: stickyContent!,
            ),
          if (floatingActionButton != null)
            Positioned(
              right: 16,
              bottom: bottomInset + 20,
              child: floatingActionButton!,
            ),
        ],
      ),
    );
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
