import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/chat_room.dart';
import '../providers/mock_data.dart';
import '../widgets/league_filter.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _selectedLeagueId;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatRoom> get _leagueRooms => mockChatRooms.where((r) => r.type == ChatRoomType.league).toList();
  List<ChatRoom> get _eventRooms => mockChatRooms.where((r) => r.type == ChatRoomType.event).toList();
  List<ChatRoom> get _directRooms => mockChatRooms.where((r) => r.type == ChatRoomType.direct).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search conversations...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          LeagueFilter(
            leagues: mockLeagues,
            selectedLeagueId: _selectedLeagueId,
            onSelected: (id) => setState(() => _selectedLeagueId = id),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_leagueRooms.isNotEmpty) ...[
                  _SectionHeader(title: 'League Rooms', count: _leagueRooms.length),
                  ..._leagueRooms.map((r) => _ChatRoomTile(room: r, unreadCount: 3)),
                ],
                if (_eventRooms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Events & Tournaments', count: _eventRooms.length),
                  ..._eventRooms.map((r) => _ChatRoomTile(room: r, unreadCount: 1)),
                ],
                if (_directRooms.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Direct Messages', count: _directRooms.length),
                  ..._directRooms.map((r) => _ChatRoomTile(room: r, unreadCount: 0)),
                ],
                const SizedBox(height: 24),
              ],
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
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _ChatRoomTile extends StatelessWidget {
  final ChatRoom room;
  final int unreadCount;
  const _ChatRoomTile({required this.room, required this.unreadCount});

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
            room.type == ChatRoomType.direct ? Icons.person : room.type == ChatRoomType.event ? Icons.event : Icons.forum,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(room.lastMessage ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (room.lastMessageAt != null)
              Text(AppUtils.formatDateTime(room.lastMessageAt!), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        onTap: () {},
      ),
    );
  }
}
