import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../providers/mock_data.dart';
import '../widgets/league_filter.dart';
import '../widgets/avatar_widget.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  String? _selectedLeagueId;

  List<Announcement> get _filtered {
    if (_selectedLeagueId == null) return mockAnnouncements;
    return mockAnnouncements.where((a) => a.leagueId == _selectedLeagueId).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcements'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          LeagueFilter(
            leagues: mockLeagues,
            selectedLeagueId: _selectedLeagueId,
            onSelected: (id) => setState(() => _selectedLeagueId = id),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) => _AnnouncementCard(announcement: _filtered[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: announcement.isPinned ? AppColors.warning.withOpacity(0.5) : AppColors.border,
          width: announcement.isPinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (announcement.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.push_pin, size: 14, color: AppColors.warning),
                  SizedBox(width: 6),
                  Text('Pinned Announcement', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
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
                    _ScopeTag(scope: announcement.scope),
                    const Spacer(),
                    Text(AppUtils.formatDateTime(announcement.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(announcement.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 6),
                Text(announcement.body, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    AvatarWidget(name: announcement.authorName, size: 28),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(announcement.authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                        Text(announcement.authorRole, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopeTag extends StatelessWidget {
  final AnnouncementScope scope;
  const _ScopeTag({required this.scope});

  Color get color {
    switch (scope) {
      case AnnouncementScope.orgWide: return AppColors.primary;
      case AnnouncementScope.league: return AppColors.accent;
      case AnnouncementScope.hub: return AppColors.success;
    }
  }

  String get label {
    switch (scope) {
      case AnnouncementScope.orgWide: return 'Org-Wide';
      case AnnouncementScope.league: return 'League';
      case AnnouncementScope.hub: return 'Hub';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
