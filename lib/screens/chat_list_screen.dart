import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/design_system.dart';
import '../core/league_branding.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/authorized_firestore_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_states.dart';
import '../widgets/chat_room_avatar.dart';
import '../widgets/empty_state.dart';
import '../widgets/league_filter.dart';

const double _chatTypeSelectorMinHeight = 44;
const double _chatTypeLabelSize = 13;
const double _chatTypeVerticalInsets = 20;
const double _leagueFilterHeight = 38;
const double _stickyFilterGap = 8;

double chatTypeSelectorHeight(BuildContext context) {
  final accessibleHeight =
      MediaQuery.textScalerOf(context).scale(_chatTypeLabelSize) +
          _chatTypeVerticalInsets;
  return accessibleHeight > _chatTypeSelectorMinHeight
      ? accessibleHeight
      : _chatTypeSelectorMinHeight;
}

enum ChatRoomListFilter {
  all('All'),
  leagueRooms('League Rooms'),
  hubRooms('Hub Rooms'),
  teamRooms('Team Rooms'),
  events('Events'),
  directMessages('Direct Messages');

  final String label;

  const ChatRoomListFilter(this.label);
}

ChatRoomListFilter chatRoomCategory(ChatRoom room) {
  if (room.type == ChatRoomType.direct) {
    return ChatRoomListFilter.directMessages;
  }
  if (room.isEventRoom) {
    return ChatRoomListFilter.events;
  }
  if (room.teamId?.isNotEmpty == true) {
    return ChatRoomListFilter.teamRooms;
  }
  if (room.hubId?.isNotEmpty == true) {
    return ChatRoomListFilter.hubRooms;
  }
  return ChatRoomListFilter.leagueRooms;
}

class ChatRoomSectionData {
  final String title;
  final List<ChatRoom> rooms;

  const ChatRoomSectionData({required this.title, required this.rooms});
}

TextStyle chatLeagueChipLabelStyle({required bool selected}) {
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
  ChatRoomListFilter roomFilter = ChatRoomListFilter.all,
}) {
  var filtered = rooms;

  if (searchText.isNotEmpty) {
    filtered = filtered
        .where((r) => r.name.toLowerCase().contains(searchText))
        .toList();
  }
  if (selectedLeagueId != null) {
    filtered = filtered
        .where(
          (r) =>
              r.leagueId == selectedLeagueId || r.type == ChatRoomType.direct,
        )
        .toList();
  }

  filtered = switch (roomFilter) {
    ChatRoomListFilter.all => filtered,
    ChatRoomListFilter.leagueRooms =>
      filtered.where((r) => chatRoomCategory(r) == roomFilter).toList(),
    ChatRoomListFilter.hubRooms =>
      filtered.where((r) => chatRoomCategory(r) == roomFilter).toList(),
    ChatRoomListFilter.teamRooms =>
      filtered.where((r) => chatRoomCategory(r) == roomFilter).toList(),
    ChatRoomListFilter.events =>
      filtered.where((r) => chatRoomCategory(r) == roomFilter).toList(),
    ChatRoomListFilter.directMessages =>
      filtered.where((r) => chatRoomCategory(r) == roomFilter).toList(),
  };

  return filtered;
}

List<ChatRoomSectionData> buildChatRoomSections(List<ChatRoom> rooms) {
  final sections = <ChatRoomSectionData>[
    ChatRoomSectionData(
      title: 'League Rooms',
      rooms: rooms
          .where((r) => chatRoomCategory(r) == ChatRoomListFilter.leagueRooms)
          .toList(),
    ),
    ChatRoomSectionData(
      title: 'Hub Rooms',
      rooms: rooms
          .where((r) => chatRoomCategory(r) == ChatRoomListFilter.hubRooms)
          .toList(),
    ),
    ChatRoomSectionData(
      title: 'Team Rooms',
      rooms: rooms
          .where((r) => chatRoomCategory(r) == ChatRoomListFilter.teamRooms)
          .toList(),
    ),
    ChatRoomSectionData(
      title: 'Events',
      rooms: rooms
          .where((r) => chatRoomCategory(r) == ChatRoomListFilter.events)
          .toList(),
    ),
    ChatRoomSectionData(
      title: 'Direct Messages',
      rooms: rooms
          .where(
            (r) => chatRoomCategory(r) == ChatRoomListFilter.directMessages,
          )
          .toList(),
    ),
  ];

  return sections.where((section) => section.rooms.isNotEmpty).toList();
}

DateTime chatRoomActivityAt(ChatRoom room) {
  return room.lastMessageAt ?? room.createdAt;
}

