import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/league_branding.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';

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
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Notifications',
        leadingIcon: Icons.notifications_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const _GlassDivider(),
                  _ToggleTile(
                    icon: Icons.chat_bubble_outline,
                    title: 'Chat Messages',
                    subtitle: 'New messages in your chat rooms',
                    value: prefs['chat_messages'] ?? true,
                    onChanged: () => notifier.toggle('chat_messages'),
                  ),
                  const _GlassDivider(),
                  _ToggleTile(
                    icon: Icons.description_outlined,
                    title: 'Policy Uploads',
                    subtitle: 'New policies shared with you',
                    value: prefs['policy_uploads'] ?? true,
                    onChanged: () => notifier.toggle('policy_uploads'),
                  ),
                  const _GlassDivider(),
                  _ToggleTile(
                    icon: Icons.groups_outlined,
                    title: 'Team Updates',
                    subtitle: 'Roster changes and team news',
                    value: prefs['team_updates'] ?? true,
                    onChanged: () => notifier.toggle('team_updates'),
                  ),
                  const _GlassDivider(),
                  _ToggleTile(
                    icon: Icons.event_outlined,
                    title: 'Event Reminders',
                    subtitle: 'Upcoming games and practices',
                    value: prefs['event_reminders'] ?? true,
                    onChanged: () => notifier.toggle('event_reminders'),
                  ),
                  const _GlassDivider(),
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
                  const _GlassDivider(),
                  _ToggleTile(
                    icon: Icons.vibration,
                    title: 'Vibration',
                    subtitle: 'Vibrate for notifications',
                    value: prefs['vibration'] ?? true,
                    onChanged: () => notifier.toggle('vibration'),
                  ),
                  const _GlassDivider(),
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
              AppGlassSurface(
                padding: const EdgeInsets.all(16),
                radius: 20,
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppGlassColors.aqua,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notification preferences sync with FCM topics. Changes take effect immediately for new notifications.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppGlassColors.inkSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppGlassColors.inkMuted,
                  letterSpacing: 0.8)),
        ),
        AppGlassSurface(
          padding: EdgeInsets.zero,
          radius: 22,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 68,
      color: Colors.white.withValues(alpha: 0.12),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppGlassColors.aqua.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppGlassColors.aqua.withValues(alpha: 0.24),
          ),
        ),
        child: Icon(icon, color: AppGlassColors.aqua, size: 21),
      ),
      title: Text(title,
          style: const TextStyle(
            fontSize: 14,
            color: AppGlassColors.ink,
            fontWeight: FontWeight.w800,
          )),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppGlassColors.inkMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: (_) => onChanged(),
        activeTrackColor: AppGlassColors.aqua.withValues(alpha: 0.48),
        activeThumbColor: AppGlassColors.aqua,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
        inactiveThumbColor: AppGlassColors.inkMuted,
      ),
    );
  }
}
