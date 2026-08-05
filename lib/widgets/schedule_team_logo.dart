import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/utils.dart';
import 'app_glass.dart';

class ScheduleTeamLogo extends StatelessWidget {
  final String teamName;
  final String? imageUrl;
  final double size;

  const ScheduleTeamLogo({
    super.key,
    required this.teamName,
    this.imageUrl,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(size * 0.27),
          border: Border.all(
            color: AppGlassColors.inkMuted.withValues(alpha: 0.2),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 140),
                placeholder: (_, __) => _fallback(),
                errorWidget: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Center(
        child: Text(
          AppUtils.getInitials(teamName),
          maxLines: 1,
          style: TextStyle(
            color: AppGlassColors.ink,
            fontSize: size * 0.27,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}
