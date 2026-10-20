import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/info_centre.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/info_centre_screen.dart';

void main() {
  final data = InfoCentreData.fromJson({
    'structure': {
      'leagues': [
        {'id': 'l', 'name': 'League'}
      ],
      'hubs': [
        {'id': 'h', 'name': 'Hub', 'leagueId': 'l'}
      ],
      'teams': [
        {'id': 't', 'name': 'Team', 'hubId': 'h', 'leagueId': 'l'}
      ]
    },
    'sections': [
      {
        'id': 's',
        'title': 'Registration',
        'leagueId': 'l',
        'hubId': 'h',
        'status': 'published',
        'audience': 'members'
      }
    ],
    'entries': [
      {
        'id': 'e',
        'title': 'Team registration',
        'sectionId': 's',
        'leagueId': 'l',
        'hubId': 'h',
        'teamId': 't',
        'status': 'published',
        'audience': 'members',
        'kind': 'registration',
        'inviteCode': 'example-code',
        'url': 'https://example.com/register',
        'hasPassword': true,
        'canReveal': false
      }
    ],
  });
  for (final role in UserRole.values) {
    testWidgets('$role sees resources and only authorized password controls',
        (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [
        currentUserProvider.overrideWith((ref) => AppUser(
            id: 'u',
            email: 'u@example.com',
            displayName: 'Member',
            role: role,
            orgId: 'org',
            hubIds: ['h'],
            teamIds: ['t'],
            createdAt: DateTime(2026),
            isActive: true)),
        organizationProvider.overrideWith((ref) => Organization(
            id: 'org',
            name: 'Org',
            primaryColor: '#000000',
            secondaryColor: '#000000',
            accentColor: '#000000',
            createdAt: DateTime(2026),
            ownerId: 'admin')),
        leaguesProvider.overrideWith((ref) => Stream.value([
              League(
                  id: 'other',
                  orgId: 'org',
                  name: 'Other League',
                  abbreviation: 'OL',
                  createdAt: DateTime(2026)),
              League(
                  id: 'l',
                  orgId: 'org',
                  name: 'Test League',
                  abbreviation: 'TL',
                  logoUrl: 'https://example.com/league.png',
                  createdAt: DateTime(2026))
            ])),
        infoCentreProvider.overrideWith((ref) => data),
      ], child: const MaterialApp(home: InfoCentreScreen())));
      await tester.pumpAndSettle();
      final logo =
          tester.widget<AppHeaderLogoMark>(find.byType(AppHeaderLogoMark));
      expect(logo.imageUrl, 'https://example.com/league.png');
      expect(logo.label, 'Test League');
      expect(find.byTooltip('Profile'), findsNothing);
      expect(find.text('Team registration'), findsOneWidget);
      expect(find.text('Open registration'), findsOneWidget);
      expect(find.byTooltip('Copy invite code'), findsOneWidget);
      expect(find.text('Reveal password'), findsNothing);
      expect(find.text('Manage in portal'),
          role == UserRole.staff ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test('hub filter includes league resources and rejects other hub resources',
      () {
    final global = InfoCentreItem.fromJson({
      'id': 'g',
      'title': 'Website',
      'leagueId': 'l',
      'status': 'published',
      'audience': 'members'
    });
    final foreign = InfoCentreItem.fromJson({
      'id': 'o',
      'title': 'Other',
      'leagueId': 'l',
      'hubId': 'other',
      'status': 'published',
      'audience': 'members'
    });
    expect(data.visibleInHub(global, 'h'), isTrue);
    expect(data.visibleInHub(foreign, 'h'), isFalse);
    expect(data.scopeLabel(data.entries.single), 'Team');
  });
}