List<ChatRoom> orderChatRoomsForDisplay(List<ChatRoom> rooms) {
  final ordered = [...rooms];
  ordered.sort((a, b) {
    final activityCompare = chatRoomActivityAt(
      b,
    ).compareTo(chatRoomActivityAt(a));
    if (activityCompare != 0) return activityCompare;
    return a.name.compareTo(b.name);
  });
  return ordered;
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

bool chatRoomLastMessageIsBlocked(
  ChatRoom room,
  AppUser? currentUser,
  List<AppUser> users,
) {
  if (currentUser == null || currentUser.blockedUserIds.isEmpty) return false;
  final senderId = room.lastMessageSenderId;
  if (senderId != null) return currentUser.blockedUserIds.contains(senderId);
  if (room.type == ChatRoomType.direct) {
    return room.participants.any(
      (id) => id != currentUser.id && currentUser.blockedUserIds.contains(id),
    );
  }
  final blockedNames = users
      .where((user) => currentUser.blockedUserIds.contains(user.id))
      .map((user) => user.displayName)
      .toSet();
  return blockedNames.contains(room.lastMessageBy);
}

String? chatRoomPreviewText(
  ChatRoom room, {
  AppUser? currentUser,
  bool lastMessageIsBlocked = false,
}) {
  final hasMessage = room.lastMessage != null && room.lastMessage!.isNotEmpty;
  if (!hasMessage) return null;
  if (lastMessageIsBlocked) return 'Blocked message hidden';
  if (room.lastMessageBy != null) {
    if (room.type == ChatRoomType.direct &&
        room.lastMessageBy == currentUser?.displayName) {
      return room.lastMessage!;
    }
    return '${room.lastMessageBy}: ${room.lastMessage}';
  }
  return room.lastMessage!;
}

List<AppUser> chatRoomMembers(ChatRoom room, List<AppUser> users) {
  final activeUsers = users.where((user) => user.isActive).toList();
  if (room.type == ChatRoomType.direct) {
    return activeUsers
        .where((user) => room.participants.contains(user.id))
        .toList();
  }
  if (room.hasMultiTeamAudience) {
    return activeUsers
        .where(
          (user) =>
              room.teamIds.any(user.teamIds.contains) ||
              (user.role == UserRole.managerAdmin &&
                  room.hubIds.any(user.hubIds.contains)),
        )
        .toList();
  }
  if (room.leagueId != null) {
    if (room.teamId != null) {
      return activeUsers
          .where(
            (user) =>
                user.teamIds.contains(room.teamId) ||
                (room.hubId != null && user.hubIds.contains(room.hubId)),
          )
          .toList();
    }
    if (room.hubId != null) {
      return activeUsers
          .where((user) => user.hubIds.contains(room.hubId))
          .toList();
    }
    return activeUsers
        .where((user) => user.leagueIds.contains(room.leagueId))
        .toList();
  }
  if (room.participants.isNotEmpty) {
    return activeUsers
        .where((user) => room.participants.contains(user.id))
        .toList();
  }
  return activeUsers;
}

Color chatRoomTimestampColor(int unreadCount) {
  return unreadCount > 0 ? AppColors.primary : AppColors.textMuted;
}

String formatUnreadBadgeCount(int unreadCount) {
  return unreadCount > 99 ? '99+' : '$unreadCount';
}

Future<String?> createSharedChatRoom({
  required AppUser? currentUser,
  required String orgId,
  required String roomName,
  required ChatRoomPurpose roomPurpose,
  required String selectedLeagueId,
  String? selectedHubId,
  String? selectedTeamId,
  required Future<String> Function(
    AppUser actor,
    String orgId,
    String name,
    ChatRoomType type, {
    String? leagueId,
    String? hubId,
    String? teamId,
    List<String> participants,
    String? roomIconName,
    String? roomImageUrl,
    ChatRoomPurpose? roomPurpose,
  }) createRoom,
  required VoidCallback onPermissionDenied,
  String? roomIconName,
  String? roomImageUrl,
  List<String>? participantIds,
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
      hubId: selectedHubId,
      teamId: selectedTeamId,
      participants: participantIds ?? [currentUser.id],
      roomIconName: roomIconName,
      roomImageUrl: roomImageUrl,
      roomPurpose: roomPurpose,
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
  ChatRoomListFilter _selectedRoomFilter = ChatRoomListFilter.all;

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;
    final orgId = org?.id;
    final leagues = leaguesAsync.valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final showLeagueFilter = leagues.length > 1;
    final stickyHeight = chatTypeSelectorHeight(context) +
        (showLeagueFilter ? _stickyFilterGap + _leagueFilterHeight : 0);
    final topContentPadding = appShellTopPadding(
      context,
      stickyHeight: stickyHeight,
      stickySpacing: 8,
    );

    return AppShellScaffold(
      floatingActionButton: orgId == null
          ? null
          : AppGlassFloatingActionButton(
              icon: Icons.add,
              tooltip: 'New chat',
              onTap: () => context.push('/chat/new'),
            ),
      header: AppShellHeader(
        leadingIcon: Icons.forum_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        title: 'Messages',
      ),
      stickyContent: _ChatListStickyFilters(
        selectedRoomFilter: _selectedRoomFilter,
        onRoomFilterSelected: (filter) {
          setState(() => _selectedRoomFilter = filter);
        },
        showLeagueFilter: showLeagueFilter,
        leagues: leagues,
        selectedLeagueId: _selectedLeagueId,
        onLeagueSelected: (id) => setState(() => _selectedLeagueId = id),
      ),
      stickySpacing: 8,
      child: chatRoomsAsync.when(
        loading: () => const AppLoadingState(label: 'Loading conversations…'),
        error: (e, _) => AppErrorState(
          title: 'Unable to load conversations',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(chatRoomsProvider),
        ),
        data: (rooms) {
          final filtered = filterChatRooms(
            rooms: rooms,
            searchText: '',
            selectedLeagueId: _selectedLeagueId,
            roomFilter: _selectedRoomFilter,
          );
          final visibleRooms = orderChatRoomsForDisplay(filtered);

          if (filtered.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No chat rooms yet',
              subtitle: 'Tap + to start a conversation',
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              topContentPadding,
              16,
              bottomContentPadding,
            ),
            itemCount: visibleRooms.length,
            itemBuilder: (context, index) => AppMotionReveal(
              index: index,
              child: _ChatRoomTile(room: visibleRooms[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ChatListStickyFilters extends StatelessWidget {
  final ChatRoomListFilter selectedRoomFilter;
  final ValueChanged<ChatRoomListFilter> onRoomFilterSelected;
  final bool showLeagueFilter;
  final List<League> leagues;
  final String? selectedLeagueId;
  final ValueChanged<String?> onLeagueSelected;

  const _ChatListStickyFilters({
    required this.selectedRoomFilter,
    required this.onRoomFilterSelected,
    required this.showLeagueFilter,
    required this.leagues,
    required this.selectedLeagueId,
    required this.onLeagueSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChatTypeSelector(
          selected: selectedRoomFilter,
          onSelected: onRoomFilterSelected,
        ),
        if (showLeagueFilter) ...[
          const SizedBox(height: _stickyFilterGap),
          LeagueFilter(
            leagues: leagues,
            selectedLeagueId: selectedLeagueId,
            onSelected: onLeagueSelected,
          ),
        ],
      ],
    );
  }
}

class _ChatTypeSelector extends StatelessWidget {
  final ChatRoomListFilter selected;
  final ValueChanged<ChatRoomListFilter> onSelected;

  const _ChatTypeSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectorHeight = chatTypeSelectorHeight(context);
    return SizedBox(
      height: selectorHeight,
      child: ListView(
        key: const ValueKey('chat-type-selector'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final filter in ChatRoomListFilter.values)
            _ChatTypePill(
              key: ValueKey('chat-type-filter-${filter.name}'),
              label: filter.label,
              isSelected: selected == filter,
              onTap: () => onSelected(filter),
            ),
        ],
      ),
    );
  }
}

class _ChatTypePill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatTypePill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectorHeight = chatTypeSelectorHeight(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: selectorHeight,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(right: 8),
          child: AnimatedContainer(
            duration: AppMotion.accessible(context, AppMotion.fast),
            curve: AppMotion.enter,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppGlassColors.aqua.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? AppGlassColors.aqua.withValues(alpha: 0.5)
                    : AppGlassColors.border,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color:
                    isSelected ? AppGlassColors.aqua : AppGlassColors.inkMuted,
                fontSize: _chatTypeLabelSize,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
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
    final lastMessageIsBlocked = chatRoomLastMessageIsBlocked(
      room,
      currentUser,
      users,
    );
    final preview = chatRoomPreviewText(
      room,
      currentUser: currentUser,
      lastMessageIsBlocked: lastMessageIsBlocked,
    );
    final hasMessage = preview != null;
    final unreadCount =
        ref.watch(unreadCountProvider(room.id)).valueOrNull ?? 0;

    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      radius: 20,
      quality: appGlassListSurfaceQuality,
      onTap: () => context.push('/chat/${room.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: ChatRoomAvatar(
          room: room,
          displayName: displayName,
          directMessagePeer: peer,
        ),
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
            color: AppGlassColors.ink,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          preview ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
            color: unreadCount > 0
                ? AppGlassColors.ink
                : hasMessage
                    ? AppGlassColors.inkSecondary
                    : AppGlassColors.inkMuted,
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
                  color: unreadCount > 0
                      ? AppGlassColors.aqua
                      : AppGlassColors.inkMuted,
                ),
              ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppGlassColors.aqua,
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
      ),
    );
  }
}
