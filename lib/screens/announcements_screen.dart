import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../services/permission_service.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/league_filter.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/status_badge.dart';

class AnnouncementSummaryData {
  final IconData icon;
  final String label;

  const AnnouncementSummaryData({
    required this.icon,
    required this.label,
  });
}

class AnnouncementActionData {
  final IconData icon;
  final Color iconColor;
  final String label;
  final TextStyle? textStyle;
  final VoidCallback onTap;

  const AnnouncementActionData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.textStyle,
  });
}

List<Announcement> filterAnnouncementsByLeague(
  List<Announcement> announcements,
  String? leagueId,
) {
  if (leagueId == null) return announcements;
  return announcements
      .where((a) =>
          a.scope == AnnouncementScope.orgWide || a.leagueId == leagueId)
      .toList();
}

bool canManageAnnouncements(UserRole role) {
  return PermissionService.isAtLeast(role, UserRole.managerAdmin);
}

List<AnnouncementSummaryData> buildAnnouncementSummaries(
  List<Announcement> announcements,
) {
  return [
    AnnouncementSummaryData(
      icon: Icons.push_pin_outlined,
      label: '${announcements.where((a) => a.isPinned).length} pinned',
    ),
    AnnouncementSummaryData(
      icon: Icons.public_outlined,
      label: '${announcements.length} total posts',
    ),
  ];
}

Future<void> refreshAnnouncements(WidgetRef ref) async {
  ref.invalidate(announcementsProvider);
}

Future<bool> toggleAnnouncementPin({
  required AuthorizedFirestoreService service,
  required AppUser currentUser,
  required String orgId,
  required String announcementId,
  required bool isPinned,
  required void Function(String message) onError,
}) async {
  try {
    await service.togglePin(currentUser, orgId, announcementId, isPinned);
    return true;
  } on PermissionDeniedException {
    onError('Permission denied. You cannot pin announcements.');
    return false;
  } catch (e) {
    onError('Failed to toggle pin: $e');
    return false;
  }
}

Future<bool> deleteAnnouncementWithHandling({
  required AuthorizedFirestoreService service,
  required AppUser currentUser,
  required String orgId,
  required String announcementId,
  required void Function(String message) onError,
}) async {
  try {
    await service.deleteAnnouncement(currentUser, orgId, announcementId);
    return true;
  } on PermissionDeniedException {
    onError('Permission denied. You cannot delete announcements.');
    return false;
  } catch (e) {
    onError('Delete failed: $e');
    return false;
  }
}

