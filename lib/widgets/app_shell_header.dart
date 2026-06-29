import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/utils.dart';
import 'app_glass.dart';

const _headerLogoSize = 40.0;

class AppShellHeader extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final String? leadingImageUrl;
  final String? leadingLabel;
  final bool showBackButton;
  final String backFallbackLocation;
  final List<Widget> actions;
  final Widget? bottom;
  final Widget? content;
  final IconData backIcon;
  final VoidCallback? onBack;

  const AppShellHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.leadingImageUrl,
    this.leadingLabel,
    this.showBackButton = false,
    this.backFallbackLocation = '/',
    this.actions = const [],
    this.bottom,
    this.content,
    this.backIcon = Icons.arrow_back_ios_new,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final hasBottom = bottom != null;
    final hasTrailingMark =
        (leadingImageUrl != null && leadingImageUrl!.isNotEmpty) ||
            (leadingLabel != null && leadingLabel!.isNotEmpty);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, topInset, 20, hasBottom ? 14 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content ??
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showBackButton) ...[
                      _HeaderBackButton(
                        fallbackLocation: backFallbackLocation,
                        icon: backIcon,
                        onTap: onBack,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _HeaderTitlePill(
                          title: title,
                          leadingIcon: leadingIcon,
                        ),
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ],
                    if (hasTrailingMark) ...[
                      const SizedBox(width: 10),
                      AppHeaderLogoMark(
                        imageUrl: leadingImageUrl,
                        label: leadingLabel ?? title,
                      ),
                    ],
                  ],
                ),
            if (hasBottom) ...[
              const SizedBox(height: 14),
              bottom!,
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderTitlePill extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;

  const _HeaderTitlePill({
    required this.title,
    required this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 104;
        final reservedWidth = leadingIcon == null ? 32.0 : 76.0;
        final maxTitleWidth =
            (availableWidth - reservedWidth).clamp(0.0, availableWidth);

        return AppHeaderPill(
          text: title,
          icon: leadingIcon,
          showIconBubble: leadingIcon != null,
          padding: EdgeInsets.fromLTRB(
            leadingIcon == null ? 16 : 8,
            0,
            14,
            0,
          ),
          iconSize: 15,
          maxTextWidth: maxTitleWidth,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppGlassColors.ink,
            height: 1.1,
          ),
        );
      },
    );
  }
}

class AppHeaderPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool showIconBubble;
  final EdgeInsetsGeometry padding;
  final TextStyle textStyle;
  final double height;
  final double radius;
  final double iconSize;
  final double iconBubbleSize;
  final double iconGap;
  final double? maxTextWidth;

  const AppHeaderPill({
    super.key,
    required this.text,
    this.icon,
    this.showIconBubble = false,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 14, 0),
    this.textStyle = const TextStyle(
      color: AppGlassColors.ink,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    this.height = 40,
    this.radius = 20,
    this.iconSize = 18,
    this.iconBubbleSize = 27,
    this.iconGap = 10,
    this.maxTextWidth,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      height: height,
      padding: padding,
      radius: radius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            if (showIconBubble)
              Container(
                width: iconBubbleSize,
                height: iconBubbleSize,
                decoration: BoxDecoration(
                  color: AppGlassColors.aqua.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppGlassColors.aqua.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppGlassColors.ink.withValues(alpha: 0.94),
                  size: iconSize,
                ),
              )
            else
              Icon(
                icon,
                color: textStyle.color ?? AppGlassColors.ink,
                size: iconSize,
              ),
            SizedBox(width: iconGap),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTextWidth ?? 240),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class AppHeaderLogoMark extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final double size;

  const AppHeaderLogoMark({
    super.key,
    required this.imageUrl,
    required this.label,
    this.size = _headerLogoSize,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return AppGlassSurface(
      width: size,
      height: size,
      padding: EdgeInsets.zero,
      radius: size / 2,
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? ClipOval(
              child: Padding(
                padding: EdgeInsets.all(size * 0.12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => _fallback(),
                  errorWidget: (_, __, ___) => _fallback(),
                ),
              ),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        AppUtils.getInitials(label),
        style: const TextStyle(
          color: AppGlassColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  final String fallbackLocation;
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderBackButton({
    required this.fallbackLocation,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: AppGlassSurface(
        width: _headerLogoSize,
        height: _headerLogoSize,
        padding: EdgeInsets.zero,
        radius: _headerLogoSize / 2,
        onTap: onTap ??
            () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(fallbackLocation);
              }
            },
        child: Center(
          child: Icon(
            icon,
            color: AppGlassColors.ink.withValues(alpha: 0.94),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class AppHeaderSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const AppHeaderSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppGlassColors.inkMuted),
          prefixIcon: const Icon(Icons.search, color: AppGlassColors.inkMuted),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                const BorderSide(color: AppGlassColors.aqua, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
    );
  }
}

class AppHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconChild = SizedBox(
      width: 40,
      height: 40,
      child: Icon(
        icon,
        color: color ?? Colors.white.withValues(alpha: 0.92),
        size: 19,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: tooltip == null
          ? AppGlassSurface(
              width: 40,
              height: 40,
              padding: EdgeInsets.zero,
              radius: 20,
              onTap: onPressed,
              child: iconChild,
            )
          : Tooltip(
              message: tooltip!,
              child: AppGlassSurface(
                width: 40,
                height: 40,
                padding: EdgeInsets.zero,
                radius: 20,
                onTap: onPressed,
                child: iconChild,
              ),
            ),
    );
  }
}
