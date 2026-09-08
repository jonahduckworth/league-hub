import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/announcement_read_receipt.dart';
import '../models/app_user.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/confirmation_dialog.dart';

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  final String announcementId;
  final bool returnToDashboard;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
    this.returnToDashboard = false,
  });

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  String? _scheduledReadKey;

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final userAsync = ref.watch(currentUserProvider);
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];

    final announcement = announcementsAsync.valueOrNull
        ?.where((a) => a.id == widget.announcementId)
        .firstOrNull;

    final leagues = leaguesAsync.valueOrNull ?? [];
    final currentUser = userAsync.valueOrNull;
    final author = _userById(users, announcement?.authorId);
    final dashboardBack =
        widget.returnToDashboard ? () => context.go('/') : null;

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

    final permissions = const PermissionService();
    final canEdit = currentUser != null &&
        permissions.canEditAnnouncement(
          currentUser,
          authorId: announcement.authorId,
        );
    final canDelete =
        currentUser != null && permissions.canDeleteAnnouncement(currentUser);
    final canViewReaders = currentUser != null &&
        permissions.canViewAnnouncementReaders(currentUser);
    final readReceiptsAsync = canViewReaders
        ? ref.watch(
            announcementReadReceiptsProvider((
              orgId: announcement.orgId,
              announcementId: announcement.id,
            )),
          )
        : null;

    if (currentUser != null) {
      _scheduleReadReceipt(announcement, currentUser);
    }

    final headerLeague = resolveHeaderLeague(leagues, announcement.leagueId);
    final topContentPadding = appShellTopPadding(context);
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
          if (readReceiptsAsync != null) ...[
            const SizedBox(height: 16),
            _AnnouncementReadersCard(
              receiptsAsync: readReceiptsAsync,
              users: users,
            ),
          ],
        ],
      ),
    );
  }

  void _scheduleReadReceipt(Announcement announcement, AppUser currentUser) {
    final readKey = '${announcement.id}:${currentUser.id}';
    if (_scheduledReadKey == readKey) return;
    _scheduledReadKey = readKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(authorizedFirestoreServiceProvider).markAnnouncementRead(
              currentUser,
              announcement.orgId,
              announcement.id,
              scope: announcement.scope,
              leagueId: announcement.leagueId,
              hubId: announcement.hubId,
              teamId: announcement.teamId,
            );
      } catch (_) {
        // Read receipts are best-effort and must never block the announcement.
      }
    });
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

class _AnnouncementReadersCard extends StatelessWidget {
  final AsyncValue<List<AnnouncementReadReceipt>> receiptsAsync;
  final List<AppUser> users;

  const _AnnouncementReadersCard({
    required this.receiptsAsync,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    return receiptsAsync.when(
      loading: () => const AppGlassSurface(
        padding: EdgeInsets.all(16),
        radius: 24,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Loading readers…',
              style: TextStyle(
                color: AppGlassColors.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => const AppGlassSurface(
        padding: EdgeInsets.all(16),
        radius: 24,
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, color: AppGlassColors.inkMuted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reader details are temporarily unavailable.',
                style: TextStyle(
                  color: AppGlassColors.inkSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      data: (receipts) => AppGlassSurface(
        padding: const EdgeInsets.all(16),
        radius: 24,
        onTap: receipts.isEmpty
            ? null
            : () => _showReadersDialog(context, receipts),
        semanticLabel: receipts.isEmpty
            ? 'No announcement readers yet'
            : 'View ${receipts.length} announcement readers',
        child: Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              color: AppGlassColors.aqua,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Read by ${receipts.length}',
                    style: const TextStyle(
                      color: AppGlassColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    receipts.isEmpty
                        ? 'No one has opened this announcement yet.'
                        : 'Tap to view readers',
                    style: const TextStyle(
                      color: AppGlassColors.inkSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (receipts.isNotEmpty)
              const Icon(
                Icons.chevron_right,
                color: AppGlassColors.inkMuted,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReadersDialog(
    BuildContext context,
    List<AnnouncementReadReceipt> receipts,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: AppGlassSurface(
          padding: const EdgeInsets.all(18),
          radius: 28,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Read by ${receipts.length}',
                        style: const TextStyle(
                          color: AppGlassColors.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close reader list',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(
                        Icons.close,
                        color: AppGlassColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: receipts.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 17,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    itemBuilder: (context, index) {
                      final receipt = receipts[index];
                      final user = _findUser(receipt.userId);
                      return Row(
                        children: [
                          AvatarWidget(
                            imageUrl: user?.avatarUrl,
                            name: user?.displayName ?? 'Former member',
                            size: 40,
                            backgroundColor:
                                AppGlassColors.aqua.withValues(alpha: 0.18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              user?.displayName ?? 'Former member',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppGlassColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppUtils.formatDateTime(receipt.readAt),
                            style: const TextStyle(
                              color: AppGlassColors.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  }

  AppUser? _findUser(String userId) {
    for (final user in users) {
      if (user.id == userId) return user;
    }
    return null;
  }
}

class _ScopeTag extends StatelessWidget {
  final AnnouncementScope scope;
  final List<League> leagues;
  final String? leagueId;

  const _ScopeTag({required this.scope, required this.leagues, this.leagueId});

  Color get _color {
    switch (scope) {
      case AnnouncementScope.league:
        return AppGlassColors.gold;
      case AnnouncementScope.hub:
        return AppGlassColors.aqua;
      case AnnouncementScope.team:
        return AppGlassColors.gold;
    }
  }

  String get _label {
    switch (scope) {
      case AnnouncementScope.league:
        final league = leagues.where((l) => l.id == leagueId).firstOrNull;
        return league?.name ?? 'League';
      case AnnouncementScope.hub:
        return 'Hub';
      case AnnouncementScope.team:
        return 'Team';
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
