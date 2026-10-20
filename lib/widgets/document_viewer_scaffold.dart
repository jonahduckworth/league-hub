import 'package:flutter/material.dart';

import 'app_glass.dart';
import 'app_shell_header.dart';

/// A fixed app header above a zoomable document viewport. Document gestures
/// stay inside the viewport rather than scrolling or covering the header.
class DocumentViewerScaffold extends StatelessWidget {
  final String title;
  final String leagueName;
  final String? leagueLogoUrl;
  final IconData icon;
  final List<Widget> actions;
  final Widget child;

  const DocumentViewerScaffold({
    super.key,
    required this.title,
    this.leagueName = 'League Hub',
    this.leagueLogoUrl,
    this.icon = Icons.description_outlined,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AppGlassBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(children: [
          SafeArea(
            top: false,
            bottom: false,
            child: AppShellHeader(
              title: title,
              leadingIcon: icon,
              leadingImageUrl: leagueLogoUrl,
              leadingLabel: leagueName,
              showBackButton: true,
              // Viewers are pushed on Navigator outside the GoRouter page stack.
              onBack: () => Navigator.of(context).maybePop(),
              actions: actions,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SafeArea(top: false, child: child),
            ),
          ),
        ]),
      ),
    ]);
  }
}
