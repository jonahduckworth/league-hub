import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../services/permission_service.dart';

/// Displays team details, roster management, and a link to the team chat room.
class TeamDetailScreen extends ConsumerStatefulWidget {
  final String teamId;
  final String leagueId;
  final String hubId;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
    required this.leagueId,
    required this.hubId,
  });

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen> {
  static const _ps = PermissionService();

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(organizationProvider).valueOrNull?.id;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final teamsAsync = ref.watch(
      teamsProvider((leagueId: widget.leagueId, hubId: widget.hubId)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Team Details')),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (teams) {
          final team = teams.where((t) => t.id == widget.teamId).firstOrNull;
          if (team == null) {
            return const Center(
                child: Text('Team not found',
                    style: TextStyle(color: AppColors.textSecondary)));
          }
          return _buildContent(context, team, orgId, currentUser);
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Team team, String? orgId, AppUser? currentUser) {
    final canManage = currentUser != null &&
        _ps.canCreateTeam(currentUser, hubId: widget.hubId);
    final orgUsersAsync = ref.watch(orgUsersProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Team info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups,
                        color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        if (team.ageGroup != null || team.division != null)
                          Text(
                            [team.ageGroup, team.division]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Team chat room link
        if (team.chatRoomId != null) ...[
          _SectionCard(
            icon: Icons.chat_bubble_outline,
            title: 'Team Chat',
            subtitle: 'Open the team chat room',
            trailing: const Icon(Icons.chevron_right,
                color: AppColors.textSecondary),
            onTap: () => context.push('/chat/${team.chatRoomId}'),
          ),
          const SizedBox(height: 16),
        ],

        // Roster section
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Text('ROSTER',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    Text('${team.memberIds.length} members',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showAddMemberSheet(
                            context, team, orgId ?? ''),
                        child: const Icon(Icons.person_add_outlined,
                            size: 20, color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              if (team.memberIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No members yet',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                            fontSize: 13)),
                  ),
                )
              else
                orgUsersAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: $e')),
                  data: (allUsers) {
                    final members = allUsers
                        .where((u) => team.memberIds.contains(u.id))
                        .toList();
                    return Column(
                      children: members
                          .map((m) => _MemberTile(
                                user: m,
                                canRemove: canManage,
                                onRemove: () => _removeMember(
                                    team, m.id, orgId ?? ''),
                              ))
                          .toList(),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAddMemberSheet(
      BuildContext context, Team team, String orgId) async {
    final orgUsersAsync = ref.read(orgUsersProvider);
    final allUsers = orgUsersAsync.valueOrNull ?? [];
    // Exclude users already in the team.
    final available =
        allUsers.where((u) => !team.memberIds.contains(u.id)).toList();

    if (!mounted) return;

    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        builder: (_, scrollCtrl) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add Member',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
            ),
            const Divider(height: 1),
            if (available.isEmpty)
              const Expanded(
                child: Center(
                    child: Text('No available users',
                        style: TextStyle(color: AppColors.textMuted))),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: available.length,
                  itemBuilder: (_, i) {
                    final user = available[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.roleLabel,
                          style: const TextStyle(fontSize: 12)),
                      onTap: () => Navigator.pop(ctx, user),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    if (selected != null && orgId.isNotEmpty) {
      await _addMember(team, selected.id, orgId);
    }
  }

  Future<void> _addMember(Team team, String userId, String orgId) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    try {
      final authFs = ref.read(authorizedFirestoreServiceProvider);
      final newMembers = [...team.memberIds, userId];
      await authFs.updateTeamFields(
          currentUser, orgId, team.leagueId, team.hubId, team.id,
          {'memberIds': newMembers});
      // Also update the user's teamIds.
      final allUsers = ref.read(orgUsersProvider).valueOrNull ?? [];
      final targetUser = allUsers.where((u) => u.id == userId).firstOrNull;
      if (targetUser != null) {
        await authFs.updateUserFields(currentUser, targetUser, {
          'teamIds': [...targetUser.teamIds, team.id],
        });
      }
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You do not have permission to manage this team'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to add member: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _removeMember(Team team, String userId, String orgId) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    try {
      final authFs = ref.read(authorizedFirestoreServiceProvider);
      final newMembers = team.memberIds.where((id) => id != userId).toList();
      await authFs.updateTeamFields(
          currentUser, orgId, team.leagueId, team.hubId, team.id,
          {'memberIds': newMembers});
      // Also update the user's teamIds.
      final allUsers = ref.read(orgUsersProvider).valueOrNull ?? [];
      final targetUser = allUsers.where((u) => u.id == userId).firstOrNull;
      if (targetUser != null) {
        await authFs.updateUserFields(currentUser, targetUser, {
          'teamIds': targetUser.teamIds.where((id) => id != team.id).toList(),
        });
      }
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You do not have permission to manage this team'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to remove member: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final AppUser user;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.user,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        radius: 18,
        child: Text(
          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
          style: const TextStyle(color: AppColors.primary, fontSize: 14),
        ),
      ),
      title: Text(user.displayName,
          style: const TextStyle(fontSize: 14, color: AppColors.text)),
      subtitle: Text(user.roleLabel,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: canRemove
          ? IconButton(
              icon:
                  const Icon(Icons.remove_circle_outline, color: AppColors.danger, size: 20),
              onPressed: onRemove,
            )
          : null,
    );
  }
}
