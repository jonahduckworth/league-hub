import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const jphlAppIconPromptCampaign = 'jphl-icon-v1';

final appIconPromptPreferencesProvider = Provider<AppIconPromptPreferences>(
  (ref) => HiveAppIconPromptPreferences(),
);

abstract class AppIconPromptPreferences {
  Future<bool> isSuppressed({
    required String userId,
    required String iconId,
    required String campaign,
  });

  Future<void> dismissForCampaign({
    required String userId,
    required String iconId,
    required String campaign,
  });

  Future<void> neverAskAgain({
    required String userId,
    required String iconId,
  });
}

class HiveAppIconPromptPreferences implements AppIconPromptPreferences {
  static const _prefix = 'app_icon_prompt';
  static const _boxName = 'app_icon_prompt_preferences';

  final Box<bool>? _providedBox;

  const HiveAppIconPromptPreferences({Box<bool>? box}) : _providedBox = box;

  @override
  Future<bool> isSuppressed({
    required String userId,
    required String iconId,
    required String campaign,
  }) async {
    final box = await _box();
    return box.get(_neverKey(userId, iconId), defaultValue: false) == true ||
        box.get(
              _campaignKey(userId, iconId, campaign),
              defaultValue: false,
            ) ==
            true;
  }

  @override
  Future<void> dismissForCampaign({
    required String userId,
    required String iconId,
    required String campaign,
  }) async {
    final box = await _box();
    await box.put(_campaignKey(userId, iconId, campaign), true);
  }

  @override
  Future<void> neverAskAgain({
    required String userId,
    required String iconId,
  }) async {
    final box = await _box();
    await box.put(_neverKey(userId, iconId), true);
  }

  Future<Box<bool>> _box() async {
    final providedBox = _providedBox;
    if (providedBox != null) return providedBox;
    if (Hive.isBoxOpen(_boxName)) return Hive.box<bool>(_boxName);

    await Hive.initFlutter();
    return Hive.openBox<bool>(_boxName);
  }

  String _neverKey(String userId, String iconId) =>
      '$_prefix.never.$userId.$iconId';

  String _campaignKey(String userId, String iconId, String campaign) =>
      '$_prefix.campaign.$campaign.$userId.$iconId';
}
