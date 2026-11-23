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
  InfoCentreData filterData({List<Map<String, dynamic>>? hubs}) =>
      InfoCentreData(
        leagues: const [
          {'id': 'l', 'name': 'League'},
          {'id': 'other', 'name': 'Other League'},
        ],
        hubs: hubs ??
            const [
              {'id': 'south', 'name': 'South Hub', 'leagueId': 'l'},
              {'id': 'north', 'name': 'North Hub', 'leagueId': 'l'},
              {'id': 'other-hub', 'name': 'Other Hub', 'leagueId': 'other'},
            ],
        teams: const [
          {'id': 't', 'name': 'North Team', 'hubId': 'north', 'leagueId': 'l'},
        ],
        sections: [
          InfoCentreItem.fromJson({
            'id': 's',
            'title': 'Resources',
            'leagueId': 'l',
            'status': 'published',
            'audience': 'members',
          }),
          InfoCentreItem.fromJson({
            'id': 'empty',
            'title': 'Travel information',
            'leagueId': 'l',
            'hubId': 'south',
            'status': 'published',
            'audience': 'members',
          }),
        ],
        entries: [
          for (final entry in [
            {'id': 'global', 'title': 'League resource'},
            {'id': 'n', 'title': 'North resource', 'hubId': 'north'},
            {
              'id': 't',
              'title': 'Team resource',
              'hubId': 'north',
              'teamId': 't'
            },
            {'id': 'south', 'title': 'South resource', 'hubId': 'south'},
          ])
            InfoCentreItem.fromJson({
              ...entry,
              'sectionId': 's',
              'leagueId': 'l',
              'status': 'published',
              'audience': 'members',
            }),
        ],
      );

  testWidgets(
      'hub chooser filters hub and team resources while retaining league resources',
      (tester) async {
    await _pumpScreen(tester, filterData());
    await tester.tap(find.byKey(const ValueKey('info-hub-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Choose hub'), findsOneWidget);
    expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('info-hub-option-north')))
            .dy,
        lessThan(tester
            .getTopLeft(find.byKey(const ValueKey('info-hub-option-south')))
            .dy));
    await tester.tap(find.byKey(const ValueKey('info-hub-option-north')));
    await tester.pumpAndSettle();
    expect(find.text('League resource'), findsOneWidget);
    expect(find.text('North resource'), findsOneWidget);
    expect(find.text('Team resource'), findsOneWidget);
    expect(find.text('South resource'), findsNothing);
    expect(find.text('Travel information'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('info-hub-filter')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('info-hub-option-north')),
            matching: find.byIcon(Icons.check_circle)),
        findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Other League');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('info-hub-option-other-hub')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('info-hub-option-north')), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('North resource'), findsOneWidget);
    expect(find.text('South resource'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('info-hub-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('info-hub-option-')));
    await tester.pumpAndSettle();
    expect(find.text('South resource'), findsOneWidget);
  });

  testWidgets(
      'long hub list is searchable and bounded on a small phone with large text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 812);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    final hubs = [
      for (var i = 39; i >= 0; i--)
        {
          'id': 'h$i',
          'name': 'Hub ${i.toString().padLeft(2, '0')} with a long name',
          'leagueId': 'l'
        },
    ];
    await _pumpScreen(tester, filterData(hubs: hubs), textScale: 2);
    await tester.tap(find.byKey(const ValueKey('info-hub-filter')));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('info-hub-picker'));
    expect(tester.getSize(picker).height, lessThan(812 * 0.8));
    expect(find.byKey(const ValueKey('info-hub-option-h39')), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'Hub 39');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(picker).dy, lessThanOrEqualTo(512));
    final result = find.byKey(const ValueKey('info-hub-option-h39'));
    await tester.scrollUntilVisible(result, 120,
        scrollable: find.descendant(
            of: picker,
            matching: find.byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down)));
    await tester.pumpAndSettle();
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.text('Hub 39 with a long name'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding();
    tester.view.physicalSize = const Size(812, 375);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('info-hub-filter')));
    await tester.pumpAndSettle();
    expect(tester.getSize(picker).height, lessThan(375 * 0.8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmatched hub search still offers all hubs and can be cleared',
      (tester) async {
    await _pumpScreen(tester, filterData());
    await tester.tap(find.byKey(const ValueKey('info-hub-filter')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'missing hub');
    await tester.pumpAndSettle();
    expect(find.text('No hubs match your search.'), findsOneWidget);
    expect(find.byKey(const ValueKey('info-hub-option-')), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('No hubs match your search.'), findsNothing);
    expect(find.byKey(const ValueKey('info-hub-option-north')), findsOneWidget);
  });

  testWidgets('empty sections explain the absence of published resources',
      (tester) async {
    await _pumpScreen(tester, filterData());
    await tester.scrollUntilVisible(find.text('Travel information'), 200);
    await tester.pumpAndSettle();
    expect(
        find.text('No published resources in this section.'), findsOneWidget);
    expect(find.text('No resources yet'), findsNothing);
  });

  testWidgets('no sections shows the global empty state', (tester) async {
    await _pumpScreen(tester, const InfoCentreData());
    expect(find.text('No resources yet'), findsOneWidget);
    expect(find.text('No published resources in this section.'), findsNothing);
  });

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

Future<void> _pumpScreen(WidgetTester tester, InfoCentreData data,
    {double textScale = 1}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => AppUser(
          id: 'u',
          email: 'u@example.com',
          displayName: 'Member',
          role: UserRole.staff,
          orgId: 'org',
          hubIds: ['north', 'south'],
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
      leaguesProvider.overrideWith((ref) => Stream.value(<League>[])),
      infoCentreProvider.overrideWith((ref) => data),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale), disableAnimations: true),
        child: child!,
      ),
      home: const InfoCentreScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}
