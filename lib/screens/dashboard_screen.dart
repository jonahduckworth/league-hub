import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/chat_room.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/mock_data.dart';
import '../widgets/league_filter.dart';
import '../widgets/avatar_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedLeagueId;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final orgAsync = ref.watch(organizationProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final hubCountAsync = ref.watch(hubCountProvider);
    final teamCountAsync = ref.watch(teamCountProvider);
    final memberCountAsync = ref.watch(activeUserCountProvider);

    final orgName = orgAsync.valueOrNull?.name ?? 'League Hub';
    final userName = userAsync.valueOrNull?.displayName ?? '';
    final leagues = leaguesAsync.valueOrNull ?? [];
    final hubCount = hubCountAsync.valueOrNull ?? 0;
    final teamCount = teamCountAsync.valueOrNull ?? 0;
    final leagueCount = leagues.length;
    final memberCount = memberCountAsync.valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orgName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  Text(
                    userName.isNotEmpty ? 'Hi, $userName' : 'League Hub',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white),
                  onPressed: () {}),
              IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {}),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                LeagueFilter(
                  leagues: leagues,
                  selectedLeagueId: _selectedLeagueId,
                  onSelected: (id) => setState(() => _selectedLeagueId = id),
                ),
                const SizedBox(height: 20),
                _buildStatsRow(
                    hubCount: hubCount,
                    teamCount: teamCount,
                    leagueCount: leagueCount,
                    memberCount: memberCount),
                const SizedBox(height: 24),
                _buildAnnouncementsSection(),
                const SizedBox(height: 24),
                _buildChatsSection(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
      {required int hubCount,
      required int teamCount,
      required int leagueCount,
      required int memberCount}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: _StatCard(
                      title: 'Active Hubs',
                      value: '$hubCount',
                      icon: Icons.location_city,
                      color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      title: 'Total Teams',
                      value: '$teamCount',
                      icon: Icons.groups,
                      color: AppColors.accent)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                  child: _StatCard(
                      title: 'Leagues',
                      value: '$leagueCount',
                      icon: Icons.emoji_events,
                      color: AppColors.success)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      title: 'Members',
                      value: '$memberCount',
                      icon: Icons.people,
                      color: const Color(0xFF7C3AED))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Announcements',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
              TextButton(onPressed: () {}, child: const Text('See All')),
            ],
          ),
        ),
        ...mockAnnouncements
            .take(2)
            .map((a) => _AnnouncementCard(announcement: a)),
      ],
    );
  }

  Widget _buildChatsSection() {
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Chats',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text)),
              TextButton(
                onPressed: () => context.go('/chat'),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        if (chatRooms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No chat rooms yet. Go to Messages to create one.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          )
        else
          ...chatRooms.take(3).map((c) => _ChatCard(chatRoom: c)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(title,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
              if (announcement.isPinned)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin, size: 12, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text('Pinned',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(announcement.scopeLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(announcement.title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text)),
          const SizedBox(height: 4),
          Text(announcement.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              AvatarWidget(name: announcement.authorName, size: 20),
              const SizedBox(width: 6),
              Text(announcement.authorName,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text(AppUtils.formatDateTime(announcement.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final ChatRoom chatRoom;
  const _ChatCard({required this.chatRoom});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/chat/${chatRoom.id}'),
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: chatRoom.type == ChatRoomType.direct
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              chatRoom.type == ChatRoomType.direct
                  ? Icons.person
                  : chatRoom.type == ChatRoomType.event
                      ? Icons.event
                      : Icons.forum,
              color: chatRoom.type == ChatRoomType.direct
                  ? AppColors.accent
                  : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chatRoom.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text)),
                const SizedBox(height: 2),
                Text(chatRoom.lastMessage ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (chatRoom.lastMessageAt != null)
            Text(AppUtils.formatDateTime(chatRoom.lastMessageAt!),
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    ),
    );
  }
}
