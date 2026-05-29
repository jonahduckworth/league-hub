import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const appIconOptions = [
  AppIconOption(
    id: 'default',
    nativeName: null,
    name: 'Default',
    description: 'The standard League Hub icon',
    assetPath: 'assets/app_icons/default.png',
  ),
  AppIconOption(
    id: 'jphl',
    nativeName: 'AppIconJphl',
    name: 'JPHL',
    description: 'Junior Prospects Hockey League badge',
    assetPath: 'assets/app_icons/jphl.png',
  ),
  AppIconOption(
    id: 'soccer',
    nativeName: 'AppIconSoccer',
    name: 'Soccer',
    description: 'Soccer ball icon',
    assetPath: 'assets/app_icons/soccer.png',
  ),
  AppIconOption(
    id: 'basketball',
    nativeName: 'AppIconBasketball',
    name: 'Basketball',
    description: 'Basketball icon',
    assetPath: 'assets/app_icons/basketball.png',
  ),
  AppIconOption(
    id: 'football',
    nativeName: 'AppIconFootball',
    name: 'Football',
    description: 'Football icon',
    assetPath: 'assets/app_icons/football.png',
  ),
  AppIconOption(
    id: 'baseball',
    nativeName: 'AppIconBaseball',
    name: 'Baseball',
    description: 'Baseball icon',
    assetPath: 'assets/app_icons/baseball.png',
  ),
  AppIconOption(
    id: 'hockey',
    nativeName: 'AppIconHockey',
    name: 'Hockey',
    description: 'Hockey icon',
    assetPath: 'assets/app_icons/hockey.png',
  ),
  AppIconOption(
    id: 'tennis',
    nativeName: 'AppIconTennis',
    name: 'Tennis',
    description: 'Tennis icon',
    assetPath: 'assets/app_icons/tennis.png',
  ),
  AppIconOption(
    id: 'trophy',
    nativeName: 'AppIconTrophy',
    name: 'Trophy',
    description: 'Championship trophy icon',
    assetPath: 'assets/app_icons/trophy.png',
  ),
];

final appIconServiceProvider = Provider<AppIconService>(
  (ref) => const AppIconService(),
);

class AppIconOption {
  final String id;
  final String? nativeName;
  final String name;
  final String description;
  final String assetPath;

  const AppIconOption({
    required this.id,
    required this.nativeName,
    required this.name,
    required this.description,
    required this.assetPath,
  });
}

class AppIconService {
  static const _channel = MethodChannel('league_hub/app_icon');

  const AppIconService();

  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<String> getCurrentIconId() async {
    try {
      final nativeName =
          await _channel.invokeMethod<String?>('getCurrentIconName');
      return _idForNativeName(nativeName);
    } on MissingPluginException {
      return 'default';
    }
  }

  Future<void> setIcon(String iconId) async {
    final option = appIconOptions.firstWhere(
      (option) => option.id == iconId,
      orElse: () => throw ArgumentError.value(iconId, 'iconId'),
    );
    try {
      await _channel.invokeMethod<void>(
        'setIcon',
        {'iconName': option.nativeName},
      );
    } on MissingPluginException {
      throw const AppIconUnsupportedException();
    }
  }

  String _idForNativeName(String? nativeName) {
    if (nativeName == null || nativeName.isEmpty) return 'default';
    return appIconOptions
        .firstWhere(
          (option) => option.nativeName == nativeName,
          orElse: () => appIconOptions.first,
        )
        .id;
  }
}

class AppIconUnsupportedException implements Exception {
  const AppIconUnsupportedException();

  @override
  String toString() =>
      'Alternate app icons are only available on iOS and Android devices.';
}
