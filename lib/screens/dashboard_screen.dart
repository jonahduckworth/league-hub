import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/announcement.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../screens/chat_list_screen.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
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
    final bottomContentPadding = appShellBottomPadding(context);
    final userAsync = ref.watch(currentUserProvider);
    final orgAsync = ref.watch(organizationProvider);
    final leaguesAsync = ref.watch(leaguesProvider);

    final org = orgAsync.valueOrNull;
    final orgName = org?.name ?? 'League Hub';
    final userName = userAsync.valueOrNull?.displayName ?? '';
    final leagues = leaguesAsync.valueOrNull ?? [];
    final showLeagueFilter = leagues.length > 1;

    return AppShellScaffold(
      header: AppShellHeader(
        leadingIcon: Icons.apartment_rounded,
        leadingImageUrl: org?.logoUrl,
        leadingLabel: orgName,
        title: orgName,
        subtitle: userName.isNotEmpty
            ? 'Welcome back, $userName'
            : 'Your organization overview for today',
        actions: [
          AppHeaderIconButton(
            icon: Icons.notifications_outlined,
            tooltip: 'Notifications',
            onPressed: () => context.push('/settings/notifications'),
          ),
          AppHeaderIconButton(
            icon: Icons.search,
            tooltip: 'Search',
            onPressed: () => _showSearchSheet(context),
          ),
        ],
      ),
      stickyContent: showLeagueFilter
          ? LeagueFilter(
              leagues: leagues,
              selectedLeagueId: _selectedLeagueId,
              onSelected: (id) => setState(() => _selectedLeagueId = id),
            )
          : null,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(0, 0, 0, bottomContentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnnouncementsSection(),
            const SizedBox(height: 24),
            _buildChatsSection(),
          ],
        ),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search announcements, chats, documents...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onSubmitted: (query) {
                Navigator.pop(ctx);
                if (query.trim().isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Search'),
                      content:
                          const Text('Search functionality is coming soon.'),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _SearchChip(
                  label: 'Announcements',
                  icon: Icons.campaign,
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/announcements');
                  },
                ),
                const SizedBox(width: 8),
                _SearchChip(
                  label: 'Chats',
                  icon: Icons.chat,
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/chat');
                  },
                ),
                const SizedBox(width: 8),
                _SearchChip(
                  label: 'Documents',
                  icon: Icons.description,
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/documents');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    final announcements = ref.watch(announcementsProvider).valueOrNull ?? [];
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];
    final recent = announcements.take(3).toList();

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
              TextButton(
                onPressed: () => context.go('/announcements'),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'No announcements yet.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          )
        else
          ...recent.map((a) => _AnnouncementCard(
                announcement: a,
                author: _userById(users, a.authorId),
              )),
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
    return GestureDetector(
      onTap: () => context.push('/announcements/${announcement.id}'),
      child: Container(
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
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin,
                            size: 12, color: AppColors.warning),
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
                    color: AppColors.primary.withValues(alpha: 0.1),
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
                AvatarWidget(
                  imageUrl: author?.avatarUrl,
                  name: announcement.authorName,
                  size: 20,
                ),
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
      ),
    );
  }
}

class _SearchChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SearchChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
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
            _DashboardChatAvatar(
              room: chatRoom,
              displayName: displayName,
              peer: peer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.text)),
                  if (preview != null) ...[
                    const SizedBox(height: 2),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (chatRoom.lastMessageAt != null)
              Text(AppUtils.formatDateTime(chatRoom.lastMessageAt!),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _DashboardChatAvatar extends StatelessWidget {
  final ChatRoom room;
  final String displayName;
  final AppUser? peer;

  const _DashboardChatAvatar({
    required this.room,
    required this.displayName,
    required this.peer,
  });

  @override
  Widget build(BuildContext context) {
    if (room.type == ChatRoomType.direct) {
      return AvatarWidget(
        imageUrl: peer?.avatarUrl,
        name: displayName,
        size: 44,
        backgroundColor: AppColors.accent,
      );
    }

    final imageUrl = room.roomImageUrl;
    if (room.type == ChatRoomType.event &&
        imageUrl != null &&
        imageUrl.isNotEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _iconFallback(),
          errorWidget: (_, __, ___) => _iconFallback(),
        ),
      );
    }

    return _iconFallback();
  }

  Widget _iconFallback() {
    final isEvent = room.type == ChatRoomType.event;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isEvent ? iconForChatRoomIconName(room.roomIconName) : Icons.forum,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}
