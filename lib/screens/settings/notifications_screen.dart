import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/league_branding.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
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

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  AnnouncementDelivery? _savedDelivery;
  AnnouncementDelivery? _savingDelivery;
  String? _deliveryError;

  Future<void> _saveDelivery(
    AppUser user,
    AnnouncementDelivery delivery,
  ) async {
    if (_savingDelivery != null || delivery == _savedDelivery) return;
    setState(() {
      _savingDelivery = delivery;
      _deliveryError = null;
    });

    try {
      await ref
          .read(authorizedFirestoreServiceProvider)
          .updateOwnNotificationPreferences(user, delivery);
      if (!mounted) return;
      setState(() {
        _savedDelivery = delivery;
        _savingDelivery = null;
      });
      ref.invalidate(currentUserProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement delivery updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingDelivery = null;
        _deliveryError =
            'We could not save that choice. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPrefsProvider);
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final currentUser = ref.watch(currentUserProvider);
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
                title: 'ANNOUNCEMENT DELIVERY',
                children: [
                  currentUser.when(
                    data: (user) {
                      if (user == null) {
                        return const _DeliveryStatus(
                          message: 'Sign in to manage announcement delivery.',
                        );
                      }
                      final selected =
                          _savedDelivery ?? user.announcementDelivery;
                      return _AnnouncementDeliveryPicker(
                        selected: selected,
                        saving: _savingDelivery,
                        error: _deliveryError,
                        onChanged: (delivery) => _saveDelivery(user, delivery),
                      );
                    },
                    loading: () => const _DeliveryStatus(
                      message: 'Loading your announcement preference…',
                      showProgress: true,
                    ),
                    error: (_, __) => _DeliveryStatus(
                      message:
                          'We could not load your announcement preference.',
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(currentUserProvider),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'OTHER PUSH NOTIFICATIONS',
                children: [
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
              const SizedBox(height: 16),
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
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppGlassColors.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AppGlassSurface(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _AnnouncementDeliveryPicker extends StatelessWidget {
  final AnnouncementDelivery selected;
  final AnnouncementDelivery? saving;
  final String? error;
  final ValueChanged<AnnouncementDelivery> onChanged;

  const _AnnouncementDeliveryPicker({
    required this.selected,
    required this.saving,
    required this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const descriptions = {
      AnnouncementDelivery.both: 'Get a push alert and a copy in your inbox.',
      AnnouncementDelivery.push:
          'Get an alert on devices where League Hub is installed.',
      AnnouncementDelivery.email:
          'Get announcements at the email on your League Hub account.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Choose how new announcements reach you. This does not change chat or other push alerts.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        RadioGroup<AnnouncementDelivery>(
          groupValue: selected,
          onChanged: (value) {
            if (saving == null && value != null) onChanged(value);
          },
          child: Column(
            children: [
              for (final delivery in AnnouncementDelivery.values) ...[
                RadioListTile<AnnouncementDelivery>(
                  key: ValueKey(
                    'announcement-delivery-${delivery.name}',
                  ),
                  value: delivery,
                  enabled: saving == null,
                  activeColor: AppGlassColors.aqua,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  title: Text(
                    delivery.label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppGlassColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    descriptions[delivery]!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppGlassColors.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  secondary: saving == delivery
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          switch (delivery) {
                            AnnouncementDelivery.both =>
                              Icons.mark_email_unread_outlined,
                            AnnouncementDelivery.push =>
                              Icons.notifications_active_outlined,
                            AnnouncementDelivery.email => Icons.email_outlined,
                          },
                          color: AppGlassColors.aqua,
                          size: 22,
                        ),
                ),
                if (delivery != AnnouncementDelivery.email)
                  const _GlassDivider(),
              ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              error!,
              key: const ValueKey('announcement-delivery-error'),
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _DeliveryStatus extends StatelessWidget {
  final String message;
  final bool showProgress;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _DeliveryStatus({
    required this.message,
    this.showProgress = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (showProgress) ...[
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppGlassColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 54,
      color: Colors.white.withValues(alpha: 0.1),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppGlassColors.aqua, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: AppGlassColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
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
