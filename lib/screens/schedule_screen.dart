import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/design_system.dart';
import '../models/schedule_event.dart';
import '../providers/data_providers.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/empty_state.dart';
import '../widgets/schedule_game_card.dart';

enum ScheduleView { upcoming, results }

List<ScheduleEvent> filterScheduleEvents(
  List<ScheduleEvent> events, {
  required ScheduleView view,
  required DateTime now,
  DateTime? selectedDate,
}) {
  bool sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
  final filtered = events.where((event) {
    final inView = view == ScheduleView.upcoming
        ? event.isUpcomingAt(now)
        : event.status == ScheduleEventStatus.finalGame;
    return inView &&
        (selectedDate == null || sameDay(event.scheduleDate, selectedDate));
  }).toList();
  filtered.sort((first, second) => view == ScheduleView.upcoming
      ? first.startsAt.compareTo(second.startsAt)
      : second.startsAt.compareTo(first.startsAt));
  return filtered;
}

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  ScheduleView _view = ScheduleView.upcoming;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final scheduleAsync = ref.watch(scheduleEventsProvider);
    final events = filterScheduleEvents(
      scheduleAsync.valueOrNull ?? [],
      view: _view,
      now: DateTime.now(),
      selectedDate: _selectedDate,
    );
    final grouped = _groupByDate(events);
    const toolbarHeight = 48.0;
    final topPadding = appShellTopPadding(
      context,
      stickyHeight: toolbarHeight,
    );

    return AppShellScaffold(
      header: const AppShellHeader(
        leadingIcon: Icons.calendar_month_outlined,
        leadingLabel: 'League Hub',
        title: 'Schedule',
      ),
      stickyContent: _ScheduleToolbar(
        view: _view,
        selectedDate: _selectedDate,
        onViewChanged: (view) => setState(() {
          _view = view;
          _selectedDate = null;
        }),
        onDateTap: _pickDate,
        onDateClear: () => setState(() => _selectedDate = null),
      ),
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(scheduleEventsProvider),
        child: scheduleAsync.isLoading
            ? const AppLoadingState(label: 'Loading games…')
            : events.isEmpty
                ? ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      topPadding + 40,
                      24,
                      appShellBottomPadding(context),
                    ),
                    children: [
                      EmptyState(
                        icon: _view == ScheduleView.upcoming
                            ? Icons.event_available_outlined
                            : Icons.sports_score_outlined,
                        title: _selectedDate != null
                            ? 'No games on this date'
                            : _view == ScheduleView.upcoming
                                ? 'No upcoming games yet'
                                : 'No results yet',
                        subtitle: _selectedDate != null
                            ? 'Choose another date or clear the calendar filter.'
                            : 'Games will appear here automatically when the league publishes them.',
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      topPadding,
                      16,
                      appShellBottomPadding(context),
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (context, groupIndex) {
                      final group = grouped[groupIndex];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: groupIndex == 0 ? 0 : AppSpacing.lg,
                              bottom: AppSpacing.sm,
                            ),
                            child: _DateHeading(date: group.date),
                          ),
                          ...group.events.indexed.map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AppMotionReveal(
                                index: groupIndex * 3 + entry.$1,
                                child: ScheduleGameCard(
                                  event: entry.$2,
                                  onTap: () => _showGameDetails(entry.$2),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  List<_ScheduleDateGroup> _groupByDate(List<ScheduleEvent> events) {
    final groups = <String, _ScheduleDateGroup>{};
    for (final event in events) {
      final date = event.scheduleDate;
      final key = DateFormat('yyyy-MM-dd').format(date);
      groups
          .putIfAbsent(key, () => _ScheduleDateGroup(date, []))
          .events
          .add(event);
    }
    return groups.values.toList();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(today.year - 2),
      lastDate: DateTime(today.year + 3),
      helpText: 'Filter schedule by date',
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _showGameDetails(ScheduleEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: AppGlassSurface(
            radius: 28,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppGlassColors.inkMuted.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (event.division != null)
                  Text(
                    event.division!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppGlassColors.aqua,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  event.cleanFirstTeamName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    event.status == ScheduleEventStatus.finalGame
                        ? '${event.firstScore ?? '–'}  FINAL  ${event.secondScore ?? '–'}'
                        : 'vs',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppGlassColors.inkMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  event.cleanSecondTeamName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  text: DateFormat('EEEE, MMMM d, yyyy')
                      .format(event.scheduleDate),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  text:
                      '${scheduleTimeLabel(event, includeEnd: true)} · ${_timezoneLabel(event.timezone)}',
                ),
                if (event.location != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    text: event.location!,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timezoneLabel(String timezone) =>
      timezone == 'America/Edmonton' ? 'Mountain time' : timezone;
}

class _ScheduleDateGroup {
  final DateTime date;
  final List<ScheduleEvent> events;

  _ScheduleDateGroup(this.date, this.events);
}

class _DateHeading extends StatelessWidget {
  final DateTime date;

  const _DateHeading({required this.date});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = DateUtils.isSameDay(date, today);
    final isTomorrow = DateUtils.isSameDay(date, tomorrow);
    final prefix = isToday
        ? 'Today'
        : isTomorrow
            ? 'Tomorrow'
            : DateFormat('EEEE').format(date);
    return Text(
      '$prefix · ${DateFormat('MMMM d').format(date)}',
      style: const TextStyle(
        color: AppGlassColors.ink,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ScheduleToolbar extends StatelessWidget {
  final ScheduleView view;
  final DateTime? selectedDate;
  final ValueChanged<ScheduleView> onViewChanged;
  final VoidCallback onDateTap;
  final VoidCallback onDateClear;

  const _ScheduleToolbar({
    required this.view,
    required this.selectedDate,
    required this.onViewChanged,
    required this.onDateTap,
    required this.onDateClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: AppGlassSurface(
                radius: AppRadius.pill,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ScheduleView.values.map((item) {
                    final selected = item == view;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        child: InkWell(
                          onTap: () => onViewChanged(item),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: AnimatedContainer(
                            duration: AppMotion.standard,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppGlassColors.aqua.withValues(alpha: 0.18)
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              item == ScheduleView.upcoming
                                  ? 'Upcoming'
                                  : 'Results',
                              style: TextStyle(
                                color: selected
                                    ? AppGlassColors.ink
                                    : AppGlassColors.inkMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: selectedDate == null
                  ? 'Filter schedule by date'
                  : 'Date filter ${DateFormat.yMMMd().format(selectedDate!)}',
              child: AppGlassSurface(
                onTap: selectedDate == null ? onDateTap : onDateClear,
                width: 48,
                height: 48,
                radius: AppRadius.pill,
                padding: EdgeInsets.zero,
                child: Icon(
                  selectedDate == null
                      ? Icons.calendar_today_outlined
                      : Icons.close_rounded,
                  size: 20,
                  color: AppGlassColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppGlassColors.aqua),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppGlassColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
