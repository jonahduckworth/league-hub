import 'package:flutter/material.dart';

class LeagueHubScrollBehavior extends MaterialScrollBehavior {
  const LeagueHubScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
