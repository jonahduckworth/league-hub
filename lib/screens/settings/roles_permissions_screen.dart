import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/data_providers.dart';

class RolesPermissionsScreen extends ConsumerWidget {
  const RolesPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(orgUsersProvider);
    final users = usersAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Roles & Permissions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRoleCard(
            role: UserRole.platformOwner,
            title: 'Platform Owner',
            description:
                'Full access to all organization settings, user management, billing, and data. Can transfer ownership.',
            permissions: [
              'Manage organization settings',
              'Manage all users and roles',
              'Manage billing & subscriptions',
              'Delete organization',
              'All Super Admin permissions',
            ],
            users: users,
          ),
          const SizedBox(height: 12),
          _buildRoleCard(
            role: UserRole.superAdmin,
            title: 'Super Admin',
            description:
                'Manage leagues, hubs, teams, users, and all content across the organization.',
            permissions: [
              'Manage leagues, hubs & teams',
              'Manage users & invitations',
              'Create & manage announcements',
              'Manage documents & chat rooms',
              'All Manager Admin permissions',
            ],
            users: users,
          ),
          const SizedBox(height: 12),
          _buildRoleCard(
            role: UserRole.managerAdmin,
            title: 'Manager Admin',
            description:
                'Manage assigned hubs and teams. Can create announcements and manage documents within their scope.',
            permissions: [
              'Manage assigned hubs & teams',
              'Create scoped announcements',
              'Upload & manage documents',
              'Manage chat rooms in assigned hubs',
              'View all members in assigned hubs',
            ],
            users: users,
          ),
          const SizedBox(height: 12),
          _buildRoleCard(
            role: UserRole.staff,
            title: 'Staff',
            description:
                'View content, participate in chat rooms, and access shared documents.',
            permissions: [
              'View announcements',
              'View & download documents',
              'Participate in chat rooms',
              'View team rosters',
              'Update own profile',
            ],
            users: users,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required UserRole role,
    required String title,
    required String description,
    required List<String> permissions,
    required List<AppUser> users,
  }) {
    final count = users.where((u) => u.role == role && u.isActive).length;
    final color = _roleColor(role);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_roleIcon(role), color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count member${count == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Text(description,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Permissions',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
          ),
          const SizedBox(height: 8),
          ...permissions.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.platformOwner:
        return AppColors.warning;
      case UserRole.superAdmin:
        return AppColors.primary;
      case UserRole.managerAdmin:
        return AppColors.accent;
      case UserRole.staff:
        return AppColors.success;
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.platformOwner:
        return Icons.shield;
      case UserRole.superAdmin:
        return Icons.admin_panel_settings;
      case UserRole.managerAdmin:
        return Icons.manage_accounts;
      case UserRole.staff:
        return Icons.person;
    }
  }
}
