import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';

/// Notification preferences with FCM topic sync.
final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsNotifier, Map<String, bool>>(
  (ref) => NotificationPrefsNotifier(ref),
);

class NotificationPrefsNotifier extends StateNotifier<Map<String, bool>> {
  final Ref _ref;

  NotificationPrefsNotifier(this._ref)
      : super({
          'announcements': true,
          'chat_messages': true,
          'document_uploads': true,
          'team_updates': true,
          'event_reminders': true,
          'admin_alerts': true,
          'sound': true,
          'vibration': true,
          'badge_count': true,
        });

  void toggle(String key) {
    state = {...state, key: !(state[key] ?? true)};

    // Sync push notification topic subscriptions.
    final orgId = _ref.read(organizationProvider).valueOrNull?.id;
    if (orgId != null) {
      _ref.read(messagingServiceProvider).syncPreferences(orgId, state);
    }
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            title: 'PUSH NOTIFICATIONS',
            children: [
              _ToggleTile(
                icon: Icons.campaign,
                title: 'Announcements',
                subtitle: 'New and pinned announcements',
                value: prefs['announcements'] ?? true,
                onChanged: () => notifier.toggle('announcements'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.chat_bubble_outline,
                title: 'Chat Messages',
                subtitle: 'New messages in your chat rooms',
                value: prefs['chat_messages'] ?? true,
                onChanged: () => notifier.toggle('chat_messages'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.description_outlined,
                title: 'Document Uploads',
                subtitle: 'New documents shared with you',
                value: prefs['document_uploads'] ?? true,
                onChanged: () => notifier.toggle('document_uploads'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.groups_outlined,
                title: 'Team Updates',
                subtitle: 'Roster changes and team news',
                value: prefs['team_updates'] ?? true,
                onChanged: () => notifier.toggle('team_updates'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.event_outlined,
                title: 'Event Reminders',
                subtitle: 'Upcoming games and practices',
                value: prefs['event_reminders'] ?? true,
                onChanged: () => notifier.toggle('event_reminders'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin Alerts',
                subtitle: 'User management and system alerts',
                value: prefs['admin_alerts'] ?? true,
                onChanged: () => notifier.toggle('admin_alerts'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'DELIVERY',
            children: [
              _ToggleTile(
                icon: Icons.volume_up_outlined,
                title: 'Sound',
                subtitle: 'Play sound for notifications',
                value: prefs['sound'] ?? true,
                onChanged: () => notifier.toggle('sound'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.vibration,
                title: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: prefs['vibration'] ?? true,
                onChanged: () => notifier.toggle('vibration'),
              ),
              const Divider(height: 1, indent: 54),
              _ToggleTile(
                icon: Icons.looks_one_outlined,
                title: 'Badge Count',
                subtitle: 'Show unread count on app icon',
                value: prefs['badge_count'] ?? true,
                onChanged: () => notifier.toggle('badge_count'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    color: AppColors.primary.withValues(alpha: 0.6), size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Notification preferences sync with FCM topics. Changes take effect immediately for new notifications.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onChanged;

  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title:
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.text)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Switch.adaptive(
        value: value,
        onChanged: (_) => onChanged(),
        activeTrackColor: AppColors.primary,
      ),
    );
  }
}
