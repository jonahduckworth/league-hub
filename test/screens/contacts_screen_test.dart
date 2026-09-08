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
import 'package:league_hub/screens/contact_profile_screen.dart';
import 'package:league_hub/screens/contacts_screen.dart';

void main() {
  group('ContactsScreen', () {
    final league = League(
      id: 'league-1',
      orgId: 'org-1',
      name: 'Spring League',
      abbreviation: 'SL',
      createdAt: DateTime(2026),
    );
    final northHub = Hub(
      id: 'hub-north',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'North Hub',
      createdAt: DateTime(2026),
    );
    final southHub = Hub(
      id: 'hub-south',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'South Hub',
      createdAt: DateTime(2026),
    );
    final northTeam = Team(
      id: 'team-north',
      hubId: 'hub-north',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'North Stars',
      createdAt: DateTime(2026),
    );
    final southTeam = Team(
      id: 'team-south',
      hubId: 'hub-south',
      leagueId: 'league-1',
      orgId: 'org-1',
      name: 'South Storm',
      createdAt: DateTime(2026),
    );

    AppUser user({
      required String id,
      required String name,
      required String email,
      String? title,
      String? phone,
      UserRole role = UserRole.staff,
      bool isActive = true,
      List<String> hubIds = const [],
      List<String> teamIds = const [],
    }) {
      return AppUser(
        id: id,
        email: email,
        displayName: name,
        title: title,
        phone: phone,
        role: role,
        orgId: 'org-1',
        hubIds: hubIds,
        leagueIds: const ['league-1'],
        teamIds: teamIds,
        createdAt: DateTime(2026),
        isActive: isActive,
      );
    }

    Widget buildScreen(
      List<AppUser> users, {
      String initialLocation = '/contacts',
      AppUser? viewer,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const ContactsScreen(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) => ContactProfileScreen(
                  userId: state.pathParameters['userId']!,
                ),
              ),
            ],
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) =>
                viewer ??
                user(
                  id: 'viewer',
                  name: 'League Owner',
                  email: 'owner@example.com',
                  role: UserRole.superAdmin,
                ),
          ),
          leaguesProvider.overrideWith((ref) => Stream.value([league])),
          orgUsersProvider.overrideWith((ref) => Stream.value(users)),
          organizationHubsProvider.overrideWith(
            (ref) async => [northHub, southHub],
          ),
          organizationTeamsProvider.overrideWith(
            (ref) async => [northTeam, southTeam],
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
          ),
        ),
      );
    }

    testWidgets('shows active contacts with hubs and no emails', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildScreen([
          user(
            id: '2',
            name: 'Zoe Manager',
            email: 'zoe@example.com',
            title: 'Head Coach',
            role: UserRole.managerAdmin,
            hubIds: const ['hub-south'],
          ),
          user(
            id: '1',
            name: 'Alex Staff',
            email: 'alex@example.com',
            title: 'Trainer',
            hubIds: const ['hub-north'],
          ),
          user(
            id: '3',
            name: 'Inactive Person',
            email: 'inactive@example.com',
            isActive: false,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Alex Staff'), findsOneWidget);
      expect(find.text('North Hub'), findsOneWidget);
      expect(find.text('alex@example.com'), findsNothing);
      expect(find.text('Staff'), findsNothing);
      expect(find.text('Zoe Manager'), findsOneWidget);
      expect(find.text('South Hub'), findsOneWidget);
      expect(find.text('zoe@example.com'), findsNothing);
      expect(find.text('Manager'), findsNothing);
      expect(find.text('Inactive Person'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    });

    testWidgets('searches by contact name or visible hub', (tester) async {
      await tester.pumpWidget(
        buildScreen([
          user(
            id: '1',
            name: 'Alex Staff',
            email: 'alex@example.com',
            hubIds: const ['hub-north'],
          ),
          user(
            id: '2',
            name: 'Zoe Manager',
            email: 'zoe@example.com',
            hubIds: const ['hub-south'],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'north');
      await tester.pump();

      expect(find.text('Alex Staff'), findsOneWidget);
      expect(find.text('Zoe Manager'), findsNothing);
    });

    testWidgets('filters contacts by hub and team', (tester) async {
      await tester.pumpWidget(
        buildScreen([
          user(
            id: '1',
            name: 'Alex Staff',
            email: 'alex@example.com',
            teamIds: const ['team-north'],
          ),
          user(
            id: '2',
            name: 'Zoe Manager',
            email: 'zoe@example.com',
            teamIds: const ['team-south'],
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('North Hub').last);
      await tester.pumpAndSettle();

      expect(find.text('Alex Staff'), findsOneWidget);
      expect(find.text('Zoe Manager'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('North Stars').last);
      await tester.pumpAndSettle();

      expect(find.text('Alex Staff'), findsOneWidget);
      expect(find.text('Zoe Manager'), findsNothing);
    });

    testWidgets('staff sees only assignments shared with the viewer', (
      tester,
    ) async {
      final staffViewer = user(
        id: 'viewer',
        name: 'North Staff',
        email: 'viewer@example.com',
        teamIds: const ['team-north'],
      );
      await tester.pumpWidget(
        buildScreen(
          [
            user(
              id: '1',
              name: 'Multi Hub Contact',
              email: 'multi@example.com',
              teamIds: const ['team-north', 'team-south'],
            ),
          ],
          viewer: staffViewer,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('North Hub'), findsOneWidget);
      expect(find.text('South Hub'), findsNothing);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('North Stars'), findsOneWidget);
      expect(find.text('South Storm'), findsNothing);
    });

    testWidgets('opens a contact profile with title and contact details', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildScreen([
          user(
            id: '1',
            name: 'Alex Staff',
            email: 'alex@example.com',
            title: 'Equipment Manager',
            phone: '555-0144',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex Staff'));
      await tester.pumpAndSettle();

      expect(find.text('Equipment Manager'), findsWidgets);
      expect(find.text('555-0144'), findsOneWidget);
      expect(find.text('alex@example.com'), findsOneWidget);
      expect(find.text('Address'), findsNothing);
    });

    testWidgets('shows empty contact state', (tester) async {
      await tester.pumpWidget(buildScreen([]));
      await tester.pumpAndSettle();

      expect(find.text('No contacts yet.'), findsOneWidget);
    });

    testWidgets('shows not found state for missing profile', (tester) async {
      await tester.pumpWidget(
        buildScreen([], initialLocation: '/contacts/missing-user'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile not found.'), findsOneWidget);
    });

    testWidgets('remains usable on a small phone and in landscape', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;

      for (final size in const [Size(375, 667), Size(667, 375)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(buildScreen(
          [
            user(
              id: '1',
              name: 'Alex Staff',
              email: 'alex@example.com',
              teamIds: const ['team-north'],
            ),
          ],
          themeMode: ThemeMode.dark,
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.tune));
        await tester.pumpAndSettle();

        expect(find.text('FILTER CONTACTS'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