List<AnnouncementActionData> buildAnnouncementActions({
  required Announcement announcement,
  required VoidCallback onTogglePin,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return [
    AnnouncementActionData(
      icon: announcement.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
      iconColor: AppColors.warning,
      label: announcement.isPinned ? 'Unpin' : 'Pin',
      onTap: onTogglePin,
    ),
    AnnouncementActionData(
      icon: Icons.edit_outlined,
      iconColor: AppColors.primary,
      label: 'Edit',
      onTap: onEdit,
    ),
    AnnouncementActionData(
      icon: Icons.delete_outline,
      iconColor: AppColors.danger,
      label: 'Delete',
      textStyle: const TextStyle(color: AppColors.danger),
      onTap: onDelete,
    ),
  ];
}

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String? _selectedLeagueId;

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final announcementsAsync = ref.watch(announcementsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final userAsync = ref.watch(currentUserProvider);

    final leagues = leaguesAsync.valueOrNull ?? [];
    final allAnnouncements = announcementsAsync.valueOrNull ?? [];
    final filtered =
        filterAnnouncementsByLeague(allAnnouncements, _selectedLeagueId);
    final currentUser = userAsync.valueOrNull;
    final canManage =
        currentUser != null && canManageAnnouncements(currentUser.role);
    final summaryItems = buildAnnouncementSummaries(allAnnouncements);

    return AppShellScaffold(
      floatingActionButton: canManage
          ? FloatingActionButton(
              heroTag: 'announcements_fab',
              onPressed: () => context.push('/announcements/create'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      header: AppShellHeader(
        eyebrow: 'UPDATES',
        leadingIcon: Icons.campaign_outlined,
        title: 'Announcements',
        subtitle:
            'Keep teams, staff, and families aligned with the latest updates.',
        bottom: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: summaryItems
              .map((item) => _InfoChip(icon: item.icon, label: item.label))
              .toList(),
        ),
      ),
      stickyContent: LeagueFilter(
        leagues: leagues,
        selectedLeagueId: _selectedLeagueId,
        onSelected: (id) => setState(() => _selectedLeagueId = id),
      ),
      child: RefreshIndicator(
        onRefresh: () => refreshAnnouncements(ref),
        child: announcementsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'No announcements yet',
                    subtitle: 'Check back later for updates.',
                  )
                : ListView.builder(
                    padding:
                        EdgeInsets.fromLTRB(16, 0, 16, bottomContentPadding),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final a = filtered[index];
                      return _AnnouncementCard(
                        announcement: a,
                        leagues: leagues,
                        canManage: canManage,
                        onTap: () => context.push('/announcements/${a.id}'),
                        onLongPress:
                            canManage ? () => _showOptions(context, a) : null,
                      );
                    },
                  ),
      ),
    );
  }

  void _showOptions(BuildContext context, Announcement a) {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;
    final actions = buildAnnouncementActions(
      announcement: a,
      onTogglePin: () => _togglePin(orgId, a.id, !a.isPinned, currentUser),
      onEdit: () => context.push('/announcements/${a.id}/edit'),
      onDelete: () => _confirmDelete(context, orgId, a.id, currentUser),
    );

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions
              .map(
                (action) => ListTile(
                  leading: Icon(action.icon, color: action.iconColor),
                  title: Text(action.label, style: action.textStyle),
                  onTap: () {
                    Navigator.pop(ctx);
                    action.onTap();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _togglePin(String orgId, String announcementId, bool isPinned,
      AppUser currentUser) async {
    await toggleAnnouncementPin(
      service: ref.read(authorizedFirestoreServiceProvider),
      currentUser: currentUser,
      orgId: orgId,
      announcementId: announcementId,
      isPinned: isPinned,
      onError: (message) {
        if (mounted) {
          AppUtils.showErrorSnackBar(context, message);
        }
      },
    );
  }

  void _confirmDelete(BuildContext context, String orgId, String id,
      AppUser currentUser) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Delete Announcement',
      message: 'Are you sure you want to delete this announcement?',
      confirmLabel: 'Delete',
      confirmColor: AppColors.danger,
    );
    if (ok == true) {
      _deleteAnnouncement(orgId, id, currentUser);
    }
  }

  Future<void> _deleteAnnouncement(
      String orgId, String announcementId, AppUser currentUser) async {
    await deleteAnnouncementWithHandling(
      service: ref.read(authorizedFirestoreServiceProvider),
      currentUser: currentUser,
      orgId: orgId,
      announcementId: announcementId,
      onError: (message) {
        if (mounted) {
          AppUtils.showErrorSnackBar(context, message);
        }
      },
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final List<League> leagues;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AnnouncementCard({
    required this.announcement,
    required this.leagues,
    required this.canManage,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: announcement.isPinned
                ? AppColors.warning.withValues(alpha: 0.5)
                : AppColors.border,
            width: announcement.isPinned ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (announcement.isPinned)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.push_pin, size: 14, color: AppColors.warning),
                    SizedBox(width: 6),
                    Text('Pinned Announcement',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
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
                      Text(AppUtils.formatDateTime(announcement.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(announcement.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text)),
                  const SizedBox(height: 6),
                  Text(announcement.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AvatarWidget(name: announcement.authorName, size: 28),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(announcement.authorName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text)),
                          Text(announcement.authorRole,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        return AppColors.primary;
      case AnnouncementScope.league:
        return AppColors.accent;
      case AnnouncementScope.hub:
        return AppColors.success;
    }
  }

  String get _label {
    switch (scope) {
      case AnnouncementScope.orgWide:
        return 'Org-Wide';
      case AnnouncementScope.league:
        final league = leagues.where((l) => l.id == leagueId).firstOrNull;
        return league?.abbreviation ?? 'League';
      case AnnouncementScope.hub:
        return 'Hub';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: _label, color: _color);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
