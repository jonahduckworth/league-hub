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
          'badge_count': true,
        });

  void toggle(String key) {
    state = {...state, key: !(state[key] ?? true)};

    final orgId = _ref.read(organizationProvider).valueOrNull?.id;
    if (orgId != null) {
      _ref.read(messagingServiceProvider).syncPreferences(orgId, state);
    }
  }
}

/// Total unread chat messages across every room visible to the signed-in user.
///
/// The provider reuses the same bounded, per-room unread streams shown in the
/// chat UI, so opening or reading a conversation immediately updates the icon.
final totalUnreadMessageCountProvider = Provider<int>((ref) {
  final rooms = ref.watch(chatRoomsProvider).valueOrNull ?? const [];
  return rooms.fold<int>(
    0,
    (total, room) =>
        total + (ref.watch(unreadCountProvider(room.id)).valueOrNull ?? 0),
  );
});

/// Badge value to publish to the operating system.
final appBadgeCountProvider = Provider<int>((ref) {
  final enabled = ref.watch(
    notificationPrefsProvider.select(
      (preferences) => preferences['badge_count'] ?? true,
    ),
  );
  return enabled ? ref.watch(totalUnreadMessageCountProvider) : 0;
});
