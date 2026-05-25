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
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (showBackButton) ...[
                            _HeaderBackButton(
                              fallbackLocation: backFallbackLocation,
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (leadingIcon != null) ...[
                            Icon(
                              leadingIcon,
                              color: AppGlassColors.ink.withValues(alpha: 0.9),
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppGlassColors.ink,
                                height: 1.15,
                              ),
                            ),
                          ),
                          if (hasTrailingMark) ...[
                            const SizedBox(width: 12),
                            AppHeaderLogoMark(
                              imageUrl: leadingImageUrl,
                              label: leadingLabel ?? title,
                              size: 34,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Row(mainAxisSize: MainAxisSize.min, children: actions),
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
    return SizedBox(
      width: 36,
      height: 36,
      child: Tooltip(
        message: 'Back',
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 19,
          color: AppGlassColors.ink.withValues(alpha: 0.92),
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallbackLocation);
            }
          },
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
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: tooltip == null
              ? iconChild
              : Tooltip(message: tooltip!, child: iconChild),
        ),
      ),
    );
  }
}
