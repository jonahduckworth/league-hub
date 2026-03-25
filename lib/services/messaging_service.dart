import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Handles FCM token management, notification display, and deep linking.
class MessagingService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// Navigator key for deep linking from notification taps.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// The router instance for deep linking via go_router.
  final GoRouter? router;

  MessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
    this.navigatorKey,
    this.router,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Full initialization: permissions → local notifications → listeners → token.
  Future<void> initialize(String userId) async {
    await _requestPermission();
    await _initLocalNotifications();
    _setupListeners();
    await _registerToken(userId);
    await _checkInitialMessage();
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
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

  /// Registers the current FCM token in the user's Firestore document.
  Future<void> _registerToken(String userId) async {
    try {
      // On iOS, we need to wait for the APNS token before requesting the FCM
      // token. Simulators don't support APNS, so this may return null.
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          debugPrint(
            'MessagingService: APNS token not available '
            '(expected on simulators). Skipping FCM registration.',
          );
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(userId, token);
      }
    } catch (e) {
      // Don't crash the app if push registration fails (e.g. on simulators).
      debugPrint('MessagingService: Failed to register FCM token: $e');
    }

    // Listen for token refreshes.
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(userId, newToken);
    });
  }

  Future<void> _saveToken(String userId, String token) async {
    await _db.collection(AppConstants.usersCollection).doc(userId).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Removes the current token on sign-out so the user stops receiving pushes.
  Future<void> removeToken(String userId) async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _db.collection(AppConstants.usersCollection).doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Topic Subscriptions (tied to notification preferences)
  // ---------------------------------------------------------------------------

  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }

  /// Subscribes/unsubscribes based on the user's notification preferences.
  Future<void> syncPreferences(
      String orgId, Map<String, bool> preferences) async {
    final topicMap = {
      'announcements': 'org_${orgId}_announcements',
      'chat_messages': 'org_${orgId}_chat',
      'document_uploads': 'org_${orgId}_documents',
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

      case 'document':
        final docId = data['documentId'] as String?;
        if (docId != null) router!.push('/documents/$docId');
        break;

      case 'team_update':
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
