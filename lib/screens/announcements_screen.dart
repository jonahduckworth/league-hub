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
import '../widgets/league_filter.dart';
import '../widgets/avatar_widget.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String? _selectedLeagueId;

  List<Announcement> _filterAnnouncements(
      List<Announcement> all, String? leagueId) {
    if (leagueId == null) return all;
    return all
        .where((a) =>
            a.scope == AnnouncementScope.orgWide || a.leagueId == leagueId)
        .toList();
  }

  bool _canManage(UserRole role) =>
      role == UserRole.platformOwner ||
      role == UserRole.superAdmin ||
      role == UserRole.managerAdmin;

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final userAsync = ref.watch(currentUserProvider);

    final leagues = leaguesAsync.valueOrNull ?? [];
    final allAnnouncements = announcementsAsync.valueOrNull ?? [];
    final filtered = _filterAnnouncements(allAnnouncements, _selectedLeagueId);
    final currentUser = userAsync.valueOrNull;
    final canManage = currentUser != null && _canManage(currentUser.role);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcements'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => context.push('/announcements/create'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(announcementsProvider),
        child: Column(
          children: [
            const SizedBox(height: 12),
            LeagueFilter(
              leagues: leagues,
              selectedLeagueId: _selectedLeagueId,
              onSelected: (id) => setState(() => _selectedLeagueId = id),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: announcementsAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final a = filtered[index];
                            return _AnnouncementCard(
                              announcement: a,
                              leagues: leagues,
                              canManage: canManage,
                              onTap: () =>
                                  context.push('/announcements/${a.id}'),
                              onLongPress: canManage
                                  ? () => _showOptions(context, a)
                                  : null,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined,
              size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No announcements yet',
              style:
                  TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Check back later for updates.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, Announcement a) {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  a.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                  color: AppColors.warning),
              title: Text(a.isPinned ? 'Unpin' : 'Pin'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePin(orgId, a.id, !a.isPinned, currentUser);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/announcements/${a.id}/edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Delete',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, orgId, a.id, currentUser);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePin(String orgId, String announcementId, bool isPinned,
      AppUser currentUser) async {
    try {
      await ref.read(authorizedFirestoreServiceProvider).togglePin(
            currentUser,
            orgId,
            announcementId,
            isPinned,
          );
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission denied. You cannot pin announcements.'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to toggle pin: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  void _confirmDelete(BuildContext context, String orgId, String id,
      AppUser currentUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content:
            const Text('Are you sure you want to delete this announcement?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAnnouncement(orgId, id, currentUser);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnouncement(
      String orgId, String announcementId, AppUser currentUser) async {
    try {
      await ref.read(authorizedFirestoreServiceProvider).deleteAnnouncement(
            currentUser,
            orgId,
            announcementId,
          );
    } on PermissionDeniedException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permission denied. You cannot delete announcements.'),
          backgroundColor: AppColors.danger,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: AppColors.danger,
        ));
      }
    }
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
                      Text(
                          AppUtils.formatDateTime(announcement.createdAt),
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
                      AvatarWidget(
                          name: announcement.authorName, size: 28),
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
                                  fontSize: 11,
                                  color: AppColors.textMuted)),
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

  const _ScopeTag(
      {required this.scope, required this.leagues, this.leagueId});

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
        final league =
            leagues.where((l) => l.id == leagueId).firstOrNull;
        return league?.abbreviation ?? 'League';
      case AnnouncementScope.hub:
        return 'Hub';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(_label,
          style: TextStyle(
              fontSize: 12,
              color: _color,
              fontWeight: FontWeight.w600)),
    );
  }
}
