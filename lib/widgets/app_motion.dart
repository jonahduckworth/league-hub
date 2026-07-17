import 'package:flutter/material.dart';

import '../core/design_system.dart';

/// A quiet fade used for content that appears after its screen is mounted.
///
/// Motion is removed when the platform accessibility setting disables
/// animations. Items begin together so long lists never feel staged or slow.
class AppMotionReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final bool enabled;

  const AppMotionReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.enabled = true,
  });

  @override
  State<AppMotionReveal> createState() => _AppMotionRevealState();
}

class _AppMotionRevealState extends State<AppMotionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.standard,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.enabled || reduceMotion) {
      _controller.value = 1;
      return;
    }

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = AppMotion.screenFadeCurve.transform(_controller.value);
        return Opacity(
          opacity: progress,
          child: child,
        );
      },
    );
  }
}
