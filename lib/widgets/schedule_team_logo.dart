import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/image_cache.dart';
import '../core/utils.dart';
import 'app_glass.dart';

class ScheduleTeamLogo extends StatelessWidget {
  final String teamName;
  final String? imageUrl;
  final double size;
  final Color fallbackTextColor;

  const ScheduleTeamLogo({
    super.key,
    required this.teamName,
    this.imageUrl,
    this.size = 28,
    this.fallbackTextColor = AppGlassColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final cacheDimension = thumbnailCacheDimension(context, size);
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Padding(
          padding: EdgeInsets.all(size * 0.1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.27),
            child: url != null && url.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    memCacheWidth: cacheDimension,
                    memCacheHeight: cacheDimension,
                    maxWidthDiskCache: cacheDimension,
                    maxHeightDiskCache: cacheDimension,
                    fadeInDuration: const Duration(milliseconds: 140),
                    placeholder: (_, __) => _fallback(),
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Text(
          AppUtils.getInitials(teamName),
          maxLines: 1,
          style: TextStyle(
            color: fallbackTextColor,
            fontSize: size * 0.27,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}
