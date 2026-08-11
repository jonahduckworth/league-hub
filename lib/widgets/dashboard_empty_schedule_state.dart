import 'package:flutter/material.dart';

import '../core/design_system.dart';

class DashboardEmptyScheduleState extends StatelessWidget {
  static const double maxTextScale = 1.4;

  final bool accessibilityLayout;
  final Color titleColor;
  final Color bodyColor;

  const DashboardEmptyScheduleState({
    super.key,
    required this.accessibilityLayout,
    required this.titleColor,
    required this.bodyColor,
  });

  static bool shouldUseAccessibilityLayout(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return scaler.scale(13) > 13 * maxTextScale;
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
      child: FractionallySizedBox(
        key: const ValueKey('next-game-empty-content'),
        widthFactor: accessibilityLayout ? 1 : 0.72,
        alignment: Alignment.centerLeft,
        child: Column(
          key: const ValueKey('next-game-empty-text-column'),
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _UpcomingCalendarMark(),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No upcoming games',
              style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New games will appear here when the schedule is published.',
              style: TextStyle(
                color: bodyColor,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCalendarMark extends StatelessWidget {
  const _UpcomingCalendarMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Color(0xFFDCEAFF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.calendar_month_outlined,
        color: Color(0xFF1D5A9E),
        size: 25,
      ),
    );
  }
}
