import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'app_shell_header.dart';

double appShellBottomPadding(BuildContext context, {double extra = 8}) {
  return MediaQuery.paddingOf(context).bottom + extra;
}

class AppShellScaffold extends StatelessWidget {
  final AppShellHeader header;
  final Widget child;
  final Widget? stickyContent;
  final Widget? floatingActionButton;
  final double overlap;
  final double topSpacing;
  final double stickySpacing;

  const AppShellScaffold({
    super.key,
    required this.header,
    required this.child,
    this.stickyContent,
    this.floatingActionButton,
    this.overlap = 32,
    this.topSpacing = 20,
    this.stickySpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              header,
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, -overlap),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: AppColors.background,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(30)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          SizedBox(height: topSpacing),
                          if (stickyContent != null) ...[
                            stickyContent!,
                            SizedBox(height: stickySpacing),
                          ],
                          Expanded(child: child),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
