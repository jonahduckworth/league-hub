import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/schedule_event.dart';
import 'package:league_hub/models/schedule_team_logos.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/schedule_screen.dart';
import 'package:league_hub/widgets/schedule_team_logo.dart';

void main() {
  final now = DateTime.now();

  ScheduleEvent event({
    required String id,
    required String firstTeam,
    required String secondTeam,
    required DateTime startsAt,
    String? sourceSeasonId,
    ScheduleEventStatus status = ScheduleEventStatus.scheduled,
    int? firstScore,
    int? secondScore,
  }) {
    final local = startsAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return ScheduleEvent(
      id: id,
      orgId: 'org-1',
      sourceUid: '$id@rampinteractive.com',
      sourceSeasonId: sourceSeasonId,
      firstTeamId: 'team-1',
      secondTeamId: 'team-2',
      teamIds: const ['team-1', 'team-2'],
      hubIds: const ['hub-1'],
      leagueIds: const ['league-1'],
      division: '17U AAA',
      title: '$firstTeam vs $secondTeam',
      firstTeamName: firstTeam,
      secondTeamName: secondTeam,
      startsAt: startsAt,
      endsAt: startsAt.add(const Duration(hours: 2)),
      timezone: 'America/Edmonton',
      localDate: '${local.year}-${two(local.month)}-${two(local.day)}',
      localStartTime: '18:30',
      localEndTime: '20:30',
      location: 'Great Plains Arena',
      status: status,
      firstScore: firstScore,
      secondScore: secondScore,
      isActive: true,
    );
  }

  late List<ScheduleEvent> games;

  setUp(() {
    games = [
      event(
        id: 'future',
        firstTeam: '17U AAA - Wolves HC',
        secondTeam: '17U AAA - Calgary Rockies',
        startsAt: now.add(const Duration(days: 2)),
      ),
      event(
        id: 'final',
        firstTeam: '17U AAA - Island HC',
        secondTeam: '17U AAA - Okanagan HC',
        startsAt: now.subtract(const Duration(days: 2)),
        status: ScheduleEventStatus.finalGame,
        firstScore: 4,
        secondScore: 2,
      ),
    ];
  });

  Widget subject({double textScale = 1, bool disableAnimations = false}) =>
      ProviderScope(
        overrides: [
          scheduleEventsProvider.overrideWith((ref) => Stream.value(games)),
          scheduleTeamLogosProvider.overrideWith(
            (ref) => const ScheduleTeamLogos(
              byTeamId: {
                'team-1': 'https://example.com/team-1.png',
                'team-2': 'https://example.com/team-2.png',
              },
            ),
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
          home: const ScheduleScreen(),
        ),
      );

  test('filters upcoming and final events predictably', () {
    expect(
      filterScheduleEvents(
        games,
        view: ScheduleView.upcoming,
        now: now,
      ).map((event) => event.id),
      ['future'],
    );
    expect(
      filterScheduleEvents(
        games,
        view: ScheduleView.results,
        now: now,
      ).map((event) => event.id),
      ['final'],
    );
  });

  testWidgets('shows upcoming games natively and opens game details',
      (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Wolves HC'), findsOneWidget);
    expect(find.text('Calgary Rockies'), findsOneWidget);
    expect(find.byType(ScheduleTeamLogo), findsNWidgets(2));
    expect(find.text('Island HC'), findsNothing);

    await tester.tap(find.text('Wolves HC'));
    await tester.pumpAndSettle();

    expect(find.text('Great Plains Arena'), findsWidgets);
    expect(find.textContaining('Mountain time'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byType(ScheduleTeamLogo), findsNWidgets(4));
  });

  testWidgets('switches to final results with scores', (tester) async {
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    expect(find.text('Island HC'), findsOneWidget);
    expect(find.text('Okanagan HC'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(ScheduleTeamLogo), findsNWidgets(2));
    expect(find.text('Wolves HC'), findsNothing);
  });

  testWidgets('shows final results retained from multiple seasons',
      (tester) async {
    games = [
      event(
        id: 'older-final',
        sourceSeasonId: 'previous-season',
        firstTeam: 'Wolves HC',
        secondTeam: 'Rockies',
        startsAt: now.subtract(const Duration(days: 300)),
        status: ScheduleEventStatus.finalGame,
        firstScore: 3,
        secondScore: 1,
      ),
      event(
        id: 'current-final',
        sourceSeasonId: 'current-season',
        firstTeam: 'Island HC',
        secondTeam: 'Okanagan HC',
        startsAt: now.subtract(const Duration(days: 2)),
        status: ScheduleEventStatus.finalGame,
        firstScore: 4,
        secondScore: 2,
      ),
    ];
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    expect(find.text('Wolves HC'), findsOneWidget);
    expect(find.text('Rockies'), findsOneWidget);
    expect(find.text('Island HC'), findsOneWidget);
    expect(find.text('Okanagan HC'), findsOneWidget);
  });

  testWidgets('shows a helpful empty state when nothing is published',
      (tester) async {
    games = [];
    await tester.pumpWidget(subject());
    await tester.pumpAndSettle();

    expect(find.text('No upcoming games yet'), findsOneWidget);
    expect(
      find.textContaining('automatically when the league publishes'),
      findsOneWidget,
    );
  });

  testWidgets('remains usable on a small phone with large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject(textScale: 1.6));
    await tester.pumpAndSettle();

    expect(find.text('Wolves HC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports landscape and reduced motion without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(667, 375));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject(disableAnimations: true));
    await tester.pumpAndSettle();

    expect(find.text('Wolves HC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
