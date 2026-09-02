import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/core/design_system.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/weather_snapshot.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/models/schedule_event.dart';
import 'package:league_hub/models/schedule_team_logos.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/providers/weather_provider.dart';
import 'package:league_hub/screens/dashboard_screen.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/league_filter.dart';
import 'package:league_hub/widgets/schedule_team_logo.dart';

void main() {
  group('DashboardScreen', () {
    final testUser = AppUser(
      id: 'user-1',
      email: 'user@example.com',
      displayName: 'Test User',
      title: 'Head Coach',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2024),
      isActive: true,
    );

    final testOrg = Organization(
      id: 'org-1',
      name: 'Test Organization',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime.now(),
      ownerId: 'user-1',
    );

    final testLeagues = [
      League(
        id: 'league-1',
        orgId: 'org-1',
        name: 'Spring League',
        abbreviation: 'SL',
        logoUrl: 'https://example.com/logo.png',
        websiteUrl: 'https://spring.example',
        instagramUrl: 'https://instagram.com/spring',
        xUrl: 'https://x.com/spring',
        createdAt: DateTime.now(),
      ),
      League(
        id: 'league-2',
        orgId: 'org-1',
        name: 'Fall League',
        abbreviation: 'FL',
        createdAt: DateTime.now(),
      ),
    ];

    final testWeather = WeatherSnapshot(
      temperatureC: 18.4,
      apparentTemperatureC: 17.9,
      windSpeedKph: 12,
      weatherCode: 1,
      isDay: true,
      observedAt: DateTime(2026),
    );

    final pinnedAnnouncement = Announcement(
      id: 'announcement-1',
      orgId: 'org-1',
      scope: AnnouncementScope.league,
      leagueId: 'league-1',
      title: 'Weekend schedule update',
      body: 'Please review the revised arrival times before Saturday.',
      authorId: 'manager-1',
      authorName: 'Manager User',
      authorRole: 'Manager',
      attachments: const [],
      isPinned: true,
      createdAt: DateTime(2026, 8, 10),
    );

    final fallPinnedAnnouncement = Announcement(
      id: 'announcement-2',
      orgId: 'org-1',
      scope: AnnouncementScope.league,
      leagueId: 'league-2',
      title: 'Fall registration update',
      body: 'Registration closes Friday.',
      authorId: 'manager-1',
      authorName: 'Manager User',
      authorRole: 'Manager',
      attachments: const [],
      isPinned: true,
      createdAt: DateTime(2026, 8, 11),
    );

    Widget createTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
      WeatherSnapshot? weather,
      List<ScheduleEvent> scheduleEvents = const [],
      List<Announcement> announcements = const [],
      Stream<List<Announcement>>? announcementsStream,
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => user ?? testUser,
          ),
          organizationProvider.overrideWith(
            (ref) => org ?? testOrg,
          ),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          hubCountProvider.overrideWith(
            (ref) => hubCount,
          ),
          teamCountProvider.overrideWith(
            (ref) => teamCount,
          ),
          activeUserCountProvider.overrideWith(
            (ref) => memberCount,
          ),
          unreadCountProvider.overrideWith((ref, roomId) => Stream.value(0)),
          currentWeatherProvider.overrideWith((ref) => weather ?? testWeather),
          scheduleEventsProvider.overrideWith(
            (ref) => Stream.value(scheduleEvents),
          ),
          announcementsProvider.overrideWith(
            (ref) => announcementsStream ?? Stream.value(announcements),
          ),
          scheduleTeamLogosProvider.overrideWith(
            (ref) => const ScheduleTeamLogos(
              byTeamId: {
                'wolves': 'https://example.com/wolves.png',
                'rockies': 'https://example.com/rockies.png',
              },
            ),
          ),
        ],
        child: MaterialApp(
          home: DashboardScreen(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
          ),
        ),
      );
    }

    Widget createRoutedTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
      List<ScheduleEvent> scheduleEvents = const [],
      List<Announcement> announcements = const [],
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/schedule',
            builder: (context, state) =>
                const Scaffold(body: Text('Schedule Route')),
          ),
          GoRoute(
            path: '/settings/notifications',
            builder: (context, state) =>
                const Scaffold(body: Text('Notifications Route')),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) =>
                const Scaffold(body: Text('Announcements Route')),
          ),
          GoRoute(
            path: '/announcements/:announcementId',
            builder: (context, state) => Scaffold(
              body: Text(
                'Announcement ${state.pathParameters['announcementId']}',
              ),
            ),
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) =>
                const Scaffold(body: Text('Chat Route')),
          ),
          GoRoute(
            path: '/policy',
            builder: (context, state) =>
                const Scaffold(body: Text('Policy Route')),
          ),
          GoRoute(
            path: '/contacts',
            builder: (context, state) =>
                const Scaffold(body: Text('Contacts Route')),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                const Scaffold(body: Text('Settings Route')),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile Route')),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (context, state) => Scaffold(
                body: Text('Chat Detail ${state.pathParameters['id']}')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user ?? testUser),
          organizationProvider.overrideWith((ref) => org ?? testOrg),
          leaguesProvider.overrideWith(
            (ref) => Stream.value(leagues ?? testLeagues),
          ),
          hubCountProvider.overrideWith((ref) => hubCount),
          teamCountProvider.overrideWith((ref) => teamCount),
          activeUserCountProvider.overrideWith((ref) => memberCount),
          unreadCountProvider.overrideWith((ref, roomId) => Stream.value(0)),
          currentWeatherProvider.overrideWith((ref) => testWeather),
          scheduleEventsProvider.overrideWith(
            (ref) => Stream.value(scheduleEvents),
          ),
          announcementsProvider.overrideWith(
            (ref) => Stream.value(announcements),
          ),
          scheduleTeamLogosProvider.overrideWith(
            (ref) => const ScheduleTeamLogos(
              byTeamId: {
                'wolves': 'https://example.com/wolves.png',
                'rockies': 'https://example.com/rockies.png',
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
        ),
      );
    }

    group('Main Content', () {
      testWidgets('shows team logos with the next game',
          (WidgetTester tester) async {
        final startsAt = DateTime.now().add(const Duration(days: 2));
        final game = ScheduleEvent(
          id: 'next-game',
          orgId: 'org-1',
          sourceUid: 'next-game@rampinteractive.com',
          firstTeamId: 'wolves',
          secondTeamId: 'rockies',
          teamIds: const ['wolves', 'rockies'],
          hubIds: const ['hub-wolves', 'hub-rockies'],
          leagueIds: const ['league-1'],
          division: '17U AAA',
          title: 'Wolves HC vs Calgary Rockies',
          firstTeamName: '17U AAA - Wolves HC',
          secondTeamName: '17U AAA - Calgary Rockies',
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(hours: 2)),
          timezone: 'America/Edmonton',
          location: 'Winsport Arena',
          status: ScheduleEventStatus.scheduled,
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(scheduleEvents: [game]));
        await tester.pumpAndSettle();

        expect(find.text('Wolves HC'), findsOneWidget);
        expect(find.text('Calgary Rockies'), findsOneWidget);
        expect(find.byType(ScheduleTeamLogo), findsNWidgets(2));
        expect(
          tester
              .widgetList<ScheduleTeamLogo>(find.byType(ScheduleTeamLogo))
              .every(
                (logo) => logo.fallbackTextColor == const Color(0xFF061D3A),
              ),
          isTrue,
        );
        expect(find.text('Next Game'), findsOneWidget);
        expect(find.text('17U AAA  •  Winsport Arena'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('next-game-active-background')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('next-game-active-frame')),
          findsOneWidget,
        );
        final activeFrame = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('next-game-active-frame')),
        );
        expect(
          (activeFrame.decoration as BoxDecoration).border,
          isNotNull,
        );
        expect(
          find.byKey(const ValueKey('next-game-active-overlay')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('next-game-empty-background')),
          findsNothing,
        );
      });

      testWidgets('shows a helpful empty schedule state',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('No upcoming games'), findsOneWidget);
        expect(
          find.text(
            'New games will appear here when the schedule is published.',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('next-game-empty-background')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('next-game-empty-frame')),
          findsOneWidget,
        );
        final emptyFrame = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('next-game-empty-frame')),
        );
        expect(
          (emptyFrame.decoration as BoxDecoration).border,
          isNotNull,
        );
        expect(
          find.byKey(const ValueKey('next-game-empty-overlay')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('next-game-active-background')),
          findsNothing,
        );
      });

      testWidgets('does not render the old stats card grid',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Active Hubs'), findsNothing);
        expect(find.text('Total Teams'), findsNothing);
        expect(find.text('Leagues'), findsNothing);
        expect(find.text('Members'), findsNothing);
      });

      testWidgets('shows profile, quick access, and quick tiles',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Quick Access'), findsOneWidget);
        expect(find.text('Test User'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-profile-background')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-profile-frame')),
          findsOneWidget,
        );
        final profileFrame = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('home-profile-frame')),
        );
        expect(
          (profileFrame.decoration as BoxDecoration).border,
          isNotNull,
        );
        final profileSurface = find
            .ancestor(
              of: find.byKey(const ValueKey('home-profile-background')),
              matching: find.byType(AppGlassSurface),
            )
            .last;
        expect(
            tester.getSize(profileSurface).height, greaterThanOrEqualTo(112));
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.text('Test User'),
          ),
          findsOneWidget,
        );
        expect(find.text('Policy'), findsOneWidget);
        expect(find.text('Weather'), findsOneWidget);
        expect(find.text('Chats'), findsOneWidget);
        expect(find.text('Group and direct messages'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('does not render chat previews on home',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Active Chats'), findsNothing);
        expect(find.text('General Discussion'), findsNothing);
        expect(find.text('Tournament Bracket'), findsNothing);
      });

      testWidgets('places pinned announcements before quick access',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(announcements: [pinnedAnnouncement]),
        );
        await tester.pumpAndSettle();

        final nextGame = find.byKey(const ValueKey('next-game-card'));
        final announcements =
            find.byKey(const ValueKey('pinned-announcements-section'));
        final quickAccess = find.text('Quick Access');

        expect(find.text('Weekend schedule update'), findsOneWidget);
        expect(tester.getTopLeft(announcements).dy,
            greaterThan(tester.getBottomLeft(nextGame).dy));
        expect(tester.getTopLeft(quickAccess).dy,
            greaterThan(tester.getBottomLeft(announcements).dy));
      });

      testWidgets('opens announcement detail and full feed from home',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createRoutedTestWidget(announcements: [pinnedAnnouncement]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Weekend schedule update'));
        await tester.pumpAndSettle();
        expect(find.text('Announcement announcement-1'), findsOneWidget);

        GoRouter.of(tester.element(find.text('Announcement announcement-1')))
            .go('/');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('view-all-announcements')));
        await tester.pumpAndSettle();
        expect(find.text('Announcements Route'), findsOneWidget);
      });

      testWidgets('shows a retry action when announcements fail to load',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcementsStream: Stream.error(StateError('offline')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Announcements unavailable'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('retry-pinned-announcements')),
          findsOneWidget,
        );
      });

      testWidgets('league selection scopes the pinned announcements on home',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            announcements: [pinnedAnnouncement, fallPinnedAnnouncement],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('FL'));
        await tester.pumpAndSettle();

        expect(find.text('Fall registration update'), findsOneWidget);
        expect(find.text('Weekend schedule update'), findsNothing);

        await tester.tap(find.text('SL'));
        await tester.pumpAndSettle();

        expect(find.text('Weekend schedule update'), findsOneWidget);
        expect(find.text('Fall registration update'), findsNothing);
      });

      testWidgets('announcement section stays usable in phone landscape',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(844, 390));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestWidget(announcements: [pinnedAnnouncement]),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pinned announcements'), findsOneWidget);
        expect(find.text('Weekend schedule update'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('AppBar and Header', () {
      testWidgets('shows greeting and compact profile row',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          org: Organization(
            id: 'org-1',
            name: 'Custom Org Name',
            primaryColor: '#1A3A5C',
            secondaryColor: '#2E75B6',
            accentColor: '#4DA3FF',
            createdAt: DateTime.now(),
            ownerId: 'user-1',
          ),
        ));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
          findsOneWidget,
        );
        expect(find.text('Test User'), findsWidgets);
        expect(find.text('Head Coach'), findsOneWidget);
        expect(find.text('user@example.com'), findsNothing);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        expect(
          find.byKey(const ValueKey('home-header-league-mark')),
          findsOneWidget,
        );
      });

      testWidgets('uses a borderless greeting and league mark',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final greetingFinder = find.textContaining(
          RegExp(r'Good (morning|afternoon|evening)'),
        );
        final logoFinder =
            find.byKey(const ValueKey('home-header-league-mark'));

        expect(greetingFinder, findsOneWidget);
        expect(logoFinder, findsOneWidget);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('home-greeting-row')),
              )
              .height,
          closeTo(tester.getSize(logoFinder).height, 1),
        );
        expect(tester.getCenter(logoFinder).dy,
            closeTo(tester.getCenter(greetingFinder).dy, 2));
        expect(
          tester.getTopRight(logoFinder).dx,
          greaterThan(tester.getTopRight(greetingFinder).dx),
        );
        expect(
          find.ancestor(
            of: greetingFinder,
            matching: find.byType(AppGlassSurface),
          ),
          findsNothing,
        );
        expect(
          find.ancestor(
            of: logoFinder,
            matching: find.byType(AppGlassSurface),
          ),
          findsNothing,
        );
      });

      testWidgets('keeps the profile close to the borderless header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pumpAndSettle();

        final greetingBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('home-greeting-row')))
            .dy;
        final profileTop = tester
            .getTopLeft(find.byKey(const ValueKey('home-profile-frame')))
            .dy;

        expect(profileTop - greetingBottom, closeTo(AppSpacing.xxs, 1));
      });

      testWidgets('uses a compact header without org welcome copy',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
          findsOneWidget,
        );
        expect(find.text('Test Organization'), findsNothing);
        expect(find.text('Welcome back, Test User'), findsNothing);
      });

      testWidgets('removes notification button from header',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byIcon(Icons.notifications_outlined),
          findsNothing,
        );
      });

      testWidgets('does not show the old header search bar',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text('Search chats, policies, announcements...'),
          findsNothing,
        );
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('places next game between the profile and quick access',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pump();
        await tester.pumpAndSettle();

        final profileSurface = find
            .ancestor(
              of: find.byIcon(Icons.chevron_right),
              matching: find.byType(AppGlassSurface),
            )
            .first;
        final headerBottom = tester.getBottomLeft(profileSurface).dy;
        final nextGameTop = tester
            .getTopLeft(
              find
                  .ancestor(
                    of: find.text('No upcoming games'),
                    matching: find.byType(AppGlassSurface),
                  )
                  .last,
            )
            .dy;
        final policySurface = find
            .ancestor(
              of: find.text('Policy'),
              matching: find.byType(AppGlassSurface),
            )
            .last;
        final contentTop = tester.getTopLeft(policySurface).dy;

        expect(nextGameTop, greaterThan(headerBottom));
        expect(contentTop, greaterThan(nextGameTop));
      });

      testWidgets('keeps empty and active next game cards the same height',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        final emptyHeight =
            tester.getSize(find.byKey(const ValueKey('next-game-card'))).height;

        final startsAt = DateTime.now().add(const Duration(days: 2));
        final game = ScheduleEvent(
          id: 'next-game',
          orgId: 'org-1',
          sourceUid: 'next-game@rampinteractive.com',
          firstTeamId: 'wolves',
          secondTeamId: 'rockies',
          teamIds: const ['wolves', 'rockies'],
          hubIds: const ['hub-wolves', 'hub-rockies'],
          leagueIds: const ['league-1'],
          division: '17U AAA',
          title: 'Wolves HC vs Calgary Rockies',
          firstTeamName: '17U AAA - Wolves HC',
          secondTeamName: '17U AAA - Calgary Rockies',
          startsAt: startsAt,
          endsAt: startsAt.add(const Duration(hours: 2)),
          timezone: 'America/Edmonton',
          location: 'Winsport Arena',
          status: ScheduleEventStatus.scheduled,
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(scheduleEvents: [game]));
        await tester.pumpAndSettle();
        final activeHeight =
            tester.getSize(find.byKey(const ValueKey('next-game-card'))).height;

        expect(activeHeight, closeTo(emptyHeight, 1));
        expect(tester.takeException(), isNull);
      });

      testWidgets('matches quick access heading to the greeting text',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final greetingFinder = find.textContaining(
          RegExp(r'Good (morning|afternoon|evening)'),
        );
        final quickAccessFinder = find.text('Quick Access');
        expect(greetingFinder, findsOneWidget);
        expect(quickAccessFinder, findsOneWidget);

        final greetingText = tester.widget<Text>(greetingFinder);
        final quickAccessText = tester.widget<Text>(quickAccessFinder);

        expect(quickAccessText.style?.fontSize, greetingText.style?.fontSize);
        expect(
          quickAccessText.style?.fontWeight,
          greetingText.style?.fontWeight,
        );
        expect(
          find.ancestor(
            of: quickAccessFinder,
            matching: find.byType(AppHeaderPill),
          ),
          findsNothing,
        );
        expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      });

      testWidgets('uses a masked fade over the home content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.byType(ShaderMask), findsOneWidget);
      });

      testWidgets('home grid shows policy, weather, chats, and settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Policy'), findsOneWidget);
        expect(find.text('Policies'), findsNothing);
        expect(find.text('Weather'), findsOneWidget);
        expect(find.text('Chats'), findsOneWidget);
        expect(find.text('Group and direct messages'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('18°'), findsOneWidget);
      });

      testWidgets('phone-width live weather wraps without clipping',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestWidget(
            weather: WeatherSnapshot(
              temperatureC: 20,
              apparentTemperatureC: 20,
              windSpeedKph: 13,
              weatherCode: 2,
              isDay: true,
              observedAt: DateTime(2026),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Partly cloudy'), findsOneWidget);
        expect(find.textContaining('13 km/h'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('large Dynamic Type stacks and expands quick access tiles',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestWidget(textScaler: const TextScaler.linear(2)),
        );
        await tester.pumpAndSettle();

        final policy = find.byKey(const ValueKey('home-tile-policy'));
        final weather = find.byKey(const ValueKey('home-tile-weather'));
        final chats = find.byKey(const ValueKey('home-tile-chats'));
        final settings = find.byKey(const ValueKey('home-tile-settings'));

        expect(tester.getSize(policy).height, greaterThan(136));
        expect(tester.getSize(policy).width, greaterThan(300));
        expect(tester.getTopLeft(policy).dx, tester.getTopLeft(weather).dx);
        expect(tester.getTopLeft(weather).dx, tester.getTopLeft(chats).dx);
        expect(tester.getTopLeft(chats).dx, tester.getTopLeft(settings).dx);
        expect(tester.takeException(), isNull);
      });

      testWidgets('moderate Dynamic Type keeps the balanced two-column grid',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestWidget(textScaler: const TextScaler.linear(1.4)),
        );
        await tester.pumpAndSettle();

        final policy = find.byKey(const ValueKey('home-tile-policy'));
        final weather = find.byKey(const ValueKey('home-tile-weather'));

        expect(tester.getSize(policy).height, greaterThan(136));
        expect(
          tester.getTopLeft(weather).dx,
          greaterThan(tester.getTopLeft(policy).dx),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('large Dynamic Type reserves room below the greeting header',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          createTestWidget(textScaler: const TextScaler.linear(3.2)),
        );
        await tester.pumpAndSettle();

        final greetingBottom = tester
            .getBottomLeft(find.byKey(const ValueKey('home-greeting-row')))
            .dy;
        final profileTop = tester
            .getTopLeft(find.byKey(const ValueKey('home-profile-frame')))
            .dy;

        expect(profileTop, greaterThan(greetingBottom));
        expect(tester.takeException(), isNull);
      });

      testWidgets('uses a night icon for clear nighttime conditions',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            weather: WeatherSnapshot(
              temperatureC: 12,
              apparentTemperatureC: 11,
              windSpeedKph: 4,
              weatherCode: 0,
              isDay: false,
              observedAt: DateTime(2026, 7, 17, 23),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final weatherTile = find
            .ancestor(
              of: find.text('Weather'),
              matching: find.byType(AppGlassSurface),
            )
            .first;
        expect(
          find.descendant(
            of: weatherTile,
            matching: find.byIcon(Icons.nightlight_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: weatherTile,
            matching: find.byIcon(Icons.wb_sunny_outlined),
          ),
          findsNothing,
        );
      });

      testWidgets('renders snow showers with snow styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          createTestWidget(
            weather: WeatherSnapshot(
              temperatureC: -4,
              apparentTemperatureC: -9,
              windSpeedKph: 22,
              weatherCode: 85,
              isDay: true,
              observedAt: DateTime(2026, 1, 17, 12),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Snow showers'), findsOneWidget);
        expect(find.byIcon(Icons.ac_unit), findsOneWidget);
      });

      testWidgets('home shows quick link icons for the selected league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Quick Links'), findsNothing);
        expect(find.byTooltip('League Website'), findsOneWidget);
        expect(find.byTooltip('League Instagram'), findsOneWidget);
        expect(find.byTooltip('League X'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byTooltip('League Website'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('keeps quick links at the bottom of the scrollable page',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final websiteFinder = find.byTooltip('League Website');
        final settingsSurface = find
            .ancestor(
              of: find.text('Settings'),
              matching: find.byType(AppGlassSurface),
            )
            .last;
        final websiteTop = tester.getTopLeft(websiteFinder).dy;
        final settingsBottom = tester.getBottomLeft(settingsSurface).dy;

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -100),
        );
        await tester.pumpAndSettle();

        expect(websiteTop, greaterThan(settingsBottom));
        expect(tester.getTopLeft(websiteFinder).dy, lessThan(websiteTop));
      });

      testWidgets('policy tile navigates to policy',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Policy'));
        await tester.tap(find.text('Policy'));
        await tester.pumpAndSettle();

        expect(find.text('Policy Route'), findsOneWidget);
      });

      testWidgets('chats tile navigates to chat', (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Chats'));
        await tester.tap(find.text('Chats'));
        await tester.pumpAndSettle();

        expect(find.text('Chat Route'), findsOneWidget);
      });

      testWidgets('settings tile navigates to settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Settings'));
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();

        expect(find.text('Settings Route'), findsOneWidget);
      });

      testWidgets('profile row opens the profile route',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();

        expect(find.text('Profile Route'), findsOneWidget);
      });
    });

    group('League Filter', () {
      testWidgets('displays league filter with options',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Filter should be present
        expect(find.byType(ListView), findsWidgets);
      });

      testWidgets('handles empty leagues list', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: []));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should still render without crashing
        expect(find.byType(DashboardScreen), findsOneWidget);
      });

      testWidgets('hides league filter when there is only one league',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(leagues: [testLeagues.first]));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsNothing);
      });
    });

    group('Loading and Error States', () {
      testWidgets('shows loading indicator when data is loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) => throw UnimplementedError(),
              ),
              currentWeatherProvider.overrideWith((ref) => testWeather),
            ],
            child: MaterialApp(
              home: DashboardScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen should still render with defaults
        expect(find.byType(DashboardScreen), findsOneWidget);
      });
    });

    group('Default Values', () {
      testWidgets('uses mock values when data is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith(
                (ref) => null,
              ),
              organizationProvider.overrideWith(
                (ref) => null,
              ),
              leaguesProvider.overrideWith(
                (ref) => Stream.value(<League>[]),
              ),
              hubCountProvider.overrideWith(
                (ref) => 0,
              ),
              teamCountProvider.overrideWith(
                (ref) => 0,
              ),
              activeUserCountProvider.overrideWith(
                (ref) => 0,
              ),
              unreadCountProvider
                  .overrideWith((ref, roomId) => Stream.value(0)),
              currentWeatherProvider.overrideWith((ref) => testWeather),
            ],
            child: MaterialApp(
              home: DashboardScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(RegExp(r'Good (morning|afternoon|evening)')),
          findsOneWidget,
        );
        expect(find.text('League Hub'), findsNothing);
        expect(
          find.text('Search chats, policies, announcements...'),
          findsNothing,
        );
        expect(find.text('Loading profile...'), findsOneWidget);
        expect(find.text('Quick Links'), findsNothing);
        expect(find.text('Policy'), findsOneWidget);
      });
    });

    group('Content Spacing and Layout', () {
      testWidgets('home content is vertically scrollable',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(SingleChildScrollView), findsOneWidget);
      });

      testWidgets('pull to refresh reloads every visible home data source',
          (WidgetTester tester) async {
        var userLoads = 0;
        var organizationLoads = 0;
        var leagueLoads = 0;
        var scheduleLoads = 0;
        var logoLoads = 0;
        var weatherLoads = 0;
        var announcementLoads = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserProvider.overrideWith((ref) {
                userLoads += 1;
                return testUser;
              }),
              organizationProvider.overrideWith((ref) {
                organizationLoads += 1;
                return testOrg;
              }),
              leaguesProvider.overrideWith((ref) {
                leagueLoads += 1;
                return Stream.value(testLeagues);
              }),
              scheduleEventsProvider.overrideWith((ref) {
                scheduleLoads += 1;
                return Stream.value(const []);
              }),
              scheduleTeamLogosProvider.overrideWith((ref) {
                logoLoads += 1;
                return const ScheduleTeamLogos();
              }),
              currentWeatherProvider.overrideWith((ref) {
                weatherLoads += 1;
                return testWeather;
              }),
              announcementsProvider.overrideWith((ref) {
                announcementLoads += 1;
                return Stream.value(const []);
              }),
              unreadCountProvider.overrideWith(
                (ref, roomId) => Stream.value(0),
              ),
            ],
            child: MaterialApp(
              home: const DashboardScreen(),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final initialLoads = [
          userLoads,
          organizationLoads,
          leagueLoads,
          scheduleLoads,
          logoLoads,
          weatherLoads,
          announcementLoads,
        ];
        final refreshFinder =
            find.byKey(const ValueKey('home-refresh-indicator'));
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );

        expect(refreshFinder, findsOneWidget);
        expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();

        expect(userLoads, greaterThan(initialLoads[0]));
        expect(organizationLoads, greaterThan(initialLoads[1]));
        expect(leagueLoads, greaterThan(initialLoads[2]));
        expect(scheduleLoads, greaterThan(initialLoads[3]));
        expect(logoLoads, greaterThan(initialLoads[4]));
        expect(weatherLoads, greaterThan(initialLoads[5]));
        expect(announcementLoads, greaterThan(initialLoads[6]));
      });

      testWidgets('league filter stays outside the home content',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(LeagueFilter), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(LeagueFilter),
          ),
          findsNothing,
        );
      });

      testWidgets('has proper padding on content', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        // Stats and section content should be properly padded
        expect(find.byType(Padding), findsWidgets);
      });
    });
  });
}
