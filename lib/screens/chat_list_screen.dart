import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/chat_room.dart';
import '../providers/data_providers.dart';
import '../widgets/league_filter.dart';

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

  void _showCreateRoomSheet(String orgId) {
    final nameController = TextEditingController();
    ChatRoomType selectedType = ChatRoomType.league;

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
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'New Chat Room',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'e.g. Coaches Chat',
                  prefixIcon: Icon(Icons.forum_outlined),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'TYPE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ChatRoomType.values.map((type) {
                  final labels = {
                    ChatRoomType.league: 'League',
                    ChatRoomType.event: 'Event',
                    ChatRoomType.direct: 'Direct',
                  };
                  return ChoiceChip(
                    label: Text(labels[type]!),
                    selected: selectedType == type,
                    onSelected: (_) => setSheetState(() => selectedType = type),
                    selectedColor: AppColors.primary.withOpacity(0.15),
                    labelStyle: TextStyle(
                      color: selectedType == type ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: selectedType == type ? FontWeight.w600 : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  await ref.read(firestoreServiceProvider).createChatRoom(
                    orgId,
                    name,
                    selectedType,
                  );
                  if (ctx.mounted) ctx.pop();
                },
                child: const Text('Create Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomsAsync = ref.watch(chatRoomsProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final orgId = ref.watch(organizationProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: orgId == null ? null : () => _showCreateRoomSheet(orgId),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          leaguesAsync.when(
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
            data: (leagues) => LeagueFilter(
              leagues: leagues,
              selectedLeagueId: _selectedLeagueId,
              onSelected: (id) => setState(() => _selectedLeagueId = id),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: chatRoomsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading chats: $e')),
              data: (rooms) {
                var filtered = rooms;

                if (_searchText.isNotEmpty) {
                  filtered = filtered
                      .where((r) => r.name.toLowerCase().contains(_searchText))
                      .toList();
                }
                if (_selectedLeagueId != null) {
                  filtered = filtered
                      .where((r) => r.leagueId == _selectedLeagueId || r.type == ChatRoomType.direct)
                      .toList();
                }

                final leagueRooms = filtered.where((r) => r.type == ChatRoomType.league).toList();
                final eventRooms = filtered.where((r) => r.type == ChatRoomType.event).toList();
                final directRooms = filtered.where((r) => r.type == ChatRoomType.direct).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 56, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text(
                          'No chat rooms yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap + to create your first room',
                          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (leagueRooms.isNotEmpty) ...[
                      _SectionHeader(title: 'League Rooms', count: leagueRooms.length),
                      ...leagueRooms.map((r) => _ChatRoomTile(room: r)),
                    ],
                    if (eventRooms.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Events & Tournaments', count: eventRooms.length),
                      ...eventRooms.map((r) => _ChatRoomTile(room: r)),
                    ],
                    if (directRooms.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionHeader(title: 'Direct Messages', count: directRooms.length),
                      ...directRooms.map((r) => _ChatRoomTile(room: r)),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

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
                color: AppColors.border, borderRadius: BorderRadius.circular(10)),
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

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  const _ChatRoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
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
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            room.type == ChatRoomType.direct
                ? Icons.person
                : room.type == ChatRoomType.event
                    ? Icons.event
                    : Icons.forum,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(room.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          room.lastMessage ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: room.lastMessage != null ? AppColors.textSecondary : AppColors.textMuted,
            fontStyle: room.lastMessage == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        trailing: room.lastMessageAt != null
            ? Text(
                AppUtils.formatDateTime(room.lastMessageAt!),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              )
            : null,
        onTap: () => context.push('/chat/${room.id}'),
      ),
    );
  }
}
