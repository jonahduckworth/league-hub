import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/empty_state.dart';
import '../widgets/league_filter.dart';

class ChatRoomSectionData {
  final String title;
  final List<ChatRoom> rooms;

  const ChatRoomSectionData({
    required this.title,
    required this.rooms,
  });
}

TextStyle chatLeagueChipLabelStyle({
  required bool selected,
}) {
  return TextStyle(
    color: selected ? AppColors.primary : AppColors.textSecondary,
    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
  );
}

bool shouldShowEventRoomLeagueSelector(AsyncValue<List<League>> leaguesAsync) {
  return leaguesAsync.when(
    loading: () => false,
    error: (_, __) => false,
    data: (leagues) => leagues.isNotEmpty,
  );
}

List<AppUser> visibleDirectMessageUsers(
  List<AppUser> users,
  AppUser? currentUser,
) {
  return users.where((u) => u.id != currentUser?.id && u.isActive).toList();
}

List<ChatRoom> filterChatRooms({
  required List<ChatRoom> rooms,
  required String searchText,
  required String? selectedLeagueId,
}) {
  var filtered = rooms;

  if (searchText.isNotEmpty) {
    filtered = filtered
        .where((r) => r.name.toLowerCase().contains(searchText))
        .toList();
  }
  if (selectedLeagueId != null) {
    filtered = filtered
        .where((r) =>
            r.leagueId == selectedLeagueId || r.type == ChatRoomType.direct)
        .toList();
  }

  return filtered;
}

List<ChatRoomSectionData> buildChatRoomSections(List<ChatRoom> rooms) {
  final sections = <ChatRoomSectionData>[
    ChatRoomSectionData(
      title: 'League Rooms',
      rooms: rooms.where((r) => r.type == ChatRoomType.league).toList(),
    ),
    ChatRoomSectionData(
      title: 'Events & Tournaments',
      rooms: rooms.where((r) => r.type == ChatRoomType.event).toList(),
    ),
    ChatRoomSectionData(
      title: 'Direct Messages',
      rooms: rooms.where((r) => r.type == ChatRoomType.direct).toList(),
    ),
  ];

  return sections.where((section) => section.rooms.isNotEmpty).toList();
}

const chatRoomIconOptions = <String, IconData>{
  'event': Icons.event_outlined,
  'trophy': Icons.emoji_events_outlined,
  'group': Icons.groups_2_outlined,
  'schedule': Icons.schedule_outlined,
};

IconData iconForChatRoomIconName(String? iconName) {
  return chatRoomIconOptions[iconName] ?? Icons.event_outlined;
}

String chatRoomImageContentType(String ext) {
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    default:
      return 'image/png';
  }
}

AppUser? directMessagePeer(
  ChatRoom room,
  AppUser? currentUser,
  List<AppUser> users,
) {
  if (room.type != ChatRoomType.direct || currentUser == null) return null;
  final peerId = room.participants.firstWhere(
    (id) => id != currentUser.id,
    orElse: () => '',
  );
  if (peerId.isEmpty) return null;
  for (final user in users) {
    if (user.id == peerId) return user;
  }
  return null;
}

String chatRoomDisplayName(
  ChatRoom room,
  AppUser? currentUser,
  List<AppUser> users,
) {
  final peer = directMessagePeer(room, currentUser, users);
  if (peer != null) return peer.displayName;
  if (room.type == ChatRoomType.direct && currentUser != null) {
    final peerId = room.participants.firstWhere(
      (id) => id != currentUser.id,
      orElse: () => '',
    );
    final peerName = room.participantNames[peerId];
    if (peerName != null && peerName.isNotEmpty) return peerName;
  }
  return room.name;
}

String? chatRoomPreviewText(ChatRoom room, {AppUser? currentUser}) {
  final hasMessage = room.lastMessage != null && room.lastMessage!.isNotEmpty;
  if (!hasMessage) return null;
  if (room.lastMessageBy != null) {
    if (room.type == ChatRoomType.direct &&
        room.lastMessageBy == currentUser?.displayName) {
      return room.lastMessage!;
    }
    return '${room.lastMessageBy}: ${room.lastMessage}';
  }
  return room.lastMessage!;
}

Color chatRoomTimestampColor(int unreadCount) {
  return unreadCount > 0 ? AppColors.primary : AppColors.textMuted;
}

String formatUnreadBadgeCount(int unreadCount) {
  return unreadCount > 99 ? '99+' : '$unreadCount';
}

