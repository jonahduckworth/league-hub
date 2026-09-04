import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{"resultCount":1,"results":[{"version":"1.0.7",'
      '"trackViewUrl":"https://apps.apple.com/ca/app/league-hub/'
      'id6774679631"}]}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('compareAppVersions', () {
    test('compares each numeric version component', () {
      expect(compareAppVersions('1.0.3', '1.0.4'), lessThan(0));
      expect(compareAppVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareAppVersions('2.0', '2.0.0'), 0);
    });

    test('rejects non-numeric versions instead of guessing', () {
      expect(
        () => compareAppVersions('1.0.4-beta', '1.0.4'),
        throwsFormatException,
      );
    });
  });

  group('appStoreResultFromLookup', () {
    test('requires an update when the App Store version is newer', () {
      final result = appStoreResultFromLookup(
        installedVersion: '1.0.3',
        responseData: {
          'resultCount': 1,
          'results': [
            {
              'version': '1.0.4',
              'trackViewUrl': 'https://apps.apple.com/ca/app/example/id123',
            },
          ],
        },
      );

      expect(result.status, AppUpdateStatus.updateRequired);
      expect(result.availableVersion, '1.0.4');
      expect(result.platform, AppUpdatePlatform.ios);
    });

    test('accepts the current or a newer installed version', () {
      final result = appStoreResultFromLookup(
        installedVersion: '1.0.4',
        responseData: '{"resultCount":1,"results":[{"version":"1.0.4",'
            '"trackViewUrl":"https://apps.apple.com/app/id123"}]}',
      );

      expect(result.status, AppUpdateStatus.upToDate);
    });

    test('fails open when the lookup response cannot prove an update', () {
      final missingApp = appStoreResultFromLookup(
        installedVersion: '1.0.3',
        responseData: const {'resultCount': 0, 'results': []},
      );
      final malformedVersion = appStoreResultFromLookup(
        installedVersion: '1.0.3',
        responseData: {
          'results': [
            {
              'version': 'latest',
              'trackViewUrl': 'https://apps.apple.com/app/id123',
            },
          ],
        },
      );

      expect(missingApp.status, AppUpdateStatus.unavailable);
      expect(malformedVersion.status, AppUpdateStatus.unavailable);
    });
  });

  group('StoreAppUpdateService iOS lookup', () {
    test('uses the numeric App Store ID and a five-minute cache bucket',
        () async {
      final adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final now = DateTime.utc(2026, 9, 4, 15, 8, 44);
      final service = StoreAppUpdateService(
        dio: dio,
        packageInfoLoader: () async => PackageInfo(
          appName: 'League Hub',
          packageName: 'ca.jdbuilds.leaguehub',
          version: '1.0.6',
          buildNumber: '17',
        ),
        platformResolver: () => AppUpdatePlatform.ios,
        now: () => now,
      );

      final result = await service.checkForUpdate();

      expect(result.status, AppUpdateStatus.updateRequired);
      expect(adapter.request?.uri.queryParameters['id'], '6774679631');
      expect(adapter.request?.uri.queryParameters, isNot(contains('bundleId')));
      expect(
        adapter.request?.uri.queryParameters['_cb'],
        '${now.millisecondsSinceEpoch ~/ const Duration(minutes: 5).inMilliseconds}',
      );
      expect(adapter.request?.headers['Cache-Control'], 'no-cache');
    });
  });
}
