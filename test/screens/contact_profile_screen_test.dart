import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/contact_profile_screen.dart';

void main() {
  group('ContactProfileScreen', () {
    final contact = AppUser(
      id: 'user-1',
      email: 'lily@example.com',
      displayName: 'Lily Carter',
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

    final league = League(
      id: 'league-1',
      orgId: 'org-1',
      name: 'Spring League',
      abbreviation: 'SL',
      createdAt: DateTime(2025, 1, 1),
    );

    final hub = Hub(
      id: 'hub-1',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'Calgary Hub',
      createdAt: DateTime(2025, 1, 1),
    );

    final team = Team(
      id: 'team-1',
      hubId: 'hub-1',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'U15 Rockies',
      createdAt: DateTime(2025, 1, 1),
    );

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          orgUsersProvider.overrideWith((ref) => Stream.value([contact])),
          leaguesProvider.overrideWith((ref) => Stream.value([league])),
          hubsProvider('league-1').overrideWith(
            (ref) => Stream.value([hub]),
          ),
          teamsProvider((leagueId: 'league-1', hubId: 'hub-1')).overrideWith(
            (ref) => Stream.value([team]),
          ),
        ],
        child: MaterialApp(
          home: const ContactProfileScreen(userId: 'user-1'),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
        ),
      );
    }

    testWidgets('shows profile assignment and contact details',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Lily Carter'), findsOneWidget);
      expect(find.text('Head Coach'), findsOneWidget);
      expect(find.text('lily@example.com'), findsNothing);
      expect(find.text('LEAGUE DETAILS'), findsOneWidget);
      expect(find.text('Spring League'), findsOneWidget);
      expect(find.text('Calgary Hub'), findsOneWidget);
      expect(find.text('U15 Rockies'), findsOneWidget);
      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.text('555-0101'), findsOneWidget);
      expect(find.text('1 Main Arena'), findsOneWidget);
    });
  });
}
