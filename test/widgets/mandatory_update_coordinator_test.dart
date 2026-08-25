import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/app_update_service.dart';
import 'package:league_hub/widgets/mandatory_update_coordinator.dart';

class _FakeAppUpdateService implements AppUpdateService {
  AppUpdateCheckResult result;
  bool launchResult;
  int checkCount = 0;
  int launchCount = 0;

  _FakeAppUpdateService({required this.result, this.launchResult = true});

  @override
  Future<AppUpdateCheckResult> checkForUpdate() async {
    checkCount += 1;
    return result;
  }

  @override
  Future<bool> launchUpdate(AppUpdateCheckResult update) async {
    launchCount += 1;
    return launchResult;
  }
}

AppUpdateCheckResult _requiredUpdate() => const AppUpdateCheckResult(
      status: AppUpdateStatus.updateRequired,
      platform: AppUpdatePlatform.ios,
      installedVersion: '1.0.3',
      availableVersion: '1.0.4',
      storeUrl: 'https://apps.apple.com/app/id123',
    );

Widget _testWidget(
  _FakeAppUpdateService service, {
  Stream<List<ConnectivityResult>>? connectivityChanges,
  VoidCallback? onContentTap,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: MandatoryUpdateCoordinator(
        updateService: service,
        connectivityChanges: connectivityChanges ?? const Stream.empty(),
        child: Scaffold(
          body: TextButton(
            onPressed: onContentTap,
            child: const Text('App content'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('does not block the app when it is up to date', (tester) async {
    final service = _FakeAppUpdateService(
      result: const AppUpdateCheckResult(
        status: AppUpdateStatus.upToDate,
        platform: AppUpdatePlatform.ios,
        installedVersion: '1.0.4',
        availableVersion: '1.0.4',
      ),
    );

    await tester.pumpWidget(_testWidget(service));
    await tester.pump();

    expect(find.text('Update required'), findsNothing);
    expect(find.text('App content'), findsOneWidget);
  });

  testWidgets('blocks app interaction and offers only the update action', (
    tester,
  ) async {
    var contentTapCount = 0;
    final service = _FakeAppUpdateService(result: _requiredUpdate());

    await tester.pumpWidget(
      _testWidget(service, onContentTap: () => contentTapCount += 1),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('App content'), warnIfMissed: false);
    expect(contentTapCount, 0);

    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();
    expect(service.launchCount, 1);
  });

  testWidgets('shows a retryable message when the store cannot open', (
    tester,
  ) async {
    final service = _FakeAppUpdateService(
      result: _requiredUpdate(),
      launchResult: false,
    );

    await tester.pumpWidget(_testWidget(service));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(
      find.text('The store could not be opened. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('rechecks after connectivity returns', (tester) async {
    final connectivity = StreamController<List<ConnectivityResult>>();
    final service = _FakeAppUpdateService(
      result: AppUpdateCheckResult.unavailable(platform: AppUpdatePlatform.ios),
    );

    await tester.pumpWidget(
      _testWidget(service, connectivityChanges: connectivity.stream),
    );
    await tester.pump();
    final initialChecks = service.checkCount;

    connectivity.add(const [ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump();

    expect(service.checkCount, initialChecks + 1);
    await connectivity.close();
  });

  testWidgets(
    'remains usable at large text sizes on a small landscape screen',
    (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _FakeAppUpdateService(result: _requiredUpdate());
      await tester.pumpWidget(
        _testWidget(service, textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Update now'), findsOneWidget);
      await tester.ensureVisible(find.text('Update now'));
      await tester.tap(find.text('Update now'));
      await tester.pumpAndSettle();
      expect(service.launchCount, 1);
    },
  );

  testWidgets('fits a 375-point-wide phone in portrait', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeAppUpdateService(result: _requiredUpdate());
    await tester.pumpWidget(_testWidget(service));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });
}
