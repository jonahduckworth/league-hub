import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appBadgeServiceProvider = Provider<AppBadgeService>(
  (ref) => const NativeAppBadgeService(),
);

abstract interface class AppBadgeService {
  Future<void> setBadgeCount(int count);
}

class NativeAppBadgeService implements AppBadgeService {
  static const _channel = MethodChannel('league_hub/app_icon');

  const NativeAppBadgeService();

  @override
  Future<void> setBadgeCount(int count) async {
    try {
      await _channel.invokeMethod<void>(
        'setBadgeCount',
        {'count': count < 0 ? 0 : count},
      );
    } on MissingPluginException {
      // App-icon badges are not available on every platform or launcher.
    } on PlatformException {
      // Badge synchronization is best effort and must not interrupt app use.
    }
  }
}
