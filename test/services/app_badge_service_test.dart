import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/app_badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('league_hub/app_icon');
  const service = NativeAppBadgeService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('publishes the unread count to the native app icon', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      receivedCall = call;
      return null;
    });

    await service.setBadgeCount(4);

    expect(receivedCall?.method, 'setBadgeCount');
    expect(receivedCall?.arguments, {'count': 4});
  });

  test('clamps negative badge counts to zero', () async {
    Object? arguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      arguments = call.arguments;
      return null;
    });

    await service.setBadgeCount(-2);

    expect(arguments, {'count': 0});
  });

  test('unsupported platforms do not fail badge synchronization', () async {
    await expectLater(service.setBadgeCount(3), completes);
  });

  test('native badge failures do not interrupt app use', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'badges_disabled');
    });

    await expectLater(service.setBadgeCount(3), completes);
  });
}