Future<String?> createEventChatRoom({
  required AppUser? currentUser,
  required String orgId,
  required String roomName,
  required String? selectedLeagueId,
  required Future<String> Function(
    AppUser actor,
    String orgId,
    String name,
    ChatRoomType type, {
    String? leagueId,
    List<String> participants,
    String? roomIconName,
    String? roomImageUrl,
  }) createRoom,
  required VoidCallback onPermissionDenied,
  String? roomIconName,
  String? roomImageUrl,
}) async {
  final trimmedName = roomName.trim();
  if (trimmedName.isEmpty || currentUser == null) return null;
  try {
    return await createRoom(
      currentUser,
      orgId,
      trimmedName,
      ChatRoomType.event,
      leagueId: selectedLeagueId,
      participants: [currentUser.id],
      roomIconName: roomIconName,
      roomImageUrl: roomImageUrl,
    );
  } on PermissionDeniedException {
    onPermissionDenied();
    return null;
  }
}

Future<String?> openDirectMessageRoom({
  required AppUser? currentUser,
  required AppUser otherUser,
  required String orgId,
  required Future<ChatRoom> Function(
    String orgId,
    String currentUserId,
    String otherUserId,
    String currentUserName,
    String otherUserName,
  ) getOrCreateDMRoom,
}) async {
  if (currentUser == null) return null;
  final room = await getOrCreateDMRoom(
    orgId,
    currentUser.id,
    otherUser.id,
    currentUser.displayName,
    otherUser.displayName,
  );
  return room.id;
}

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String? _selectedLeagueId;
  final _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final orgId = ref.watch(organizationProvider).valueOrNull?.id;
    final leagues = leaguesAsync.valueOrNull ?? [];
    final showLeagueFilter = leagues.length > 1;

    return AppShellScaffold(
      floatingActionButton: orgId == null
          ? null
          : FloatingActionButton(
              heroTag: 'chat_list_fab',
              onPressed: () => context.push('/chat/new'),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      header: AppShellHeader(
        eyebrow: 'CHAT',
        leadingIcon: Icons.forum_outlined,
        title: 'Messages',
        subtitle:
            'League rooms, event chats, and direct messages in one place.',
        bottom: AppHeaderSearchField(
          controller: _searchController,
          hintText: 'Search conversations...',
        ),
      ),
      stickyContent: showLeagueFilter
          ? LeagueFilter(
              leagues: leagues,
              selectedLeagueId: _selectedLeagueId,
              onSelected: (id) => setState(() => _selectedLeagueId = id),
            )
          : null,
      stickySpacing: 8,
      child: chatRoomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading chats: $e')),
        data: (rooms) {
          final filtered = filterChatRooms(
            rooms: rooms,
            searchText: _searchText,
            selectedLeagueId: _selectedLeagueId,
          );
          final sections = buildChatRoomSections(filtered);

          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No chat rooms yet',
              subtitle: 'Tap + to start a conversation',
            );
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomContentPadding),
            children: [
              for (var index = 0; index < sections.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                _SectionHeader(
                  title: sections[index].title,
                  count: sections[index].rooms.length,
                ),
                ...sections[index].rooms.map((r) => _ChatRoomTile(room: r)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(10)),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat room list tile
// ---------------------------------------------------------------------------

class _ChatRoomTile extends ConsumerWidget {
  final ChatRoom room;
  const _ChatRoomTile({required this.room});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];
    final displayName = chatRoomDisplayName(room, currentUser, users);
    final peer = directMessagePeer(room, currentUser, users);
    final preview = chatRoomPreviewText(room, currentUser: currentUser);
    final hasMessage = preview != null;
    final unreadCount =
        ref.watch(unreadCountProvider(room.id)).valueOrNull ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _ChatRoomAvatar(
          room: room,
          displayName: displayName,
          peer: peer,
        ),
        title: Text(displayName,
            style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14)),
        subtitle: Text(
          preview ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
            color: unreadCount > 0
                ? AppColors.text
                : hasMessage
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
            fontStyle: hasMessage ? FontStyle.normal : FontStyle.italic,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (room.lastMessageAt != null)
              Text(
                AppUtils.formatDateTime(room.lastMessageAt!),
                style: TextStyle(
                  fontSize: 11,
                  color: chatRoomTimestampColor(unreadCount),
                ),
              ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatUnreadBadgeCount(unreadCount),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () => context.push('/chat/${room.id}'),
      ),
    );
  }
}

class _ChatRoomAvatar extends StatelessWidget {
  final ChatRoom room;
  final String displayName;
  final AppUser? peer;

  const _ChatRoomAvatar({
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
        size: 46,
        backgroundColor: AppColors.accent,
      );
    }

    if (room.type == ChatRoomType.event && room.roomImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AvatarWidget(
          imageUrl: room.roomImageUrl,
          name: displayName,
          size: 46,
          backgroundColor: AppColors.primary,
        ),
      );
    }

    final isEvent = room.type == ChatRoomType.event;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isEvent ? iconForChatRoomIconName(room.roomIconName) : Icons.forum,
        color: AppColors.primary,
        size: 22,
      ),
    );
  }
}
