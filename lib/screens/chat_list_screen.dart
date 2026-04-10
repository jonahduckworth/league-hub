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
import '../widgets/bottom_sheet_handle.dart';
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

String? chatRoomPreviewText(ChatRoom room) {
  final hasMessage = room.lastMessage != null && room.lastMessage!.isNotEmpty;
  if (!hasMessage) return null;
  if (room.lastMessageBy != null) {
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
  }) createRoom,
  required VoidCallback onPermissionDenied,
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

  // ---------------------------------------------------------------------------
  // FAB action sheet
  // ---------------------------------------------------------------------------

  void _showNewChatOptions(String orgId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BottomSheetHandle(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'New Conversation',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_outlined,
                      color: AppColors.primary),
                ),
                title: const Text('New Event Room',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text(
                    'Create a group chat for an event or tournament'),
                onTap: () {
                  ctx.pop();
                  _showEventRoomSheet(orgId);
                },
              ),
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outlined,
                      color: AppColors.accent),
                ),
                title: const Text('New Direct Message',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle:
                    const Text('Start a private conversation with someone'),
                onTap: () {
                  ctx.pop();
                  _showDMSheet(orgId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // New Event Room sheet
  // ---------------------------------------------------------------------------

  void _showEventRoomSheet(String orgId) {
    final nameController = TextEditingController();
    final leaguesAsync = ref.read(leaguesProvider);
    String? selectedLeagueId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Event Room',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create a group chat for an event or tournament.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g. Spring Tournament 2025',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
              ),
              const SizedBox(height: 16),
              // Optional league association
              if (shouldShowEventRoomLeagueSelector(leaguesAsync))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LEAGUE (OPTIONAL)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('None'),
                          selected: selectedLeagueId == null,
                          onSelected: (_) =>
                              setSheetState(() => selectedLeagueId = null),
                          selectedColor: AppColors.border,
                        ),
                        ...(leaguesAsync.valueOrNull ?? []).map((l) => ChoiceChip(
                              label: Text(l.abbreviation),
                              selected: selectedLeagueId == l.id,
                              onSelected: (_) =>
                                  setSheetState(() => selectedLeagueId = l.id),
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              labelStyle: chatLeagueChipLabelStyle(
                                selected: selectedLeagueId == l.id,
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final currentUser = ref.read(currentUserProvider).valueOrNull;
                  final roomId = await createEventChatRoom(
                    currentUser: currentUser,
                    orgId: orgId,
                    roomName: nameController.text,
                    selectedLeagueId: selectedLeagueId,
                    createRoom:
                        ref.read(authorizedFirestoreServiceProvider).createChatRoom,
                    onPermissionDenied: () {
                      if (mounted) {
                        AppUtils.showErrorSnackBar(context,
                            'You do not have permission to create chat rooms');
                      }
                    },
                  );
                  if (roomId != null && ctx.mounted) {
                    ctx.pop();
                    if (mounted) context.push('/chat/$roomId');
                  }
                },
                child: const Text('Create Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // New DM sheet (user picker)
  // ---------------------------------------------------------------------------

  void _showDMSheet(String orgId) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final users = ref.read(orgUsersProvider).valueOrNull ?? [];
    final otherUsers = visibleDirectMessageUsers(users, currentUser);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: BottomSheetHandle(),
                  ),
                  const Text(
                    'New Direct Message',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose someone to message',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: otherUsers.isEmpty
                  ? const Center(
                      child: Text(
                        'No other members in your organization.',
                        style:
                            TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: otherUsers.length,
                      itemBuilder: (_, i) {
                        final user = otherUsers[i];
                        return _UserPickerTile(
                          user: user,
                          onTap: () async {
                            final navigator = Navigator.of(ctx);
                            final router = GoRouter.of(context);
                            final roomId = await openDirectMessageRoom(
                              currentUser: currentUser,
                              otherUser: user,
                              orgId: orgId,
                              getOrCreateDMRoom: ref
                                  .read(firestoreServiceProvider)
                                  .getOrCreateDMRoom,
                            );
                            if (roomId == null) return;
                            if (!ctx.mounted || !mounted) return;
                            navigator.pop();
                            router.push('/chat/$roomId');
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final orgId = ref.watch(organizationProvider).valueOrNull?.id;

    return AppShellScaffold(
      floatingActionButton: orgId == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showNewChatOptions(orgId),
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
      stickyContent: leaguesAsync.when(
        loading: () => const SizedBox(height: 48),
        error: (_, __) => const SizedBox(height: 48),
        data: (leagues) => LeagueFilter(
          leagues: leagues,
          selectedLeagueId: _selectedLeagueId,
          onSelected: (id) => setState(() => _selectedLeagueId = id),
        ),
      ),
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
    final preview = chatRoomPreviewText(room);
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
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: room.type == ChatRoomType.direct
                ? AppColors.accent.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            room.type == ChatRoomType.direct
                ? Icons.person
                : room.type == ChatRoomType.event
                    ? Icons.event
                    : Icons.forum,
            color: room.type == ChatRoomType.direct
                ? AppColors.accent
                : AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(room.name,
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

// ---------------------------------------------------------------------------
// User picker tile (for DM)
// ---------------------------------------------------------------------------

class _UserPickerTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;
  const _UserPickerTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: AvatarWidget(name: user.displayName, size: 40),
      title: Text(user.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(user.roleLabel,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
