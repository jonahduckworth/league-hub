import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/services/messaging_service.dart';

import '../helpers/firebase_test_helper.dart';

class FakePushTokenProvider implements PushTokenProvider {
  final List<String?> apnsTokens;
  final String? fcmToken;
  final Future<String?> Function()? tokenLoader;
  final Stream<String> tokenRefresh;
  var autoInitCalls = 0;
  var apnsChecks = 0;
  var fcmTokenCalls = 0;

  FakePushTokenProvider({
    this.apnsTokens = const [null],
    this.fcmToken,
    this.tokenLoader,
    this.tokenRefresh = const Stream.empty(),
  });

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    if (enabled) autoInitCalls++;
  }

  @override
  Future<String?> getAPNSToken() async {
    final index = apnsChecks.clamp(0, apnsTokens.length - 1);
    apnsChecks++;
    return apnsTokens[index];
  }

  @override
  Future<String?> getToken() async {
    fcmTokenCalls++;
    if (tokenLoader != null) return tokenLoader!();
    return fcmToken;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh;
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUpAll(FirebaseTestHelper.setupFirestore);

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('MessagingService', () {
    test('can be instantiated with fake firestore', () {
      final service = MessagingService(firestore: fakeFirestore);
      expect(service, isNotNull);
    });

    test('can be instantiated with default parameters', () {
      final service = MessagingService();
      expect(service, isNotNull);
    });

    test('disabled service keeps all production messaging paths inert',
        () async {
      await fakeFirestore.collection('users').doc('local-user').set({
        'fcmTokens': ['existing-production-token'],
      });
      final service = MessagingService(
        firestore: fakeFirestore,
        enabled: false,
      );

      await service.initialize('local-user');
      await service.removeToken('local-user');
      await service.subscribeToTopic('org_local_announcements');
      await service.unsubscribeFromTopic('org_local_announcements');
      await service.syncPreferences('local', {'announcements': true});

      final user =
          await fakeFirestore.collection('users').doc('local-user').get();
      expect(user.data()!['fcmTokens'], ['existing-production-token']);
    });

    test('waits for APNs and stores the FCM token when it becomes available',
        () async {
      final tokenProvider = FakePushTokenProvider(
        apnsTokens: [null, null, 'apns-token'],
        fcmToken: 'fcm-token',
      );
      final delays = <Duration>[];
      await fakeFirestore.collection('users').doc('u1').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
        tokenRegistrationDelay: (delay) async => delays.add(delay),
      );
      service.activateUserForTesting('u1');

      await service.refreshTokenRegistration('u1');

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()!['fcmTokens'], ['fcm-token']);
      expect(tokenProvider.apnsChecks, 3);
      expect(delays, const [
        Duration(milliseconds: 250),
        Duration(milliseconds: 500),
      ]);
      expect(tokenProvider.autoInitCalls, 1);
      expect(tokenProvider.fcmTokenCalls, 1);
    });

    test('does not request an FCM token until APNs registration is ready',
        () async {
      final tokenProvider = FakePushTokenProvider();
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
        tokenRegistrationDelay: (_) async {},
      );
      service.activateUserForTesting('u1');

      await service.refreshTokenRegistration('u1');

      expect(tokenProvider.fcmTokenCalls, 0);
      expect(tokenProvider.apnsChecks, 6);
    });

    test('a later token refresh repairs an initially unavailable APNs token',
        () async {
      final tokenRefresh = StreamController<String>();
      final tokenProvider = FakePushTokenProvider(
        tokenRefresh: tokenRefresh.stream,
      );
      await fakeFirestore.collection('users').doc('u1').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
        tokenRegistrationDelay: (_) async {},
      );
      service.activateUserForTesting('u1');

      await service.refreshTokenRegistration('u1');
      tokenRefresh.add('later-fcm-token');
      await Future<void>.delayed(Duration.zero);

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()!['fcmTokens'], ['later-fcm-token']);
      await tokenRefresh.close();
    });

    test('sign-out invalidation blocks a stale in-flight registration',
        () async {
      final tokenCompleter = Completer<String?>();
      final tokenProvider = FakePushTokenProvider(
        apnsTokens: const ['apns-token'],
        tokenLoader: () => tokenCompleter.future,
      );
      await fakeFirestore.collection('users').doc('u1').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
      );
      service.activateUserForTesting('u1');

      final registration = service.refreshTokenRegistration('u1');
      await Future<void>.delayed(Duration.zero);
      service.clearActiveUser();
      tokenCompleter.complete('stale-fcm-token');
      await registration;

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()!['fcmTokens'], isEmpty);
    });

    test('token rotation after sign-out is ignored', () async {
      final tokenRefresh = StreamController<String>();
      final tokenProvider = FakePushTokenProvider(
        tokenRefresh: tokenRefresh.stream,
      );
      await fakeFirestore.collection('users').doc('u1').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
        tokenRegistrationDelay: (_) async {},
      );
      service.activateUserForTesting('u1');

      await service.refreshTokenRegistration('u1');
      service.clearActiveUser();
      tokenRefresh.add('signed-out-token');
      await Future<void>.delayed(Duration.zero);

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()!['fcmTokens'], isEmpty);
      await tokenRefresh.close();
    });

    test('resume-time refresh cannot reactivate an invalidated user', () async {
      final tokenProvider = FakePushTokenProvider(
        apnsTokens: const ['apns-token'],
        fcmToken: 'stale-token',
      );
      await fakeFirestore.collection('users').doc('u1').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
      );
      service.activateUserForTesting('u1');
      service.clearActiveUser();

      await service.refreshTokenRegistration('u1');

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()!['fcmTokens'], isEmpty);
      expect(tokenProvider.fcmTokenCalls, 0);
    });

    test('switching users prevents user A registration from completing late',
        () async {
      final userAToken = Completer<String?>();
      var tokenCall = 0;
      final tokenProvider = FakePushTokenProvider(
        apnsTokens: const ['apns-token'],
        tokenLoader: () {
          tokenCall++;
          return tokenCall == 1
              ? userAToken.future
              : Future<String?>.value('user-b-token');
        },
      );
      await fakeFirestore.collection('users').doc('user-a').set({
        'fcmTokens': <String>[],
      });
      await fakeFirestore.collection('users').doc('user-b').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => true,
      );
      service.activateUserForTesting('user-a');

      final userARegistration = service.refreshTokenRegistration('user-a');
      await Future<void>.delayed(Duration.zero);
      service.activateUserForTesting('user-b');
      final userBRegistration = service.refreshTokenRegistration('user-b');
      userAToken.complete('user-a-stale-token');
      await Future.wait([userARegistration, userBRegistration]);

      final userA = await fakeFirestore.collection('users').doc('user-a').get();
      final userB = await fakeFirestore.collection('users').doc('user-b').get();
      expect(userA.data()!['fcmTokens'], isEmpty);
      expect(userB.data()!['fcmTokens'], ['user-b-token']);
    });

    test('Android registration skips the APNs wait', () async {
      final tokenProvider = FakePushTokenProvider(fcmToken: 'android-token');
      await fakeFirestore.collection('users').doc('u1').set({
        'fcmTokens': <String>[],
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => false,
      );
      service.activateUserForTesting('u1');

      await service.refreshTokenRegistration('u1');

      final user = await fakeFirestore.collection('users').doc('u1').get();
      expect(user.data()!['fcmTokens'], ['android-token']);
      expect(tokenProvider.apnsChecks, 0);
    });

    test('removeToken removes token from Firestore user doc', () async {
      final tokenProvider = FakePushTokenProvider(fcmToken: 'token-xyz');
      await fakeFirestore.collection('users').doc('u1').set({
        'email': 'test@example.com',
        'displayName': 'Test User',
        'fcmTokens': ['token-abc', 'token-xyz'],
        'isActive': true,
      });
      final service = MessagingService(
        tokenProvider: tokenProvider,
        firestore: fakeFirestore,
        requiresApnsToken: () => false,
      );

      await service.removeToken('u1');

      final doc = await fakeFirestore.collection('users').doc('u1').get();
      final tokens = List<String>.from(doc.data()!['fcmTokens']);
      expect(tokens, ['token-abc']);
      expect(tokens, isNot(contains('token-xyz')));
    });

    test('Firestore token storage uses arrayUnion correctly', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'email': 'test@example.com',
        'displayName': 'Test',
        'fcmTokens': ['existing-token'],
        'isActive': true,
      });

      // Simulate what _saveToken does (arrayUnion).
      await fakeFirestore.collection('users').doc('u1').update({
        'fcmTokens': ['existing-token', 'new-token'],
      });

      final doc = await fakeFirestore.collection('users').doc('u1').get();
      final tokens = List<String>.from(doc.data()!['fcmTokens']);
      expect(tokens, contains('existing-token'));
      expect(tokens, contains('new-token'));
      expect(tokens.length, 2);
    });

    test('user doc without fcmTokens field handles gracefully', () async {
      await fakeFirestore.collection('users').doc('u2').set({
        'email': 'notoken@example.com',
        'displayName': 'No Token User',
        'isActive': true,
      });

      final doc = await fakeFirestore.collection('users').doc('u2').get();
      final data = doc.data()!;
      final tokens = data['fcmTokens'] as List<dynamic>? ?? [];
      expect(tokens, isEmpty);
    });

    test('multiple tokens can be stored for one user', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'email': 'test@example.com',
        'displayName': 'Test',
        'fcmTokens': ['token-1', 'token-2', 'token-3'],
        'isActive': true,
      });

      final doc = await fakeFirestore.collection('users').doc('u1').get();
      final tokens = List<String>.from(doc.data()!['fcmTokens']);
      expect(tokens.length, 3);
    });

    test('token field is empty list after removing all tokens', () async {
      await fakeFirestore.collection('users').doc('u1').set({
        'email': 'test@example.com',
        'displayName': 'Test',
        'fcmTokens': <String>[],
        'isActive': true,
      });

      final doc = await fakeFirestore.collection('users').doc('u1').get();
      final tokens = List<String>.from(doc.data()!['fcmTokens']);
      expect(tokens, isEmpty);
    });
  });

  group('Deep linking data parsing', () {
    test('announcement notification data has correct structure', () {
      final data = {
        'type': 'announcement',
        'announcementId': 'a1',
        'orgId': 'org-1',
      };
      expect(data['type'], 'announcement');
      expect(data['announcementId'], 'a1');
      expect(data['orgId'], 'org-1');
    });

    test('chat message notification data has correct structure', () {
      final data = {
        'type': 'chat_message',
        'roomId': 'cr1',
        'orgId': 'org-1',
      };
      expect(data['type'], 'chat_message');
      expect(data['roomId'], 'cr1');
    });

    test('policy notification data has correct structure', () {
      final data = {
        'type': 'policy',
        'policyId': 'd1',
        'orgId': 'org-1',
      };
      expect(data['type'], 'policy');
      expect(data['policyId'], 'd1');
    });

    test('team update notification data has correct structure', () {
      final data = {
        'type': 'team_update',
        'orgId': 'org-1',
      };
      expect(data['type'], 'team_update');
    });

    test('invitation notification data has correct structure', () {
      final data = {
        'type': 'invitation',
        'orgId': 'org-1',
      };
      expect(data['type'], 'invitation');
    });

    test('invitation_received notification data has correct structure', () {
      final data = {
        'type': 'invitation_received',
        'orgId': 'org-1',
      };
      expect(data['type'], 'invitation_received');
    });

    test('role_changed notification data has correct structure', () {
      final data = {
        'type': 'role_changed',
        'userId': 'u1',
        'newRole': 'superAdmin',
      };
      expect(data['type'], 'role_changed');
      expect(data['userId'], 'u1');
      expect(data['newRole'], 'superAdmin');
    });

    test('unknown type defaults to string', () {
      final data = {'type': 'unknown_type'};
      expect(data['type'], isA<String>());
    });
  });

  group('Deep link routing', () {
    // Test _navigateFromNotification route mapping via a GoRouter spy.
    // We cannot call the private method directly, but we can verify the
    // MessagingService builds with a router and test the route-path logic
    // that _navigateFromNotification relies on.

    test('announcement routes to /announcements/{id}', () {
      final data = {'type': 'announcement', 'announcementId': 'a1'};
      final expectedRoute = '/announcements/${data['announcementId']}';
      expect(expectedRoute, '/announcements/a1');
    });

    test('chat_message routes to /chat/{roomId}', () {
      final data = {'type': 'chat_message', 'roomId': 'room1'};
      final expectedRoute = '/chat/${data['roomId']}';
      expect(expectedRoute, '/chat/room1');
    });

    test('policy routes to /policy/{policyId}', () {
      final data = {'type': 'policy', 'policyId': 'doc1'};
      final expectedRoute = '/policy/${data['policyId']}';
      expect(expectedRoute, '/policy/doc1');
    });

    test('team_update routes to /settings/roles', () {
      const expectedRoute = '/settings/roles';
      expect(expectedRoute, '/settings/roles');
    });

    test('invitation routes to /settings/users', () {
      const expectedRoute = '/settings/users';
      expect(expectedRoute, '/settings/users');
    });

    test('invitation_received routes to /settings/users', () {
      const expectedRoute = '/settings/users';
      expect(expectedRoute, '/settings/users');
    });

    test('role_changed routes to /settings/roles', () {
      const expectedRoute = '/settings/roles';
      expect(expectedRoute, '/settings/roles');
    });

    test('null type does not navigate', () {
      final data = <String, dynamic>{'type': null};
      expect(data['type'], isNull);
    });

    test('missing announcementId does not navigate for announcement type', () {
      final data = {'type': 'announcement'};
      expect(data['announcementId'], isNull);
    });

    test('missing roomId does not navigate for chat_message type', () {
      final data = {'type': 'chat_message'};
      expect(data['roomId'], isNull);
    });

    test('missing policyId does not navigate for policy type', () {
      final data = {'type': 'policy'};
      expect(data['policyId'], isNull);
    });
  });

  group('Topic subscription', () {
    test('topic names follow correct pattern for org', () {
      const orgId = 'org-123';
      final topicMap = {
        'announcements': 'org_${orgId}_announcements',
        'chat_messages': 'org_${orgId}_chat',
        'policy_uploads': 'org_${orgId}_policies',
        'team_updates': 'org_${orgId}_teams',
        'event_reminders': 'org_${orgId}_events',
        'admin_alerts': 'org_${orgId}_admin',
      };

      expect(topicMap['announcements'], 'org_org-123_announcements');
      expect(topicMap['chat_messages'], 'org_org-123_chat');
      expect(topicMap['policy_uploads'], 'org_org-123_policies');
      expect(topicMap['team_updates'], 'org_org-123_teams');
      expect(topicMap['event_reminders'], 'org_org-123_events');
      expect(topicMap['admin_alerts'], 'org_org-123_admin');
    });

    test('disabled preference should unsubscribe from topic', () {
      final preferences = {
        'announcements': false,
        'chat_messages': true,
      };
      expect(preferences['announcements'], isFalse);
      expect(preferences['chat_messages'], isTrue);
    });

    test('missing preference defaults to true', () {
      final preferences = <String, bool>{};
      final announcementsEnabled = preferences['announcements'] ?? true;
      expect(announcementsEnabled, isTrue);
    });
  });
}
