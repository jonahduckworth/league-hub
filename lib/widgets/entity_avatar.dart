import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';

const entityIconOptions = <String, IconData>{
  'league': Icons.emoji_events_outlined,
  'hub': Icons.location_on_outlined,
  'team': Icons.groups_2_outlined,
  'forum': Icons.forum,
  'calendar': Icons.event_outlined,
  'trophy': Icons.emoji_events_outlined,
  'shield': Icons.shield_outlined,
};

IconData iconForEntityIconName(String? iconName, IconData fallback) {
  return entityIconOptions[iconName] ?? fallback;
}

class EntityAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? iconName;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;
  final Color color;
  final String? textFallback;

  const EntityAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.iconName,
    required this.fallbackIcon,
    this.size = 44,
    double? borderRadius,
    this.color = AppColors.primary,
    this.textFallback,
  }) : borderRadius = borderRadius ?? 12;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    if (iconName != null && iconName!.isNotEmpty) {
      return Icon(
        iconForEntityIconName(iconName, fallbackIcon),
        color: color,
        size: size * 0.5,
      );
    }

    return Center(
      child: Text(
        textFallback ?? AppUtils.getInitials(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}
