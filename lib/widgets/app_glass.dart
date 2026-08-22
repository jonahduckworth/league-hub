import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/design_system.dart';

class AppGlassColors {
  static const Color pageTop = Color(0xFF02050B);
  static const Color pageMid = Color(0xFF061426);
  static const Color pageWarm = Color(0xFF0B2140);
  static const Color pageBottom = Color(0xFF01030A);
  static const Color ink = Color(0xFFF7FAF8);
  static const Color inkSecondary = Color(0xFFC8D3CC);
  static const Color inkMuted = Color(0xFF8FA09A);
  static const Color aqua = Color(0xFF67E8D4);
  static const Color gold = Color(0xFFF4C96B);
  static const Color rose = Color(0xFFFF7C8E);
  static const Color border = Color(0x33FFFFFF);
}

const _surfaceSettings = LiquidGlassSettings(
  thickness: 36,
  blur: 7,
  glassColor: Color(0x24FFFFFF),
  lightIntensity: 1.2,
  saturation: 1.18,
  refractiveIndex: 1.18,
  chromaticAberration: 0.18,
);

/// Shader-free glass for repeated scrolling surfaces.
///
/// The liquid-glass package recommends its minimal tier for screens with many
/// list cards so the cumulative shader cost stays flat while the frosted glass
/// appearance is preserved.
const appGlassListSurfaceQuality = GlassQuality.minimal;

class AppGlassBackground extends StatelessWidget {
  const AppGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppGlassColors.pageTop,
            AppGlassColors.pageMid,
            AppGlassColors.pageWarm,
            AppGlassColors.pageBottom,
          ],
          stops: [0, 0.42, 0.72, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x24177BFF),
                    Color(0x000B65FF),
                    Color(0x163CE7F4),
                  ],
                  stops: [0, 0.48, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x00061528),
                    Color(0x2608172B),
                    Color(0x0002050B),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppGlassRouteBackground extends StatelessWidget {
  final Widget child;

  const AppGlassRouteBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      background: const AppGlassBackground(),
      enableBackgroundSampling: false,
      edgeToEdge: true,
      statusBarStyle: GlassStatusBarStyle.light,
      child: child,
    );
  }
}

class AppGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final GlassQuality quality;
  final LiquidGlassSettings? settings;
  final Clip clipBehavior;
  final String? semanticLabel;
  final bool enableHaptics;
  final double pressedScale;

  const AppGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 20,
    this.width,
    this.height,
    this.onTap,
    this.quality = GlassQuality.standard,
    this.settings,
    this.clipBehavior = Clip.antiAlias,
    this.semanticLabel,
    this.enableHaptics = true,
    this.pressedScale = 0.985,
  });

  @override
  Widget build(BuildContext context) {
    final surface = GlassContainer(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: settings ?? _surfaceSettings,
      quality: quality,
      clipBehavior: clipBehavior,
      child: child,
    );

    if (onTap == null) return surface;

    return _InteractiveGlassSurface(
      onTap: onTap!,
      semanticLabel: semanticLabel,
      enableHaptics: enableHaptics,
      pressedScale: pressedScale,
      child: surface,
    );
  }
}

class _InteractiveGlassSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool enableHaptics;
  final double pressedScale;

  const _InteractiveGlassSurface({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    required this.enableHaptics,
    required this.pressedScale,
  });

  @override
  State<_InteractiveGlassSurface> createState() =>
      _InteractiveGlassSurfaceState();
}

class _InteractiveGlassSurfaceState extends State<_InteractiveGlassSurface> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  void _handleTap() {
    if (widget.enableHaptics) HapticFeedback.selectionClick();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: _handleTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _isPressed ? widget.pressedScale : 1,
          duration: AppMotion.accessible(context, AppMotion.fast),
          curve: AppMotion.enter,
          child: widget.child,
        ),
      ),
    );
  }
}

class AppGlassIconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const AppGlassIconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.accentColor = AppGlassColors.aqua,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      semanticLabel: label,
      height: 136,
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppGlassColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppGlassColors.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AppGlassFloatingActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const AppGlassFloatingActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppGlassColors.aqua,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppGlassSurface(
        width: 56,
        height: 56,
        padding: EdgeInsets.zero,
        radius: 28,
        onTap: onTap,
        semanticLabel: tooltip,
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}
