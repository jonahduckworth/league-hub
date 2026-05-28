import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/app_icon_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('league_hub/app_icon');
  const service = AppIconService();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isSupported returns native support result', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'isSupported');
      return true;
    });

    expect(await service.isSupported(), isTrue);
  });

  test('getCurrentIconId maps null native icon to default', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getCurrentIconName');
      return null;
    });

    expect(await service.getCurrentIconId(), 'default');
  });

  test('getCurrentIconId maps native name to app option id', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getCurrentIconName');
      return 'AppIconJphl';
    });

    expect(await service.getCurrentIconId(), 'jphl');
  });

  test('setIcon passes native icon name', () async {
    String? iconName;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setIcon');
      iconName =
          (call.arguments as Map<Object?, Object?>)['iconName'] as String?;
      return null;
    });

    await service.setIcon('hockey');

    expect(iconName, 'AppIconHockey');
  });

  test('setIcon passes null for default icon', () async {
    Object? iconName = 'unset';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setIcon');
      iconName = (call.arguments as Map<Object?, Object?>)['iconName'];
      return null;
    });

    await service.setIcon('default');

    expect(iconName, isNull);
  });
}
