import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/league_branding.dart';
import '../../core/picked_file.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/chat_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../screens/chat_list_screen.dart';
import '../../services/authorized_firestore_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/chat_room_avatar.dart';
import '../../widgets/confirmation_dialog.dart';

class ChatRoomInfoScreen extends ConsumerWidget {
  final String roomId;

  const ChatRoomInfoScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(chatRoomProvider(roomId));
    final usersAsync = ref.watch(orgUsersProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];

    final room = roomAsync.valueOrNull;
    final allUsers = usersAsync.valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, room?.leagueId);
    final topContentPadding = appShellTopPadding(context, extra: 12);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    if (room == null) {
      return AppShellScaffold(
        header: AppShellHeader(
          title: 'Chat Info',
          leadingIcon: Icons.info_outline,
          leadingImageUrl: headerLeague?.logoUrl,
          leadingLabel: headerLeague?.name ?? 'League Hub',
          showBackButton: true,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final participants = chatRoomMembers(room, allUsers);
    final peer = directMessagePeer(room, currentUser, allUsers);
    final displayName = chatRoomDisplayName(room, currentUser, allUsers);

    final canManageRoom = currentUser != null &&
        room.type != ChatRoomType.direct &&
        const PermissionService().canUpdateChatRoom(currentUser);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Chat Info',
        leadingIcon: Icons.info_outline,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        actions: [
          if (canManageRoom)
            AppHeaderIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit',
              onPressed: () => _showEditRoomDialog(context, ref, room),
            ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        children: [
          AppGlassSurface(
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ChatRoomAvatar(
                  room: room,
                  displayName: displayName,
                  directMessagePeer: peer,
                  size: 78,
                  borderRadius: 22,
                  iconSize: 34,
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppGlassColors.ink,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                _GlassBadge(_roomTypeLabel(room.type), AppGlassColors.aqua),
                const SizedBox(height: 12),
                Text(
                  'Created ${AppUtils.formatDate(room.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppGlassColors.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (room.type == ChatRoomType.direct)
            _DirectMessageInfoCard(
              peer: peer,
              displayName: displayName,
            )
          else
            _MembersSection(
              participants: participants,
              currentUser: currentUser,
            ),
          const SizedBox(height: 24),
          // Actions
          if (canManageRoom) ...[
            AppGlassSurface(
              radius: 22,
              padding: EdgeInsets.zero,
              onTap: () => _confirmArchive(context, ref, room),
              child: const ListTile(
                leading: Icon(
                  Icons.archive_outlined,
                  color: AppGlassColors.rose,
                  size: 22,
                ),
                title: Text(
                  'Archive Chat Room',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppGlassColors.rose,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
    await showDialog<void>(
      context: context,
      builder: (_) => _EditRoomDialog(room: room),
    );
  }

  Future<void> _confirmArchive(
      BuildContext context, WidgetRef ref, ChatRoom room) async {
    final ok = await showConfirmationDialog(
      context,
      title: 'Archive Chat Room',
      message:
          'Are you sure you want to archive "${room.name}"? Members will no longer be able to send messages.',
      confirmLabel: 'Archive',
      confirmColor: AppGlassColors.rose,
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

class _GlassBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _GlassBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GlassSectionLabel extends StatelessWidget {
  final String label;

  const _GlassSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppGlassColors.inkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _DialogGlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData prefixIcon;

  const _DialogGlassTextField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            filled: false,
            fillColor: Colors.transparent,
          ),
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: AppGlassColors.aqua,
            selectionColor: Color(0x3367E8D4),
            selectionHandleColor: AppGlassColors.aqua,
          ),
        ),
        child: TextField(
          controller: controller,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            prefixIcon: Icon(
              prefixIcon,
              color: AppGlassColors.inkSecondary,
              size: 20,
            ),
            labelStyle: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          ),
        ),
      ),
    );
  }
}

class _DialogIconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _DialogIconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      width: 54,
      height: 48,
      padding: EdgeInsets.zero,
      radius: 16,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppGlassColors.aqua.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppGlassColors.aqua.withValues(alpha: 0.32)
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            color: selected ? AppGlassColors.aqua : AppGlassColors.inkSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DialogTextChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _DialogTextChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      height: 48,
      padding: EdgeInsets.zero,
      radius: 16,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  selected ? AppGlassColors.aqua : AppGlassColors.inkSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 156),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppGlassColors.ink
                      : AppGlassColors.inkSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectMessageInfoCard extends StatelessWidget {
  final AppUser? peer;
  final String displayName;

  const _DirectMessageInfoCard({
    required this.peer,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DIRECT MESSAGE',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppGlassColors.inkMuted,
                letterSpacing: 0.2),
          ),
        ),
        AppGlassSurface(
          radius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: AvatarWidget(
                  imageUrl: peer?.avatarUrl,
                  name: displayName,
                  size: 44,
                  backgroundColor: AppGlassColors.aqua.withValues(alpha: 0.22),
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppGlassColors.ink),
                ),
                subtitle: Text(
                  peer?.roleLabel ?? 'Direct Message',
                  style: const TextStyle(
                      fontSize: 12, color: AppGlassColors.inkSecondary),
                ),
              ),
              const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppGlassColors.border),
              const ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  Icons.lock_outline,
                  color: AppGlassColors.inkSecondary,
                  size: 22,
                ),
                title: Text(
                  'Private one-on-one conversation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppGlassColors.ink,
                  ),
                ),
                subtitle: Text(
                  'Only you and this person can see messages here.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppGlassColors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditRoomDialog extends ConsumerStatefulWidget {
  final ChatRoom room;

  const _EditRoomDialog({required this.room});

  @override
  ConsumerState<_EditRoomDialog> createState() => _EditRoomDialogState();
}

class _EditRoomDialogState extends ConsumerState<_EditRoomDialog> {
  late final TextEditingController _nameController;
  late String _selectedIconName;
  late bool _useImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _selectedIconName = widget.room.roomIconName ?? 'event';
    _useImage = widget.room.roomImageUrl != null &&
        widget.room.roomImageUrl!.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await pickImageBytes();
    if (picked == null) {
      if (mounted) {
        AppUtils.showInfoSnackBar(
          context,
          'We could not read that image. Please try a different file.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _useImage = true;
      _selectedImageBytes = picked.bytes;
      _selectedImageName = picked.name;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppUtils.showInfoSnackBar(
        context,
        'Please enter a room name.',
      );
      return;
    }

    final orgId =
        ref.read(organizationProvider).valueOrNull?.id ?? widget.room.orgId;
    final currentUser = await ref.read(currentUserProvider.future);
    if (!mounted || currentUser == null) return;

    setState(() => _isSaving = true);

    var dialogClosed = false;
    try {
      String? roomImageUrl = _useImage ? widget.room.roomImageUrl : null;
      if (_selectedImageBytes != null) {
        final extension =
            (_selectedImageName ?? 'room.png').split('.').last.toLowerCase();
        roomImageUrl = await StorageService().uploadBytes(
          bytes: _selectedImageBytes!,
          path:
              'orgs/$orgId/chat/${widget.room.id}/room-images/${currentUser.id}/roomImage_${DateTime.now().microsecondsSinceEpoch}_${_selectedImageName ?? 'room.$extension'}',
          contentType: chatRoomImageContentType(extension),
        );
      }
      if (!mounted) return;

      await ref.read(authorizedFirestoreServiceProvider).updateChatRoomFields(
        currentUser,
        orgId,
        widget.room.id,
        {
          'name': name,
          'roomIconName': _useImage ? null : _selectedIconName,
          'roomImageUrl': roomImageUrl,
        },
      );

      if (mounted) {
        dialogClosed = true;
        Navigator.of(context).pop();
      }
    } on PermissionDeniedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
          context,
          'You do not have permission to edit chat rooms',
        );
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(
          context,
          'Could not update room: $e',
        );
      }
    } finally {
      if (!dialogClosed && mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AppGlassSurface(
        radius: 30,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Room',
                style: TextStyle(
                  color: AppGlassColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 18),
              _DialogGlassTextField(
                controller: _nameController,
                labelText: 'Room Name',
                prefixIcon: Icons.forum_outlined,
              ),
              const SizedBox(height: 18),
              const _GlassSectionLabel('Room Look'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...chatRoomIconOptions.entries.map(
                    (entry) => _DialogIconChoice(
                      icon: entry.value,
                      selected: !_useImage && _selectedIconName == entry.key,
                      onTap: _isSaving
                          ? null
                          : () => setState(() {
                                _selectedIconName = entry.key;
                                _useImage = false;
                                _selectedImageBytes = null;
                                _selectedImageName = null;
                              }),
                    ),
                  ),
                  _DialogTextChoice(
                    icon: _useImage ? Icons.check_circle : Icons.image_outlined,
                    label: _selectedImageName ??
                        (_useImage ? 'Current Image' : 'Use Image'),
                    selected: _useImage,
                    onTap: _isSaving ? null : _pickImage,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppGlassColors.aqua,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  AppGlassSurface(
                    width: 116,
                    height: 52,
                    padding: EdgeInsets.zero,
                    radius: 18,
                    onTap: _isSaving ? null : _save,
                    child: Center(
                      child: Text(
                        _isSaving ? 'Saving...' : 'Save',
                        style: const TextStyle(
                          color: AppGlassColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersSection extends StatelessWidget {
  final List<AppUser> participants;
  final AppUser? currentUser;

  const _MembersSection({
    required this.participants,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'MEMBERS (${participants.length})',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppGlassColors.inkMuted,
                letterSpacing: 0.2),
          ),
        ),
        AppGlassSurface(
          radius: 24,
          padding: EdgeInsets.zero,
          child: participants.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('All organization members have access',
                      style: TextStyle(
                          fontSize: 13, color: AppGlassColors.inkSecondary)),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppGlassColors.ink)),
                          subtitle: Text(user.roleLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppGlassColors.inkSecondary)),
                          trailing: user.id == currentUser?.id
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppGlassColors.aqua
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppGlassColors.aqua
                                          .withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: const Text('You',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppGlassColors.aqua,
                                          fontWeight: FontWeight.w600)),
                                )
                              : null,
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            indent: 62,
                            color: AppGlassColors.border,
                          ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
