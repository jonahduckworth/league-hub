import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'data_providers.dart';

/// In-session notification preferences with FCM topic sync.
final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>(
  (ref) => NotificationPrefsNotifier(ref),
);

class NotificationPrefsNotifier extends StateNotifier<Map<String, bool>> {
  final Ref _ref;

  NotificationPrefsNotifier(this._ref)
      : super({
          'chat_messages': true,
          'policy_uploads': true,
          'team_updates': true,
          'event_reminders': true,
          'admin_alerts': true,
          'sound': true,
          'vibration': true,
        });

  void toggle(String key) {
    state = {...state, key: !(state[key] ?? true)};

    final orgId = _ref.read(organizationProvider).valueOrNull?.id;
    if (orgId != null) {
      _ref.read(messagingServiceProvider).syncPreferences(orgId, state);
    }
  }
}

/// Total unread chat messages maintained transactionally by Cloud Functions.
/// A single user-document listener keeps badge synchronization lightweight.
final totalUnreadMessageCountProvider = Provider<int>((ref) {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return 0;
  return ref.watch(unreadChatCountProvider(userId)).valueOrNull ?? 0;
});

final unreadChatCountProvider = StreamProvider.family<int, String>((ref, uid) {
  return ref.watch(firestoreServiceProvider).unreadChatCountStream(uid);
});

/// Badge value to publish to the operating system.
final appBadgeCountProvider = Provider<int>((ref) {
  final enabled =
      ref.watch(currentUserProvider).valueOrNull?.appBadgeEnabled ?? false;
  return enabled ? ref.watch(totalUnreadMessageCountProvider) : 0;
});
