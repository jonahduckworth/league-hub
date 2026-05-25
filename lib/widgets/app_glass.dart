import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

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

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: surface,
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
