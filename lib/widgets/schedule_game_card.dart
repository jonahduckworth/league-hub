import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/design_system.dart';
import '../models/schedule_event.dart';
import 'app_glass.dart';

String scheduleTimeLabel(ScheduleEvent event, {bool includeEnd = false}) {
  String format(String? value, DateTime fallback) {
    final parts = value?.split(':');
    if (parts != null && parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
      }
    }
    return DateFormat.jm().format(fallback.toLocal());
  }

  final start = format(event.localStartTime, event.startsAt);
  if (!includeEnd) return start;
  final end = format(event.localEndTime, event.endsAt);
  return '$start – $end';
}

class ScheduleGameCard extends StatelessWidget {
  final ScheduleEvent event;
  final VoidCallback onTap;
  final bool compact;

  const ScheduleGameCard({
    super.key,
    required this.event,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = event.status == ScheduleEventStatus.finalGame;
    final semanticLabel = isFinal
        ? '${event.cleanFirstTeamName} ${event.firstScore}, '
            '${event.cleanSecondTeamName} ${event.secondScore}, final'
        : '${event.cleanFirstTeamName} versus ${event.cleanSecondTeamName}, '
            '${scheduleTimeLabel(event)}';

    return Semantics(
      button: true,
      label: semanticLabel,
      child: AppGlassSurface(
        onTap: onTap,
        radius: AppRadius.card,
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: compact ? 62 : 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isFinal ? 'FINAL' : scheduleTimeLabel(event),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color:
                          isFinal ? AppGlassColors.rose : AppGlassColors.aqua,
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: isFinal ? 0.8 : 0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    event.division ?? 'Game',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppGlassColors.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: compact ? 50 : 58,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              color: AppGlassColors.inkMuted.withValues(alpha: 0.18),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TeamRow(
                    name: event.cleanFirstTeamName,
                    score: isFinal ? event.firstScore : null,
                  ),
                  const SizedBox(height: 8),
                  _TeamRow(
                    name: event.cleanSecondTeamName,
                    score: isFinal ? event.secondScore : null,
                  ),
                  if (!compact && event.location != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppGlassColors.inkMuted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppGlassColors.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppGlassColors.inkMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final String name;
  final int? score;

  const _TeamRow({required this.name, this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppGlassColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$score',
            style: const TextStyle(
              color: AppGlassColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ],
    );
  }
}
