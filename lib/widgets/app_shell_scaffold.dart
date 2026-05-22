import 'package:flutter/material.dart';
import 'app_shell_header.dart';

double appShellBottomPadding(BuildContext context, {double extra = 8}) {
  return MediaQuery.paddingOf(context).bottom + extra;
}

double appShellHeaderHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + 52;
}

double appShellTopPadding(
  BuildContext context, {
  double extra = 20,
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

  const AppShellScaffold({
    super.key,
    required this.header,
    required this.child,
    this.stickyContent,
    this.floatingActionButton,
    this.topSpacing = 20,
    this.stickySpacing = 12,
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
