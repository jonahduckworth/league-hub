import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/design_system.dart';
import 'app_glass.dart';
import 'app_motion.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final useLightText =
        scaffoldColor.a == 0 || scaffoldColor.computeLuminance() < 0.35;
    final iconColor = useLightText
        ? AppGlassColors.inkMuted.withValues(alpha: 0.72)
        : AppColors.textMuted.withValues(alpha: 0.5);
    final titleColor =
        useLightText ? AppGlassColors.inkSecondary : AppColors.textSecondary;
    final subtitleColor =
        useLightText ? AppGlassColors.inkMuted : AppColors.textMuted;

    return Center(
      child: AppMotionReveal(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.feature),
                border: Border.all(color: iconColor.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
