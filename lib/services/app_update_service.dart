import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppUpdatePlatform { android, ios, unsupported }

enum AppUpdateStatus { upToDate, updateRequired, unavailable }

class AppUpdateCheckResult {
  final AppUpdateStatus status;
  final AppUpdatePlatform platform;
  final String installedVersion;
  final String? availableVersion;
  final String? storeUrl;
  final bool immediateUpdateAllowed;

  const AppUpdateCheckResult({
    required this.status,
    required this.platform,
    required this.installedVersion,
    this.availableVersion,
    this.storeUrl,
    this.immediateUpdateAllowed = false,
  });

  bool get isUpdateRequired => status == AppUpdateStatus.updateRequired;

  factory AppUpdateCheckResult.unavailable({
    AppUpdatePlatform platform = AppUpdatePlatform.unsupported,
    String installedVersion = '',
  }) {
    return AppUpdateCheckResult(
      status: AppUpdateStatus.unavailable,
      platform: platform,
      installedVersion: installedVersion,
    );
  }
}

abstract interface class AppUpdateService {
  Future<AppUpdateCheckResult> checkForUpdate();

  Future<bool> launchUpdate(AppUpdateCheckResult update);
}

int compareAppVersions(String left, String right) {
  final leftParts = _parseVersion(left);
  final rightParts = _parseVersion(right);
  if (leftParts == null || rightParts == null) {
    throw const FormatException(
      'App versions must contain only numbers and dots',
    );
  }

  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < length; index++) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}

List<int>? _parseVersion(String version) {
  final normalized = version.trim();
  if (!RegExp(r'^\d+(?:\.\d+)*$').hasMatch(normalized)) return null;
  return normalized.split('.').map(int.parse).toList(growable: false);
}

AppUpdateCheckResult appStoreResultFromLookup({
  required String installedVersion,
  required Object? responseData,
}) {
  try {
    final decoded = responseData is String
        ? jsonDecode(responseData) as Map<String, dynamic>
        : Map<String, dynamic>.from(responseData! as Map);
    final results = decoded['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return AppUpdateCheckResult.unavailable(
        platform: AppUpdatePlatform.ios,
        installedVersion: installedVersion,
      );
    }

    final app = Map<String, dynamic>.from(results.first as Map);
    final availableVersion = app['version'] as String?;
    final storeUrl = app['trackViewUrl'] as String?;
    if (availableVersion == null ||
        storeUrl == null ||
        !storeUrl.startsWith('https://')) {
      return AppUpdateCheckResult.unavailable(
        platform: AppUpdatePlatform.ios,
        installedVersion: installedVersion,
      );
    }

    final comparison = compareAppVersions(installedVersion, availableVersion);
    return AppUpdateCheckResult(
      status: comparison < 0
          ? AppUpdateStatus.updateRequired
          : AppUpdateStatus.upToDate,
      platform: AppUpdatePlatform.ios,
      installedVersion: installedVersion,
      availableVersion: availableVersion,
      storeUrl: storeUrl,
    );
  } catch (_) {
    return AppUpdateCheckResult.unavailable(
      platform: AppUpdatePlatform.ios,
      installedVersion: installedVersion,
    );
  }
}

class StoreAppUpdateService implements AppUpdateService {
  static const _androidChannel = MethodChannel('league_hub/app_update');
  static const _appStoreLookupUrl = 'https://itunes.apple.com/lookup';

  final Dio _dio;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final AppUpdatePlatform Function() _platformResolver;

  StoreAppUpdateService({
    Dio? dio,
    Future<PackageInfo> Function()? packageInfoLoader,
    AppUpdatePlatform Function()? platformResolver,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 5),
                receiveTimeout: const Duration(seconds: 5),
                sendTimeout: const Duration(seconds: 5),
              ),
            ),
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _platformResolver = platformResolver ?? _defaultPlatform;

  static AppUpdatePlatform _defaultPlatform() {
    if (kIsWeb) return AppUpdatePlatform.unsupported;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AppUpdatePlatform.android,
      TargetPlatform.iOS => AppUpdatePlatform.ios,
      _ => AppUpdatePlatform.unsupported,
    };
  }

  @override
  Future<AppUpdateCheckResult> checkForUpdate() async {
    final platform = _platformResolver();
    if (platform == AppUpdatePlatform.unsupported) {
      return AppUpdateCheckResult.unavailable();
    }

    PackageInfo packageInfo;
    try {
      packageInfo = await _packageInfoLoader();
    } catch (_) {
      return AppUpdateCheckResult.unavailable(platform: platform);
    }

    switch (platform) {
      case AppUpdatePlatform.android:
        return _checkGooglePlay(packageInfo);
      case AppUpdatePlatform.ios:
        return _checkAppStore(packageInfo);
      case AppUpdatePlatform.unsupported:
        return AppUpdateCheckResult.unavailable();
    }
  }

  Future<AppUpdateCheckResult> _checkGooglePlay(PackageInfo packageInfo) async {
    try {
      final response = await _androidChannel.invokeMapMethod<String, dynamic>(
        'checkForUpdate',
      );
      if (response == null) {
        return AppUpdateCheckResult.unavailable(
          platform: AppUpdatePlatform.android,
          installedVersion: packageInfo.version,
        );
      }

      final available = response['available'] == true;
      return AppUpdateCheckResult(
        status: available
            ? AppUpdateStatus.updateRequired
            : AppUpdateStatus.upToDate,
        platform: AppUpdatePlatform.android,
        installedVersion: packageInfo.version,
        availableVersion: response['availableVersionCode']?.toString(),
        storeUrl:
            'https://play.google.com/store/apps/details?id=${packageInfo.packageName}',
        immediateUpdateAllowed: response['immediateAllowed'] == true,
      );
    } catch (_) {
      return AppUpdateCheckResult.unavailable(
        platform: AppUpdatePlatform.android,
        installedVersion: packageInfo.version,
      );
    }
  }

  Future<AppUpdateCheckResult> _checkAppStore(PackageInfo packageInfo) async {
    try {
      final response = await _dio.get<Object?>(
        _appStoreLookupUrl,
        queryParameters: {'bundleId': packageInfo.packageName, 'country': 'ca'},
      );
      return appStoreResultFromLookup(
        installedVersion: packageInfo.version,
        responseData: response.data,
      );
    } catch (_) {
      return AppUpdateCheckResult.unavailable(
        platform: AppUpdatePlatform.ios,
        installedVersion: packageInfo.version,
      );
    }
  }

  @override
  Future<bool> launchUpdate(AppUpdateCheckResult update) async {
    if (!update.isUpdateRequired) return false;

    if (update.platform == AppUpdatePlatform.android &&
        update.immediateUpdateAllowed) {
      try {
        final started =
            await _androidChannel.invokeMethod<bool>('startImmediateUpdate') ??
                false;
        if (started) return true;
      } catch (_) {
        // Fall through to the store listing if Play's inline flow cannot start.
      }
    }

    final storeUrl = update.storeUrl;
    if (storeUrl == null) return false;
    try {
      return launchUrl(
        Uri.parse(storeUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
