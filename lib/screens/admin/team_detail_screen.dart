import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/bottom_sheet_handle.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/entity_avatar.dart';

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

    return teamsAsync.when(
      loading: () => const AppShellScaffold(
        header: AppShellHeader(
          title: 'Team Details',
          leadingIcon: Icons.groups_2_outlined,
          showBackButton: true,
          backFallbackLocation: '/settings/leagues',
        ),
        child: Center(
          child: CircularProgressIndicator(color: AppGlassColors.aqua),
        ),
      ),
      error: (e, _) => AppShellScaffold(
        header: const AppShellHeader(
          title: 'Team Details',
          leadingIcon: Icons.groups_2_outlined,
          showBackButton: true,
          backFallbackLocation: '/settings/leagues',
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            appShellTopPadding(context, extra: 12),
            16,
            appShellBottomPadding(context, extra: 24),
          ),
          children: [
            _TeamGlassMessage(
              icon: Icons.error_outline,
              title: 'Could not load team',
              message: '$e',
              color: AppGlassColors.rose,
            ),
          ],
        ),
      ),
      data: (teams) {
        final team = teams.where((t) => t.id == widget.teamId).firstOrNull;
        if (team == null) {
          return AppShellScaffold(
            header: const AppShellHeader(
              title: 'Team Details',
              leadingIcon: Icons.groups_2_outlined,
              showBackButton: true,
              backFallbackLocation: '/settings/leagues',
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                appShellTopPadding(context, extra: 12),
                16,
                appShellBottomPadding(context, extra: 24),
              ),
              children: const [
                SizedBox(height: 140),
                EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'Team not found',
                ),
              ],
            ),
          );
        }
        return AppShellScaffold(
          header: AppShellHeader(
            title: 'Team Details',
            leadingIcon: Icons.groups_2_outlined,
            leadingImageUrl: team.logoUrl,
            leadingLabel: team.logoUrl?.isNotEmpty == true ? team.name : null,
            showBackButton: true,
            backFallbackLocation: '/settings/leagues',
          ),
          child: _buildContent(context, team, orgId, currentUser),
        );
      },
    );
  }

  Widget _buildContent(
      BuildContext context, Team team, String? orgId, AppUser? currentUser) {
    final canManage = currentUser != null &&
        _ps.canCreateTeam(currentUser, hubId: widget.hubId);
    final orgUsersAsync = ref.watch(orgUsersProvider);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        appShellTopPadding(context, extra: 12),
        16,
        appShellBottomPadding(context, extra: 24),
      ),
      children: [
        // Team info card
        AppGlassSurface(
          padding: const EdgeInsets.all(16),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EntityAvatar(
                    name: team.name,
                    imageUrl: team.logoUrl,
                    iconName: team.iconName,
                    fallbackIcon: Icons.groups_2_outlined,
                    size: 54,
                    color: AppGlassColors.aqua,
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
                                color: AppGlassColors.ink)),
                        if (team.ageGroup != null || team.division != null)
                          Text(
                            [team.ageGroup, team.division]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(
                                fontSize: 13, color: AppGlassColors.inkMuted),
                          ),
                      ],
                    ),
                  ),
                  if (canManage)
                    IconButton(
                      tooltip: 'Edit Team',
                      icon: const Icon(Icons.edit_outlined,
                          color: AppGlassColors.inkMuted),
                      onPressed: () => context.push(
                        '/teams/${team.id}/edit?leagueId=${team.leagueId}&hubId=${team.hubId}',
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
            trailing: const Icon(
              Icons.chevron_right,
              color: AppGlassColors.inkMuted,
            ),
            onTap: () => context.push('/chat/${team.chatRoomId}'),
          ),
          const SizedBox(height: 16),
        ],

        // Roster section
        AppGlassSurface(
          padding: EdgeInsets.zero,
          radius: 24,
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
                            color: AppGlassColors.inkMuted,
                            letterSpacing: 0.8)),
                    const Spacer(),
                    Text('${team.memberIds.length} members',
                        style: const TextStyle(
                            fontSize: 12, color: AppGlassColors.inkMuted)),
                    if (canManage) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            _showAddMemberSheet(context, team, orgId ?? ''),
                        child: const Icon(Icons.person_add_outlined,
                            size: 20, color: AppGlassColors.aqua),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              if (team.memberIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No members yet',
                        style: TextStyle(
                            color: AppGlassColors.inkMuted,
                            fontStyle: FontStyle.italic,
                            fontSize: 13)),
                  ),
                )
              else
                orgUsersAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: CircularProgressIndicator(
                        color: AppGlassColors.aqua,
                      ))),
                  error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: AppGlassColors.rose),
                      )),
                  data: (allUsers) {
                    final members = allUsers
                        .where((u) => team.memberIds.contains(u.id))
                        .toList();
                    return Column(
                      children: members
                          .map((m) => _MemberTile(
                                user: m,
                                canRemove: canManage,
                                onRemove: () =>
                                    _removeMember(team, m.id, orgId ?? ''),
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        builder: (_, scrollCtrl) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
          child: AppGlassSurface(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: EdgeInsets.zero,
            radius: 30,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const BottomSheetHandle(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Add Member',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppGlassColors.ink,
                    ),
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
                if (available.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No available users',
                        style: TextStyle(color: AppGlassColors.inkMuted),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: available.length,
                      itemBuilder: (_, i) {
                        final user = available[i];
                        return ListTile(
                          leading: AvatarWidget(
                            imageUrl: user.avatarUrl,
                            name: user.displayName,
                            size: 40,
                            backgroundColor:
                                AppGlassColors.aqua.withValues(alpha: 0.22),
                          ),
                          title: Text(
                            user.displayName,
                            style: const TextStyle(
                              color: AppGlassColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            user.roleLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppGlassColors.inkMuted,
                            ),
                          ),
                          onTap: () => Navigator.pop(ctx, user),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
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
      await authFs.updateTeamFields(currentUser, orgId, team.leagueId,
          team.hubId, team.id, {'memberIds': newMembers});
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
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to manage this team');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to add member: $e');
      }
    }
  }

  Future<void> _removeMember(Team team, String userId, String orgId) async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    try {
      final authFs = ref.read(authorizedFirestoreServiceProvider);
      final newMembers = team.memberIds.where((id) => id != userId).toList();
      await authFs.updateTeamFields(currentUser, orgId, team.leagueId,
          team.hubId, team.id, {'memberIds': newMembers});
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
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to manage this team');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to remove member: $e');
      }
    }
  }
}

class _TeamGlassMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _TeamGlassMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppGlassColors.inkSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
    return AppGlassSurface(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Row(
        children: [
          Icon(icon, color: AppGlassColors.aqua, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppGlassColors.ink)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppGlassColors.inkMuted)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
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
      leading: AvatarWidget(
        imageUrl: user.avatarUrl,
        name: user.displayName,
        size: 36,
        backgroundColor: AppGlassColors.aqua.withValues(alpha: 0.22),
      ),
      title: Text(user.displayName,
          style: const TextStyle(fontSize: 14, color: AppGlassColors.ink)),
      subtitle: Text(user.roleLabel,
          style: const TextStyle(fontSize: 12, color: AppGlassColors.inkMuted)),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppGlassColors.rose, size: 20),
              onPressed: onRemove,
            )
          : null,
    );
  }
}
