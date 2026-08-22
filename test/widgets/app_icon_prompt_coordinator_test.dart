import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/league.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/services/app_icon_prompt_preferences.dart';
import 'package:league_hub/services/app_icon_service.dart';
import 'package:league_hub/widgets/app_icon_prompt_coordinator.dart';

class _FakeAppIconService extends AppIconService {
  bool supported = true;
  String currentIconId = 'default';
  String? appliedIconId;
  bool failOnApply = false;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<String> getCurrentIconId() async => currentIconId;

  @override
  Future<void> setIcon(String iconId) async {
    if (failOnApply) throw StateError('native failure');
    appliedIconId = iconId;
    currentIconId = iconId;
  }
}

class _FakePromptPreferences implements AppIconPromptPreferences {
  final Set<String> campaignDismissals = {};
  final Set<String> permanentDismissals = {};

  String _campaignKey(String userId, String iconId, String campaign) =>
      '$userId:$iconId:$campaign';

  String _permanentKey(String userId, String iconId) => '$userId:$iconId';

  @override
  Future<void> dismissForCampaign({
    required String userId,
    required String iconId,
    required String campaign,
  }) async {
    campaignDismissals.add(_campaignKey(userId, iconId, campaign));
  }

  @override
  Future<bool> isSuppressed({
    required String userId,
    required String iconId,
    required String campaign,
  }) async {
    return permanentDismissals.contains(_permanentKey(userId, iconId)) ||
        campaignDismissals.contains(_campaignKey(userId, iconId, campaign));
  }

  @override
  Future<void> neverAskAgain({
    required String userId,
    required String iconId,
  }) async {
    permanentDismissals.add(_permanentKey(userId, iconId));
  }
}

AppUser _user({String id = 'user-1'}) => AppUser(
      id: id,
      email: '$id@example.com',
      displayName: 'Test User',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: const [],
      teamIds: const [],
      createdAt: DateTime(2026),
      isActive: true,
    );

League _league({
  String id = 'jphl',
  String name = 'Junior Prospects Hockey League',
  String abbreviation = 'JPHL',
}) =>
    League(
      id: id,
      orgId: 'org-1',
      name: name,
      abbreviation: abbreviation,
      createdAt: DateTime(2026),
    );

Widget _testWidget({
  required _FakeAppIconService iconService,
  required _FakePromptPreferences preferences,
  List<League>? leagues,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) async => _user()),
      leaguesProvider.overrideWith(
        (ref) => Stream.value(leagues ?? [_league()]),
      ),
      appIconServiceProvider.overrideWithValue(iconService),
      appIconPromptPreferencesProvider.overrideWithValue(preferences),
    ],
    child: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: const MaterialApp(
        home: AppIconPromptCoordinator(
          child: Scaffold(body: Text('Signed-in app')),
        ),
      ),
    ),
  );
}

void main() {
  group('AppIconPromptCoordinator', () {
    testWidgets('offers the JPHL icon to an eligible signed-in user',
        (tester) async {
      await tester.pumpWidget(_testWidget(
        iconService: _FakeAppIconService(),
        preferences: _FakePromptPreferences(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Use the JPHL app icon?'), findsOneWidget);
      expect(find.text('Use JPHL Icon'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
    });

    testWidgets('does not prompt non-JPHL users', (tester) async {
      await tester.pumpWidget(_testWidget(
        iconService: _FakeAppIconService(),
        preferences: _FakePromptPreferences(),
        leagues: [
          _league(id: 'spring', name: 'Spring League', abbreviation: 'SL'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Use the JPHL app icon?'), findsNothing);
    });

    testWidgets('does not prompt when the JPHL icon is already active',
        (tester) async {
      final iconService = _FakeAppIconService()..currentIconId = 'jphl';
      await tester.pumpWidget(_testWidget(
        iconService: iconService,
        preferences: _FakePromptPreferences(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Use the JPHL app icon?'), findsNothing);
    });

    testWidgets('does not prompt on an unsupported device', (tester) async {
      final iconService = _FakeAppIconService()..supported = false;
      await tester.pumpWidget(_testWidget(
        iconService: iconService,
        preferences: _FakePromptPreferences(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Use the JPHL app icon?'), findsNothing);
    });

    testWidgets('uses the JPHL icon and dismisses the campaign after success',
        (tester) async {
      final iconService = _FakeAppIconService();
      final preferences = _FakePromptPreferences();
      await tester.pumpWidget(_testWidget(
        iconService: iconService,
        preferences: preferences,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use JPHL Icon'));
      await tester.pumpAndSettle();

      expect(iconService.appliedIconId, 'jphl');
      expect(preferences.campaignDismissals, isNotEmpty);
      expect(find.text('JPHL app icon selected'), findsOneWidget);
    });

    testWidgets('not now dismisses only the current prompt campaign',
        (tester) async {
      final preferences = _FakePromptPreferences();
      await tester.pumpWidget(_testWidget(
        iconService: _FakeAppIconService(),
        preferences: preferences,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(preferences.campaignDismissals, isNotEmpty);
      expect(preferences.permanentDismissals, isEmpty);
    });

    testWidgets('never ask again permanently suppresses the device prompt',
        (tester) async {
      final preferences = _FakePromptPreferences();
      await tester.pumpWidget(_testWidget(
        iconService: _FakeAppIconService(),
        preferences: preferences,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Don\'t ask again on this device'));
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(preferences.permanentDismissals, contains('user-1:jphl'));
      expect(preferences.campaignDismissals, isEmpty);
    });

    testWidgets('dialog remains usable at maximum Dynamic Type',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_testWidget(
        iconService: _FakeAppIconService(),
        preferences: _FakePromptPreferences(),
        textScaler: const TextScaler.linear(3.2),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Use the JPHL app icon?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('native failures leave Settings as a retry path',
        (tester) async {
      final iconService = _FakeAppIconService()..failOnApply = true;
      final preferences = _FakePromptPreferences();
      await tester.pumpWidget(_testWidget(
        iconService: iconService,
        preferences: preferences,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use JPHL Icon'));
      await tester.pumpAndSettle();

      expect(find.textContaining('try again in Settings'), findsOneWidget);
      expect(preferences.campaignDismissals, isEmpty);
    });
  });
}
