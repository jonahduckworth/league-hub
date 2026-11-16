import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/hub.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/models/team.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/contact_profile_screen.dart';

void main() {
  group('ContactProfileScreen', () {
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    final contact = AppUser(
      id: 'user-1',
      email: 'lily+team@example.com',
      displayName: 'Lily Carter',
      title: 'Head Coach',
      phone: '+1 (403) 555-0101',
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
          currentUserProvider.overrideWith((ref) => contact),
          orgUsersProvider.overrideWith((ref) => Stream.value([contact])),
          leaguesProvider.overrideWith((ref) => Stream.value([league])),
          organizationHubsProvider.overrideWith((ref) async => [hub]),
          organizationTeamsProvider.overrideWith((ref) async => [team]),
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

    testWidgets('shows profile assignment and contact details', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Lily Carter'), findsOneWidget);
      expect(find.text('Head Coach'), findsOneWidget);
      expect(find.text(contact.email), findsOneWidget);
      expect(find.text('LEAGUE DETAILS'), findsOneWidget);
      expect(find.text('Spring League'), findsOneWidget);
      expect(find.text('Calgary Hub'), findsOneWidget);
      expect(find.text('U15 Rockies'), findsOneWidget);
      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.text(contact.phone!), findsOneWidget);
      expect(find.text('Address'), findsNothing);
    });

    testWidgets('tapping contact values opens the phone and email apps', (
      tester,
    ) async {
      final launches = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        (call) async {
          expect(call.method, 'launch');
          expect(call.arguments['useWebView'], isFalse);
          launches.add(call.arguments['url'] as String);
          return true;
        },
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text(contact.email));
      await tester.pumpAndSettle();
      await tester.tap(find.text(contact.phone!));
      await tester.pumpAndSettle();

      expect(launches, ['mailto:lily+team@example.com', 'tel:+14035550101']);
    });

    testWidgets('copy preserves contact values when the system app cannot open',
        (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final copied = <String>[];
      messenger.setMockMethodCallHandler(launcherChannel, (_) async => false);
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(call.arguments['text'] as String);
        }
        return null;
      });

      await tester.binding.setSurfaceSize(const Size(375, 667));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final phoneValue = find.text(contact.phone!);
      await tester.ensureVisible(phoneValue);
      await tester.tap(phoneValue);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t open the phone app.'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Copy'));
      await tester.pumpAndSettle();
      expect(copied, [contact.phone]);
      expect(find.text('Copied to clipboard'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy email address'));
      await tester.pumpAndSettle();

      expect(copied, [contact.phone, contact.email]);
    });
  });
}
