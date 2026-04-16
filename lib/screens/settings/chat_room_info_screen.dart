import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/chat_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../screens/chat_list_screen.dart';
import '../../services/authorized_firestore_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/confirmation_dialog.dart';

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
    final peer = directMessagePeer(room, currentUser, allUsers);
    final displayName = chatRoomDisplayName(room, currentUser, allUsers);

    final canManageRoom = currentUser != null &&
        room.type != ChatRoomType.direct &&
        const PermissionService().canUpdateChatRoom(currentUser);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat Info'),
        actions: [
          if (canManageRoom)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditRoomDialog(context, ref, room),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Room header
          Center(
            child: Column(
              children: [
                _RoomInfoAvatar(
                  room: room,
                  displayName: displayName,
                  peer: peer,
                ),
                const SizedBox(height: 12),
                Text(displayName,
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
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                            leading: AvatarWidget(
                              imageUrl: user.avatarUrl,
                              name: user.displayName,
                              size: 36,
                            ),
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
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
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
          if (canManageRoom) ...[
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

  Future<void> _showEditRoomDialog(
    BuildContext context,
    WidgetRef ref,
    ChatRoom room,
  ) async {
    final nameController = TextEditingController(text: room.name);
    String selectedIconName = room.roomIconName ?? 'event';
    bool useImage = room.roomImageUrl != null && room.roomImageUrl!.isNotEmpty;
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    prefixIcon: Icon(Icons.forum_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ROOM LOOK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...chatRoomIconOptions.entries.map(
                      (entry) => ChoiceChip(
                        label: Icon(entry.value, size: 18),
                        selected: !useImage && selectedIconName == entry.key,
                        onSelected: isSaving
                            ? null
                            : (_) => setDialogState(() {
                                  selectedIconName = entry.key;
                                  useImage = false;
                                  selectedImageBytes = null;
                                  selectedImageName = null;
                                }),
                      ),
                    ),
                    ActionChip(
                      avatar: Icon(
                        useImage ? Icons.check_circle : Icons.image_outlined,
                        size: 18,
                      ),
                      label: Text(selectedImageName ??
                          (useImage ? 'Current Image' : 'Use Image')),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.image,
                                withData: true,
                              );
                              final file = result?.files.single;
                              if (file?.bytes == null || file!.bytes!.isEmpty) {
                                return;
                              }
                              setDialogState(() {
                                useImage = true;
                                selectedImageBytes = file.bytes;
                                selectedImageName = file.name;
                              });
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSaving ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        AppUtils.showInfoSnackBar(
                          context,
                          'Please enter a room name.',
                        );
                        return;
                      }

                      final orgId =
                          ref.read(organizationProvider).valueOrNull?.id;
                      final currentUser =
                          ref.read(currentUserProvider).valueOrNull;
                      if (orgId == null || currentUser == null) return;

                      setDialogState(() => isSaving = true);

                      try {
                        String? roomImageUrl =
                            useImage ? room.roomImageUrl : null;
                        if (selectedImageBytes != null) {
                          final extension = (selectedImageName ?? 'room.png')
                              .split('.')
                              .last
                              .toLowerCase();
                          roomImageUrl = await StorageService().uploadBytes(
                            bytes: selectedImageBytes!,
                            path:
                                'organizations/$orgId/chatRooms/${DateTime.now().microsecondsSinceEpoch}_${selectedImageName ?? 'room.$extension'}',
                            contentType: chatRoomImageContentType(extension),
                          );
                        }

                        await ref
                            .read(authorizedFirestoreServiceProvider)
                            .updateChatRoomFields(
                          currentUser,
                          orgId,
                          room.id,
                          {
                            'name': name,
                            'roomIconName': useImage ? null : selectedIconName,
                            'roomImageUrl': roomImageUrl,
                          },
                        );

                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } on PermissionDeniedException {
                        if (context.mounted) {
                          AppUtils.showErrorSnackBar(
                            context,
                            'You do not have permission to edit chat rooms',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppUtils.showErrorSnackBar(
                            context,
                            'Could not update room: $e',
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSaving = false);
                        }
                      }
                    },
              child: Text(isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
  }

  Future<void> _confirmArchive(
      BuildContext context, WidgetRef ref, ChatRoom room) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Archive Chat Room',
      message:
          'Are you sure you want to archive "${room.name}"? Members will no longer be able to send messages.',
      confirmLabel: 'Archive',
      confirmColor: AppColors.danger,
    );
    if (ok != true) return;

    final orgId = ref.read(organizationProvider).valueOrNull?.id;
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    if (orgId == null || currentUser == null) return;
    try {
      await ref
          .read(authorizedFirestoreServiceProvider)
          .archiveChatRoom(currentUser, orgId, room.id);
      if (context.mounted) {
        context.pop(); // Back to chat conversation
        context.pop(); // Back to chat list
      }
    } on PermissionDeniedException {
      if (context.mounted) {
        AppUtils.showErrorSnackBar(
            context, 'You do not have permission to archive chat rooms');
      }
    }
  }
}

class _RoomInfoAvatar extends StatelessWidget {
  final ChatRoom room;
  final String displayName;
  final AppUser? peer;

  const _RoomInfoAvatar({
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
        size: 72,
        backgroundColor: AppColors.accent,
      );
    }

    final imageUrl = room.roomImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          placeholder: (_, __) => _IconAvatar(room: room),
          errorWidget: (_, __, ___) => _IconAvatar(room: room),
        ),
      );
    }

    return _IconAvatar(room: room);
  }
}

class _IconAvatar extends StatelessWidget {
  final ChatRoom room;

  const _IconAvatar({required this.room});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        room.type == ChatRoomType.event
            ? iconForChatRoomIconName(room.roomIconName)
            : Icons.forum,
        color: AppColors.primary,
        size: 32,
      ),
    );
  }
}
