import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:league_hub/services/app_icon_prompt_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;
  late Box<bool> box;
  late HiveAppIconPromptPreferences preferences;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'league_hub_app_icon_preferences_',
    );
    Hive.init(temporaryDirectory.path);
    box = await Hive.openBox<bool>('app_icon_prompt_preferences_test');
    preferences = HiveAppIconPromptPreferences(box: box);
  });

  tearDown(() async {
    await box.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('campaign dismissal is scoped to the user, icon, and campaign',
      () async {
    await preferences.dismissForCampaign(
      userId: 'user-1',
      iconId: 'jphl',
      campaign: 'campaign-1',
    );

    expect(
      await preferences.isSuppressed(
        userId: 'user-1',
        iconId: 'jphl',
        campaign: 'campaign-1',
      ),
      isTrue,
    );
    expect(
      await preferences.isSuppressed(
        userId: 'user-1',
        iconId: 'jphl',
        campaign: 'campaign-2',
      ),
      isFalse,
    );
    expect(
      await preferences.isSuppressed(
        userId: 'user-2',
        iconId: 'jphl',
        campaign: 'campaign-1',
      ),
      isFalse,
    );
  });

  test('never ask again suppresses future campaigns on the same device',
      () async {
    await preferences.neverAskAgain(userId: 'user-1', iconId: 'jphl');

    expect(
      await preferences.isSuppressed(
        userId: 'user-1',
        iconId: 'jphl',
        campaign: 'future-campaign',
      ),
      isTrue,
    );
    expect(
      await preferences.isSuppressed(
        userId: 'user-1',
        iconId: 'hockey',
        campaign: 'future-campaign',
      ),
      isFalse,
    );
  });
}
