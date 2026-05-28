import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/league_branding.dart';
import '../../models/app_user.dart';
import '../../providers/data_providers.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';

class RolesPermissionsScreen extends ConsumerWidget {
  const RolesPermissionsScreen({super.key});

  static const _roles = [
    _RoleDefinition(
      role: UserRole.superAdmin,
      title: 'Admin',
      description:
          'Manage leagues, hubs, teams, users, and content across the organization.',
      permissions: [
        'Manage leagues, hubs, and teams',
        'Manage users and invitations',
        'Create and manage announcements',
        'Manage policies and chat rooms',
        'All Manager permissions',
      ],
      icon: Icons.admin_panel_settings_outlined,
      accent: AppGlassColors.gold,
    ),
    _RoleDefinition(
      role: UserRole.managerAdmin,
      title: 'Manager',
      description:
          'Manage assigned hubs and teams with scoped access to league operations.',
      permissions: [
        'Manage assigned hubs and teams',
        'Create scoped announcements',
        'Upload and manage scoped policies',
        'Manage chat rooms in assigned hubs',
        'View members in assigned hubs',
      ],
      icon: Icons.manage_accounts_outlined,
      accent: AppGlassColors.aqua,
    ),
    _RoleDefinition(
      role: UserRole.staff,
      title: 'Staff',
      description:
          'View shared content, participate in chat rooms, and access assigned teams.',
      permissions: [
        'View announcements',
        'View and download policies',
        'Participate in chat rooms',
        'View team rosters',
        'Update own profile',
      ],
      icon: Icons.person_outline,
      accent: Color(0xFF3BE5A6),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(orgUsersProvider);
    final users = usersAsync.valueOrNull ?? [];
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Roles & Permissions',
        leadingIcon: Icons.admin_panel_settings_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
            ? headerLeague?.name
            : null,
        showBackButton: true,
        backFallbackLocation: '/settings',
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          appShellTopPadding(context),
          16,
          appShellBottomPadding(context, extra: 24),
        ),
        children: [
          AppGlassSurface(
            padding: const EdgeInsets.all(16),
            radius: 24,
            child: const Row(
              children: [
                _RoleIconBubble(
                  icon: Icons.lock_person_outlined,
                  accent: AppGlassColors.aqua,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ownership-level access stays reserved on the backend. Assign day-to-day access with the roles below.',
                    style: TextStyle(
                      color: AppGlassColors.inkSecondary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final role in _roles) ...[
            _RoleCard(
              definition: role,
              memberCount:
                  users.where((u) => u.role == role.role && u.isActive).length,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _RoleDefinition {
  final UserRole role;
  final String title;
  final String description;
  final List<String> permissions;
  final IconData icon;
  final Color accent;

  const _RoleDefinition({
    required this.role,
    required this.title,
    required this.description,
    required this.permissions,
    required this.icon,
    required this.accent,
  });
}

class _RoleCard extends StatelessWidget {
  final _RoleDefinition definition;
  final int memberCount;

  const _RoleCard({
    required this.definition,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 24,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppGlassColors.ink,
          collapsedIconColor: AppGlassColors.inkSecondary,
          leading: _RoleIconBubble(
            icon: definition.icon,
            accent: definition.accent,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  definition.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MemberCountPill(
                count: memberCount,
                accent: definition.accent,
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              definition.description,
              style: const TextStyle(
                color: AppGlassColors.inkSecondary,
                fontSize: 13,
                height: 1.34,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          children: [
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'PERMISSIONS',
                style: TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final permission in definition.permissions)
              _PermissionRow(
                label: permission,
                accent: definition.accent,
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleIconBubble extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _RoleIconBubble({
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.27)),
      ),
      child: Icon(icon, color: accent, size: 22),
    );
  }
}

class _MemberCountPill extends StatelessWidget {
  final int count;
  final Color accent;

  const _MemberCountPill({
    required this.count,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        '$count member${count == 1 ? '' : 's'}',
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final Color accent;

  const _PermissionRow({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check, size: 12, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppGlassColors.inkSecondary,
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
