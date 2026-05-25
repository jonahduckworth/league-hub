import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/confirmation_dialog.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  final String announcementId;
  final bool returnToDashboard;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
    this.returnToDashboard = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final userAsync = ref.watch(currentUserProvider);
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];

    final announcement = announcementsAsync.valueOrNull
        ?.where((a) => a.id == announcementId)
        .firstOrNull;

    final leagues = leaguesAsync.valueOrNull ?? [];
    final currentUser = userAsync.valueOrNull;
    final author = _userById(users, announcement?.authorId);
    final dashboardBack = returnToDashboard ? () => context.go('/') : null;

    if (announcementsAsync.isLoading) {
      return AppShellScaffold(
        header: AppShellHeader(
          title: 'Announcement',
          leadingIcon: Icons.campaign_outlined,
          leadingLabel: 'League Hub',
          showBackButton: true,
          onBack: dashboardBack,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (announcement == null) {
      return AppShellScaffold(
        header: AppShellHeader(
          title: 'Announcement',
          leadingIcon: Icons.campaign_outlined,
          leadingLabel: 'League Hub',
          showBackButton: true,
          onBack: dashboardBack,
        ),
        child: const Center(
          child: Text(
            'Announcement not found.',
            style: TextStyle(color: AppGlassColors.inkSecondary),
          ),
        ),
      );
    }

    final canEdit = currentUser != null &&
        (currentUser.id == announcement.authorId ||
            currentUser.role == UserRole.superAdmin ||
            currentUser.role == UserRole.platformOwner);

    final canDelete = currentUser != null &&
        (currentUser.role == UserRole.superAdmin ||
            currentUser.role == UserRole.platformOwner ||
            currentUser.id == announcement.authorId);

    final headerLeague = resolveHeaderLeague(leagues, announcement.leagueId);
    final topContentPadding = appShellTopPadding(context, extra: 12);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Announcement',
        leadingIcon: Icons.campaign_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        onBack: dashboardBack,
        actions: [
          if (canEdit)
            AppHeaderIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: () =>
                  context.push('/announcements/${announcement.id}/edit'),
            ),
          if (canDelete)
            AppHeaderIconButton(
              icon: Icons.delete_outline,
              color: AppGlassColors.rose,
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, ref, announcement),
            ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        children: [
          if (announcement.isPinned)
            AppGlassSurface(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              radius: 20,
              child: const Row(
                children: [
                  Icon(Icons.push_pin, size: 16, color: AppGlassColors.gold),
                  SizedBox(width: 10),
                  Text(
                    'Pinned Announcement',
                    style: TextStyle(
                      color: AppGlassColors.gold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          AppGlassSurface(
            padding: const EdgeInsets.all(18),
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ScopeTag(
                        scope: announcement.scope,
                        leagues: leagues,
                        leagueId: announcement.leagueId),
                    const Spacer(),
                    Text(
                      AppUtils.formatDateTime(announcement.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppGlassColors.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  announcement.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppGlassColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  announcement.body,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppGlassColors.inkSecondary,
                    height: 1.65,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppGlassSurface(
            padding: const EdgeInsets.all(16),
            radius: 24,
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: author?.avatarUrl,
                  name: announcement.authorName,
                  size: 44,
                  backgroundColor: AppGlassColors.aqua,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.authorName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppGlassColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        announcement.authorRole,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppGlassColors.inkSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Posted ${AppUtils.formatDateTime(announcement.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppGlassColors.inkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppUser? _userById(List<AppUser> users, String? id) {
    if (id == null) return null;
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Announcement a) async {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    final ok = await showConfirmationDialog(
      context,
      title: 'Delete Announcement',
      message: 'Are you sure you want to delete this announcement?',
      confirmLabel: 'Delete',
      confirmColor: AppGlassColors.rose,
    );
    if (ok == true && context.mounted) {
      _deleteAnnouncement(context, ref, orgId, a.id, currentUser);
    }
  }

  Future<void> _deleteAnnouncement(BuildContext context, WidgetRef ref,
      String orgId, String announcementId, AppUser currentUser) async {
    try {
      await ref.read(authorizedFirestoreServiceProvider).deleteAnnouncement(
            currentUser,
            orgId,
            announcementId,
          );
      if (context.mounted) {
        context.pop();
      }
    } on PermissionDeniedException {
      if (context.mounted) {
        AppUtils.showErrorSnackBar(
            context, 'Permission denied. You cannot delete announcements.');
      }
    } catch (e) {
      if (context.mounted) {
        AppUtils.showErrorSnackBar(context, 'Delete failed: $e');
      }
    }
  }
}

class _ScopeTag extends StatelessWidget {
  final AnnouncementScope scope;
  final List<League> leagues;
  final String? leagueId;

  const _ScopeTag({required this.scope, required this.leagues, this.leagueId});

  Color get _color {
    switch (scope) {
      case AnnouncementScope.orgWide:
        return AppGlassColors.aqua;
      case AnnouncementScope.league:
        return AppGlassColors.gold;
      case AnnouncementScope.hub:
        return AppGlassColors.aqua;
    }
  }

  String get _label {
    switch (scope) {
      case AnnouncementScope.orgWide:
        return 'Org-Wide';
      case AnnouncementScope.league:
        final league = leagues.where((l) => l.id == leagueId).firstOrNull;
        return league?.name ?? 'League';
      case AnnouncementScope.hub:
        return 'Hub';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _color.withValues(alpha: 0.3)),
        ),
        child: Text(_label,
            style: TextStyle(
                fontSize: 13, color: _color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
