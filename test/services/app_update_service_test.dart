import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/app_update_service.dart';

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
        responseData:
            '{"resultCount":1,"results":[{"version":"1.0.4",'
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
}
