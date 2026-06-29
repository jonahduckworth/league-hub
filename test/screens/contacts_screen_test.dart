import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';
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

    AppUser user({
      required String id,
      required String name,
      required String email,
      String? title,
      String? phone,
      String? address,
      UserRole role = UserRole.staff,
      bool isActive = true,
    }) {
      return AppUser(
        id: id,
        email: email,
        displayName: name,
        title: title,
        phone: phone,
        address: address,
        role: role,
        orgId: 'org-1',
        hubIds: const [],
        teamIds: const [],
        createdAt: DateTime(2026),
        isActive: isActive,
      );
    }

    Widget buildScreen(
      List<AppUser> users, {
      String initialLocation = '/contacts',
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
          leaguesProvider.overrideWith((ref) => Stream.value([league])),
          orgUsersProvider.overrideWith((ref) => Stream.value(users)),
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

    testWidgets('shows active contacts with titles and no emails',
        (tester) async {
      await tester.pumpWidget(buildScreen([
        user(
          id: '2',
          name: 'Zoe Manager',
          email: 'zoe@example.com',
          title: 'Head Coach',
          role: UserRole.managerAdmin,
        ),
        user(
          id: '1',
          name: 'Alex Staff',
          email: 'alex@example.com',
          title: 'Trainer',
        ),
        user(
          id: '3',
          name: 'Inactive Person',
          email: 'inactive@example.com',
          isActive: false,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Alex Staff'), findsOneWidget);
      expect(find.text('Trainer'), findsOneWidget);
      expect(find.text('alex@example.com'), findsNothing);
      expect(find.text('Staff'), findsNothing);
      expect(find.text('Zoe Manager'), findsOneWidget);
      expect(find.text('Head Coach'), findsOneWidget);
      expect(find.text('zoe@example.com'), findsNothing);
      expect(find.text('Manager'), findsNothing);
      expect(find.text('Inactive Person'), findsNothing);
    });

    testWidgets('opens a contact profile with title and contact details',
        (tester) async {
      await tester.pumpWidget(buildScreen([
        user(
          id: '1',
          name: 'Alex Staff',
          email: 'alex@example.com',
          title: 'Equipment Manager',
          phone: '555-0144',
          address: '12 Home Bench',
        ),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alex Staff'));
      await tester.pumpAndSettle();

      expect(find.text('Equipment Manager'), findsWidgets);
      expect(find.text('555-0144'), findsOneWidget);
      expect(find.text('12 Home Bench'), findsOneWidget);
      expect(find.text('alex@example.com'), findsNothing);
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
  });
}
