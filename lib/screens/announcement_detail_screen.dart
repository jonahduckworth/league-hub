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
import '../widgets/avatar_widget.dart';

class AnnouncementDetailScreen extends ConsumerWidget {
  final String announcementId;

  const AnnouncementDetailScreen({super.key, required this.announcementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final userAsync = ref.watch(currentUserProvider);

    final announcement = announcementsAsync.valueOrNull
        ?.where((a) => a.id == announcementId)
        .firstOrNull;

    final leagues = leaguesAsync.valueOrNull ?? [];
    final currentUser = userAsync.valueOrNull;

    if (announcementsAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (announcement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Announcement')),
        body: const Center(child: Text('Announcement not found.')),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcement'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/announcements/${announcement.id}/edit'),
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _confirmDelete(context, ref, announcement),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pinned banner ───────────────────────────────────────────
            if (announcement.isPinned)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.push_pin, size: 16, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text('Pinned Announcement',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            // ── Scope + date row ────────────────────────────────────────
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
            const SizedBox(height: 16),

            // ── Title ───────────────────────────────────────────────────
            Text(announcement.title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                    height: 1.3)),
            const SizedBox(height: 16),

            // ── Body ────────────────────────────────────────────────────
            Text(announcement.body,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6)),
            const SizedBox(height: 28),

            // ── Author card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  AvatarWidget(
                      name: announcement.authorName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(announcement.authorName,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(announcement.authorRole,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(
                            'Posted ${AppUtils.formatDateTime(announcement.createdAt)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Announcement a) {
    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    if (orgId == null) return;

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
              ref
                  .read(firestoreServiceProvider)
                  .deleteAnnouncement(orgId, a.id)
                  .then((_) {
                if (context.mounted) context.pop();
              });
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
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
        return league?.name ?? 'League';
      case AnnouncementScope.hub:
        return 'Hub';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(_label,
          style: TextStyle(
              fontSize: 13,
              color: _color,
              fontWeight: FontWeight.w600)),
    );
  }
}
