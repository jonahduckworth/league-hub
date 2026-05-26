import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../navigation/announcement_navigation_source.dart';
import '../navigation/chat_navigation_source.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../screens/chat_list_screen.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/chat_room_avatar.dart';
import '../widgets/league_filter.dart';
import '../widgets/avatar_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedLeagueId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final leaguesAsync = ref.watch(leaguesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;

    final leagues = leaguesAsync.valueOrNull ?? [];
    final showLeagueFilter = leagues.length > 1;
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final headerImageUrl = headerLeague?.logoUrl;
    final headerLabel = headerLeague?.name ?? org?.name ?? 'League Hub';
    final topContentPadding = appShellTopPadding(
      context,
      stickyHeight: showLeagueFilter ? 38 : 0,
    );

    return AppShellScaffold(
      header: AppShellHeader(
        title: headerLabel,
        content: Row(
          children: [
            Expanded(child: _buildSearchBar(context)),
            const SizedBox(width: 12),
            AppHeaderLogoMark(
              imageUrl: headerImageUrl,
              label: headerLabel,
            ),
          ],
        ),
      ),
      stickyContent: showLeagueFilter
          ? LeagueFilter(
              leagues: leagues,
              selectedLeagueId: _selectedLeagueId,
              onSelected: (id) => setState(() => _selectedLeagueId = id),
            )
          : null,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, topContentPadding, 16, bottomContentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnnouncementsSection(),
            const SizedBox(height: 18),
            _buildNavigationTiles(context),
            const SizedBox(height: 24),
            _buildChatsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return AppGlassSurface(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      radius: 22,
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: AppGlassColors.inkSecondary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              cursorColor: AppGlassColors.aqua,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Search chats, policies, announcements...',
                hintStyle: TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (query) => _submitSearch(context, query),
            ),
          ),
        ],
      ),
    );
  }

  void _submitSearch(BuildContext context, String query) {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Search'),
        content: const Text('Search functionality is coming soon.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTiles(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppGlassIconTile(
            icon: Icons.folder_copy_outlined,
            label: 'Policies',
            subtitle: 'Files and rules',
            accentColor: AppGlassColors.aqua,
            onTap: () => context.go('/policy'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppGlassIconTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            subtitle: 'Profile and tools',
            accentColor: AppGlassColors.gold,
            onTap: () => context.go('/settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsSection() {
    final announcements = ref.watch(announcementsProvider).valueOrNull ?? [];
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];
    final recent = announcements.take(5).toList();
    final cardWidth =
        (MediaQuery.sizeOf(context).width * 0.82).clamp(292.0, 340.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Announcements',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppGlassColors.ink)),
              TextButton(
                onPressed: () => context.go('/announcements'),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No announcements yet.',
              style: TextStyle(fontSize: 13, color: AppGlassColors.inkMuted),
            ),
          )
        else
          SizedBox(
            height: 212,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: recent.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == recent.length) {
                  return _AnnouncementSeeAllCard(
                    width: cardWidth.toDouble(),
                    onTap: () => context.go('/announcements'),
                  );
                }

                final announcement = recent[index];
                return SizedBox(
                  width: cardWidth.toDouble(),
                  child: _AnnouncementCard(
                    announcement: announcement,
                    author: _userById(users, announcement.authorId),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildChatsSection() {
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull ?? [];
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Chats',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppGlassColors.ink)),
              TextButton(
                onPressed: () => context.go('/chat'),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        if (chatRooms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No chat rooms yet. Go to Messages to create one.',
              style: TextStyle(fontSize: 13, color: AppGlassColors.inkMuted),
            ),
          )
        else
          ...chatRooms.take(3).map((c) => _ChatCard(
                chatRoom: c,
                currentUser: currentUser,
                users: users,
              )),
      ],
    );
  }

  AppUser? _userById(List<AppUser> users, String id) {
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final AppUser? author;

  const _AnnouncementCard({
    required this.announcement,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      radius: 22,
      onTap: () => context.go(
        '/announcements/${announcement.id}',
        extra: AnnouncementNavigationSource.dashboardCard,
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
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppGlassColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppGlassColors.gold.withValues(alpha: 0.28),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin,
                          size: 12, color: AppGlassColors.gold),
                      SizedBox(width: 4),
                      Text('Pinned',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppGlassColors.gold,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppGlassColors.aqua.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppGlassColors.aqua.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(announcement.scopeLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppGlassColors.aqua,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(announcement.title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppGlassColors.ink)),
          const SizedBox(height: 5),
          Text(announcement.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppGlassColors.inkSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarWidget(
                imageUrl: author?.avatarUrl,
                name: announcement.authorName,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(announcement.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppGlassColors.inkSecondary)),
              ),
              Text(AppUtils.formatDateTime(announcement.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppGlassColors.inkMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnnouncementSeeAllCard extends StatelessWidget {
  final double width;
  final VoidCallback onTap;

  const _AnnouncementSeeAllCard({
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      width: width,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(18),
      radius: 22,
      onTap: onTap,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.arrow_forward,
            color: AppGlassColors.aqua,
            size: 28,
          ),
          Spacer(),
          Text(
            'See All',
            style: TextStyle(
              color: AppGlassColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Open the full announcement feed',
            style: TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final ChatRoom chatRoom;
  final AppUser? currentUser;
  final List<AppUser> users;

  const _ChatCard({
    required this.chatRoom,
    required this.currentUser,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = chatRoomDisplayName(chatRoom, currentUser, users);
    final peer = directMessagePeer(chatRoom, currentUser, users);
    final preview = chatRoomPreviewText(chatRoom, currentUser: currentUser);

    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      radius: 20,
      onTap: () => context.go(
        '/chat/${chatRoom.id}',
        extra: ChatNavigationSource.dashboardCard,
      ),
      child: Row(
        children: [
          ChatRoomAvatar(
            room: chatRoom,
            displayName: displayName,
            directMessagePeer: peer,
            size: 44,
            showImageBorder: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppGlassColors.ink)),
                if (preview != null) ...[
                  const SizedBox(height: 3),
                  Text(preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppGlassColors.inkSecondary)),
                ],
              ],
            ),
          ),
          if (chatRoom.lastMessageAt != null)
            Text(AppUtils.formatDateTime(chatRoom.lastMessageAt!),
                style: const TextStyle(
                    fontSize: 11, color: AppGlassColors.inkMuted)),
        ],
      ),
    );
  }
}
