import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/design_system.dart';

/// A restrained entrance used for cards and rows throughout the app.
///
/// Delays are deliberately capped so long lists never feel sluggish. Motion
/// is removed when the platform accessibility setting disables animations.
class AppMotionReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double verticalOffset;
  final bool enabled;

  const AppMotionReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.verticalOffset = 12,
    this.enabled = true,
  });

  @override
  State<AppMotionReveal> createState() => _AppMotionRevealState();
}

class _AppMotionRevealState extends State<AppMotionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _delayTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.emphasized,
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

    final stagger = widget.index.clamp(0, 6) * 38;
    if (stagger == 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: stagger), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = AppMotion.emphasizedCurve.transform(_controller.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(
              0,
              ui.lerpDouble(widget.verticalOffset, 0, progress)!,
            ),
            child: Transform.scale(
              alignment: Alignment.topCenter,
              scale: ui.lerpDouble(0.992, 1, progress)!,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
