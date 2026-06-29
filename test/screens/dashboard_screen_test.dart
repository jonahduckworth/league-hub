import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/weather_snapshot.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/providers/weather_provider.dart';
import 'package:league_hub/screens/dashboard_screen.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/league_filter.dart';

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
      observedAt: DateTime(2026),
    );

    Widget createTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
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
      );
    }

    Widget createRoutedTestWidget({
      AppUser? user,
      Organization? org,
      List<League>? leagues,
      int hubCount = 3,
      int teamCount = 12,
      int memberCount = 45,
    }) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
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
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.text('Test User'),
          ),
          findsOneWidget,
        );
        expect(find.text('Policy'), findsOneWidget);
        expect(find.text('Weather'), findsOneWidget);
        expect(find.text('Contacts'), findsOneWidget);
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
        expect(find.byType(AppHeaderLogoMark), findsOneWidget);
      });

      testWidgets('aligns the league mark with the greeting row',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final greetingFinder = find.textContaining(
          RegExp(r'Good (morning|afternoon|evening)'),
        );
        final logoFinder = find.byType(AppHeaderLogoMark);
        final greetingSurface = find
            .ancestor(
              of: greetingFinder,
              matching: find.byType(AppGlassSurface),
            )
            .first;

        expect(greetingFinder, findsOneWidget);
        expect(logoFinder, findsOneWidget);
        expect(
          tester.getSize(greetingSurface).height,
          closeTo(tester.getSize(logoFinder).height, 1),
        );
        expect(tester.getCenter(logoFinder).dy,
            closeTo(tester.getCenter(greetingFinder).dy, 2));
        expect(
          tester.getTopRight(logoFinder).dx,
          greaterThan(tester.getTopRight(greetingFinder).dx),
        );
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

      testWidgets('places quick access below the profile row',
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
        final policySurface = find
            .ancestor(
              of: find.text('Policy'),
              matching: find.byType(AppGlassSurface),
            )
            .last;
        final contentTop = tester.getTopLeft(policySurface).dy;

        expect(contentTop, greaterThan(headerBottom));
        expect(contentTop - headerBottom, lessThanOrEqualTo(96));
      });

      testWidgets('matches quick access heading to the greeting pill',
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

      testWidgets('home grid shows policy, weather, contacts, and settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('Policy'), findsOneWidget);
        expect(find.text('Policies'), findsNothing);
        expect(find.text('Weather'), findsOneWidget);
        expect(find.text('Contacts'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('18°'), findsOneWidget);
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
          findsNothing,
        );
      });

      testWidgets('positions quick links above the bottom nav area',
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pumpAndSettle();

        final websiteBottom =
            tester.getBottomLeft(find.byTooltip('League Website')).dy;

        expect(websiteBottom, closeTo(844 - 64 - 12 - 40, 1));
      });

      testWidgets('policy tile navigates to policy',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Policy'));
        await tester.pumpAndSettle();

        expect(find.text('Policy Route'), findsOneWidget);
      });

      testWidgets('contacts tile navigates to contacts',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Contacts'));
        await tester.pumpAndSettle();

        expect(find.text('Contacts Route'), findsOneWidget);
      });

      testWidgets('settings tile navigates to settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(createRoutedTestWidget());
        await tester.pumpAndSettle();

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
