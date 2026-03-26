import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/chat_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../widgets/avatar_widget.dart';

class ChatRoomInfoScreen extends ConsumerWidget {
  final String roomId;

  const ChatRoomInfoScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(chatRoomProvider(roomId));
    final usersAsync = ref.watch(orgUsersProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    final room = roomAsync.valueOrNull;
    final allUsers = usersAsync.valueOrNull ?? [];

    if (room == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Chat Info')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Filter participants from the org users list.
    final participants = room.participants.isNotEmpty
        ? allUsers.where((u) => room.participants.contains(u.id)).toList()
        : allUsers;

    final isAdmin = currentUser?.role == UserRole.platformOwner ||
        currentUser?.role == UserRole.superAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chat Info')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Room header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: room.type == ChatRoomType.direct
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _roomIcon(room.type),
                    color: room.type == ChatRoomType.direct
                        ? AppColors.accent
                        : AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(room.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _roomTypeLabel(room.type),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Created ${AppUtils.formatDate(room.createdAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Members section
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'MEMBERS (${participants.length})',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: participants.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('All organization members have access',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  )
                : Column(
                    children: participants.asMap().entries.map((entry) {
                      final user = entry.value;
                      final isLast = entry.key == participants.length - 1;
                      return Column(
                        children: [
                          ListTile(
                            leading:
                                AvatarWidget(name: user.displayName, size: 36),
                            title: Text(user.displayName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            subtitle: Text(user.roleLabel,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            trailing: user.id == currentUser?.id
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('You',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600)),
                                  )
                                : null,
                          ),
                          if (!isLast) const Divider(height: 1, indent: 62),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          // Actions
          if (isAdmin && room.type != ChatRoomType.direct) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListTile(
                leading: const Icon(Icons.archive_outlined,
                    color: AppColors.danger, size: 22),
                title: const Text('Archive Chat Room',
                    style: TextStyle(
                        fontSize: 14,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600)),
                onTap: () => _confirmArchive(context, ref, room),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _roomIcon(ChatRoomType type) {
    switch (type) {
      case ChatRoomType.direct:
        return Icons.person;
      case ChatRoomType.event:
        return Icons.event;
      case ChatRoomType.league:
        return Icons.forum;
    }
  }

  String _roomTypeLabel(ChatRoomType type) {
    switch (type) {
      case ChatRoomType.direct:
        return 'Direct Message';
      case ChatRoomType.event:
        return 'Event Chat';
      case ChatRoomType.league:
        return 'League Chat';
    }
  }

  void _confirmArchive(BuildContext context, WidgetRef ref, ChatRoom room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Chat Room'),
        content: Text(
            'Are you sure you want to archive "${room.name}"? Members will no longer be able to send messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final orgId =
                  ref.read(organizationProvider).valueOrNull?.id;
              final currentUser =
                  ref.read(currentUserProvider).valueOrNull;
              if (orgId == null || currentUser == null) return;
              try {
                await ref
                    .read(authorizedFirestoreServiceProvider)
                    .archiveChatRoom(currentUser, orgId, room.id);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  context.pop(); // Back to chat conversation
                  context.pop(); // Back to chat list
                }
              } on PermissionDeniedException {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You do not have permission to archive chat rooms'),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}
