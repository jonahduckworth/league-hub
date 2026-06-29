import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/profile_screen.dart';
import 'package:league_hub/widgets/profile_summary_card.dart';

void main() {
  group('ProfileScreen', () {
    final testUser = AppUser(
      id: 'user-1',
      email: 'jonah@example.com',
      displayName: 'Jonah Duckworth',
      title: 'Head Coach',
      phone: '555-0101',
      address: '1 Main Arena',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: ['hub-1'],
      leagueIds: ['league-1'],
      teamIds: ['team-1'],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

    final testLeague = League(
      id: 'league-1',
      orgId: 'org-1',
      name: 'Spring League',
      abbreviation: 'SL',
      logoUrl: 'https://example.com/logo.png',
      createdAt: DateTime(2025, 1, 1),
    );

    final testHub = Hub(
      id: 'hub-1',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'Calgary Hub',
      createdAt: DateTime(2025, 1, 1),
    );

    final testTeam = Team(
      id: 'team-1',
      hubId: 'hub-1',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'U15 Rockies',
      createdAt: DateTime(2025, 1, 1),
    );

    Widget createTestWidget({AppUser? user}) {
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) =>
                const Scaffold(body: Text('Edit Profile Route')),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => user ?? testUser),
          leaguesProvider.overrideWith((ref) => Stream.value([testLeague])),
          hubsProvider('league-1').overrideWith(
            (ref) => Stream.value([testHub]),
          ),
          teamsProvider((leagueId: 'league-1', hubId: 'hub-1')).overrideWith(
            (ref) => Stream.value([testTeam]),
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

    testWidgets('uses home-style profile row and contact-only content',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final profileCard = tester.widget<ProfileSummaryCard>(
        find.byType(ProfileSummaryCard),
      );

      expect(profileCard.compact, isTrue);
      expect(profileCard.showEmail, isFalse);
      expect(profileCard.actionIcon, Icons.edit_outlined);
      expect(find.text('Jonah Duckworth'), findsOneWidget);
      expect(find.text('Head Coach'), findsOneWidget);
      expect(find.text('jonah@example.com'), findsNothing);
      expect(find.text('LEAGUE DETAILS'), findsOneWidget);
      expect(find.text('Spring League'), findsOneWidget);
      expect(find.text('Calgary Hub'), findsOneWidget);
      expect(find.text('U15 Rockies'), findsOneWidget);
      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.text('555-0101'), findsOneWidget);
      expect(find.text('1 Main Arena'), findsOneWidget);
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('opens edit profile from the profile row action',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit profile'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile Route'), findsOneWidget);
    });
  });
}
