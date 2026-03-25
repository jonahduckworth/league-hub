import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/mock_data.dart';
import '../widgets/avatar_widget.dart';
import 'admin/manage_leagues_screen.dart';
import 'settings/edit_profile_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull ?? mockCurrentUser;
    final pendingInviteCount = ref.watch(pendingInviteCountProvider);
    final ps = ref.read(permissionServiceProvider);
    final visibleTiles = ps.visibleSettingsTiles(user);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(user: user),
          const SizedBox(height: 24),
          if (visibleTiles.any((t) => ['leagues', 'users', 'roles', 'branding', 'app-icon'].contains(t)))
            _SettingsSection(
              title: 'Organization',
              items: [
                if (visibleTiles.contains('leagues'))
                  _SettingsItem(
                    icon: Icons.location_city,
                    title: 'Manage Leagues & Hubs',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ManageLeaguesScreen(),
                      ),
                    ),
                  ),
                if (visibleTiles.contains('users'))
                  _SettingsItem(
                    icon: Icons.people,
                    title: 'User Management',
                    badge: pendingInviteCount > 0 ? pendingInviteCount : null,
                    onTap: () => context.push('/settings/users'),
                  ),
                if (visibleTiles.contains('roles'))
                  _SettingsItem(icon: Icons.admin_panel_settings, title: 'Roles & Permissions', onTap: () => context.push('/settings/roles')),
                if (visibleTiles.contains('branding'))
                  _SettingsItem(icon: Icons.palette, title: 'Branding & Appearance', onTap: () => context.push('/settings/branding')),
                if (visibleTiles.contains('app-icon'))
                  _SettingsItem(icon: Icons.apps, title: 'App Icon', onTap: () => context.push('/settings/app-icon')),
              ],
            ),
          if (visibleTiles.any((t) => ['leagues', 'users', 'roles', 'branding', 'app-icon'].contains(t)))
            const SizedBox(height: 16),
          _SettingsSection(
            title: 'Preferences',
            items: [
              _SettingsItem(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () => context.push('/settings/notifications')),
              _SettingsItem(icon: Icons.lock_outlined, title: 'Privacy & Security', onTap: () => context.push('/settings/privacy')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: const Text('Sign Out',
                  style: TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: () async {
                final user = ref.read(currentUserProvider).valueOrNull;
                if (user != null) {
                  await ref.read(messagingServiceProvider).removeToken(user.id);
                }
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
          const SizedBox(height: 24),
          const Center(
              child: Text('League Hub v1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppUser user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AvatarWidget(
              name: user.displayName,
              size: 60,
              backgroundColor: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(user.email,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _RoleBadge(label: user.roleLabel),
                    const SizedBox(width: 8),
                    if (user.role == UserRole.platformOwner ||
                        user.role == UserRole.superAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Owner',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              )),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
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
          child: Column(
            children: items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  entry.value,
                  if (!isLast) const Divider(height: 1, indent: 54),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? badge;

  const _SettingsItem(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.badge});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title,
          style: const TextStyle(fontSize: 15, color: AppColors.text)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
