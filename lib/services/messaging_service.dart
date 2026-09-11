import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

abstract interface class PushTokenProvider {
  Future<void> setAutoInitEnabled(bool enabled);

  Future<String?> getAPNSToken();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;
}

class FirebasePushTokenProvider implements PushTokenProvider {
  final FirebaseMessaging _messaging;

  FirebasePushTokenProvider(this._messaging);

  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      _messaging.setAutoInitEnabled(enabled);

  @override
  Future<String?> getAPNSToken() => _messaging.getAPNSToken();

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}

/// Handles FCM token management, notification display, and deep linking.
class MessagingService {
  final FirebaseMessaging _messaging;
  final PushTokenProvider _tokenProvider;
  final FirebaseFirestore _db;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Future<void> Function(Duration) _tokenRegistrationDelay;
  final bool Function() _requiresApnsToken;
  final bool enabled;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _activeUserId;
  int _sessionGeneration = 0;
  Future<void> _tokenWriteQueue = Future<void>.value();
  bool _autoInitEnabled = false;
  bool _messageListenersInitialized = false;

  /// Navigator key for deep linking from notification taps.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The router instance for deep linking via go_router.
  final GoRouter? router;

  MessagingService({
    FirebaseMessaging? messaging,
    PushTokenProvider? tokenProvider,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
    Future<void> Function(Duration)? tokenRegistrationDelay,
    bool Function()? requiresApnsToken,
    this.enabled = true,
    this.navigatorKey,
    this.router,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _tokenProvider = tokenProvider ??
            FirebasePushTokenProvider(messaging ?? FirebaseMessaging.instance),
        _db = firestore ?? FirebaseFirestore.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _tokenRegistrationDelay = tokenRegistrationDelay ??
            ((duration) => Future<void>.delayed(duration)),
        _requiresApnsToken = requiresApnsToken ??
            (() =>
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Full initialization: permissions → local notifications → listeners → token.
  Future<void> initialize(String userId) async {
    if (!enabled) return;
    final sessionGeneration = _activateUser(userId);
    _setupTokenRefreshListener();
    await _enableAutoInit();
    await _requestPermission();
    try {
      await _initLocalNotifications();
    } catch (e) {
      debugPrint('MessagingService: Failed to initialize local alerts: $e');
    }
    _setupListeners();
    await _registerToken(userId, sessionGeneration);
    await _checkInitialMessage();
  }

  Future<void> _requestPermission() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('MessagingService: Failed to request permission: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // Already requested above.
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel.
    const channel = AndroidNotificationChannel(
      'league_hub_default',
      'League Hub Notifications',
      description: 'Default notification channel for League Hub',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ---------------------------------------------------------------------------
  // Token Management
  // ---------------------------------------------------------------------------

  static const _apnsRetryDelays = <Duration>[
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  Future<void> _enableAutoInit() async {
    if (_autoInitEnabled) return;
    try {
      // Native auto-init stays disabled in the manifests so emulator mode can
      // be configured first. Enable it only after production mode is known.
      await _tokenProvider.setAutoInitEnabled(true);
      _autoInitEnabled = true;
    } catch (e) {
      debugPrint('MessagingService: Failed to enable FCM auto-init: $e');
    }
  }

  /// Rechecks and persists this device's token.
  ///
  /// This is safe to call when the app resumes. It repairs installs where the
  /// APNs token was not ready during the initial sign-in flow.
  Future<void> refreshTokenRegistration(String userId) async {
    if (!enabled) return;
    final sessionGeneration = _activateUser(userId);
    _setupTokenRefreshListener();
    await _registerToken(userId, sessionGeneration);
  }

  /// Stops token refreshes from being associated with a signed-out user.
  void clearActiveUser() {
    _sessionGeneration++;
    _activeUserId = null;
  }

  int _activateUser(String userId) {
    if (_activeUserId != userId) {
      _sessionGeneration++;
      _activeUserId = userId;
    }
    return _sessionGeneration;
  }

  bool _isActiveSession(String userId, int sessionGeneration) =>
      _activeUserId == userId && _sessionGeneration == sessionGeneration;

  /// Registers the current FCM token in the user's Firestore profile.
  Future<void> _registerToken(String userId, int sessionGeneration) async {
    try {
      await _enableAutoInit();

      // APNs registration completes asynchronously after permission is
      // requested. Wait briefly before asking Firebase for its mapped token.
      if (_requiresApnsToken()) {
        String? apnsToken = await _tokenProvider.getAPNSToken();
        for (final delay in _apnsRetryDelays) {
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          await _tokenRegistrationDelay(delay);
          apnsToken = await _tokenProvider.getAPNSToken();
        }
        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint(
            'MessagingService: APNs token is not available yet. '
            'Registration will retry when the app resumes or the token rotates.',
          );
          return;
        }
      }

      final token = await _tokenProvider.getToken();
      if (token != null) {
        await _saveToken(userId, sessionGeneration, token);
      }
    } catch (e) {
      // Don't crash the app if push registration fails (e.g. on simulators).
      debugPrint('MessagingService: Failed to register FCM token: $e');
    }
  }

  void _setupTokenRefreshListener() {
    if (_tokenRefreshSubscription != null) return;
    _tokenRefreshSubscription =
        _tokenProvider.onTokenRefresh.listen((newToken) {
      final userId = _activeUserId;
      if (userId == null) return;
      final sessionGeneration = _sessionGeneration;
      unawaited(
        _saveRefreshedToken(userId, sessionGeneration, newToken),
      );
    });
  }

  Future<void> _saveRefreshedToken(
    String userId,
    int sessionGeneration,
    String token,
  ) async {
    try {
      await _saveToken(userId, sessionGeneration, token);
    } catch (e) {
      debugPrint('MessagingService: Failed to save refreshed FCM token: $e');
    }
  }

  Future<void> _saveToken(
    String userId,
    int sessionGeneration,
    String token,
  ) {
    final operation = _runTokenWrite(() async {
      if (!_isActiveSession(userId, sessionGeneration)) return;
      final userRef = _db.collection(AppConstants.usersCollection).doc(userId);
      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

      // If sign-out occurred while the Firestore update was in flight, undo
      // the stale registration before allowing sign-out to complete.
      if (!_isActiveSession(userId, sessionGeneration)) {
        await userRef.update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    });
    _tokenWriteQueue = operation;
    return operation;
  }

  Future<void> _runTokenWrite(Future<void> Function() write) async {
    try {
      await _tokenWriteQueue;
    } catch (_) {
      // A previous write logs through its caller; keep later writes usable.
    }
    await write();
  }

  /// Removes the current token on sign-out so the user stops receiving pushes.
  Future<void> removeToken(String userId) async {
    if (!enabled) return;
    clearActiveUser();
    try {
      try {
        await _tokenWriteQueue;
      } catch (_) {
        // Continue with explicit removal after a failed registration write.
      }
      final token = await _tokenProvider.getToken();
      if (token != null) {
        await _db.collection(AppConstants.usersCollection).doc(userId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      }
    } catch (e) {
      // APNS token unavailable on simulators — safe to ignore.
      debugPrint('MessagingService: removeToken skipped ($e)');
    }
  }

  // ---------------------------------------------------------------------------
  // Topic Subscriptions (tied to notification preferences)
  // ---------------------------------------------------------------------------

  Future<void> subscribeToTopic(String topic) async {
    if (!enabled) return;
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!enabled) return;
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Subscribes/unsubscribes based on the user's notification preferences.
  Future<void> syncPreferences(
      String orgId, Map<String, bool> preferences) async {
    if (!enabled) return;
    final topicMap = {
      'announcements': 'org_${orgId}_announcements',
      'chat_messages': 'org_${orgId}_chat',
      'policy_uploads': 'org_${orgId}_policies',
      'team_updates': 'org_${orgId}_teams',
      'event_reminders': 'org_${orgId}_events',
      'admin_alerts': 'org_${orgId}_admin',
    };

    for (final entry in topicMap.entries) {
      final enabled = preferences[entry.key] ?? true;
      if (enabled) {
        await subscribeToTopic(entry.value);
      } else {
        await unsubscribeFromTopic(entry.value);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Message Listeners
  // ---------------------------------------------------------------------------

  void _setupListeners() {
    if (_messageListenersInitialized) return;
    _messageListenersInitialized = true;
    // Foreground messages — show a local notification.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // User tapped notification while app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Check if the app was opened from a terminated state via a notification.
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateFromNotification(initialMessage.data);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Show a local notification since FCM won't display one while foregrounded.
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'league_hub_default',
          'League Hub Notifications',
          channelDescription: 'Default notification channel for League Hub',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    _navigateFromNotification(message.data);
  }

  // ---------------------------------------------------------------------------
  // Deep Linking
  // ---------------------------------------------------------------------------

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromNotification(data);
    } catch (_) {
      // Invalid payload; ignore.
    }
  }

  /// Routes to the correct screen based on the notification data payload.
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == null || router == null) return;

    switch (type) {
      case 'announcement':
        final id = data['announcementId'] as String?;
        if (id != null) router!.push('/announcements/$id');
        break;

      case 'chat_message':
        final roomId = data['roomId'] as String?;
        if (roomId != null) router!.push('/chat/$roomId');
        break;

      case 'policy':
        final policyId = data['policyId'] as String?;
        if (policyId != null) router!.push('/policy/$policyId');
        break;

      case 'team_update':
        router!.push('/settings/roles');
        break;

      case 'role_changed':
        router!.push('/settings/roles');
        break;

      case 'invitation':
      case 'invitation_received':
        router!.push('/settings/users');
        break;

      default:
        // Unknown type — go to dashboard.
        router!.go('/');
    }
  }
}

/// Top-level background handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the system tray automatically.
  // This handler is required but can be empty for basic use cases.
  debugPrint('Background message received: ${message.messageId}');
}
