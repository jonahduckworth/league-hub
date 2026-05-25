import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../core/utils.dart';
import 'app_glass.dart';

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
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      flex: 10,
                      child: _HeaderTitlePill(
                        title: title,
                        leadingIcon: leadingIcon,
                      ),
                    ),
                    const Spacer(),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
                    ],
                    if (hasTrailingMark) ...[
                      const SizedBox(width: 10),
                      AppHeaderLogoMark(
                        imageUrl: leadingImageUrl,
                        label: leadingLabel ?? title,
                        size: 44,
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

        return AppGlassSurface(
          height: 40,
          padding: EdgeInsets.fromLTRB(
            leadingIcon == null ? 16 : 8,
            0,
            14,
            0,
          ),
          radius: 20,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: AppGlassColors.aqua.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppGlassColors.aqua.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Icon(
                    leadingIcon,
                    color: AppGlassColors.ink.withValues(alpha: 0.94),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTitleWidth),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppGlassColors.ink,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.contain,
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
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

  const _HeaderBackButton({required this.fallbackLocation});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Back',
      child: AppGlassSurface(
        width: 44,
        height: 44,
        padding: EdgeInsets.zero,
        radius: 22,
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(fallbackLocation);
          }
        },
        child: Center(
          child: Icon(
            Icons.arrow_back_ios_new,
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

  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconChild = SizedBox(
      width: 40,
      height: 40,
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 19),
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
