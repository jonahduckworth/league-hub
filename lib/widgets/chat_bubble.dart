import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/design_system.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/message.dart';
import '../models/message_reaction.dart';
import '../screens/viewers/image_viewer_screen.dart';
import 'app_glass.dart';
import 'avatar_widget.dart';
import 'message_reactions.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isSelf;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReportMessage;
  final VoidCallback? onReportUser;
  final VoidCallback? onBlockUser;
  final String? currentUserId;
  final List<AppUser> users;
  final ValueChanged<MessageReaction>? onToggleReaction;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSelf,
    this.onEdit,
    this.onDelete,
    this.onReportMessage,
    this.onReportUser,
    this.onBlockUser,
    this.currentUserId,
    this.users = const [],
    this.onToggleReaction,
  });

  void _toggleReaction(BuildContext sheetContext, MessageReaction reaction) {
    Navigator.pop(sheetContext);
    HapticFeedback.selectionClick();
    onToggleReaction?.call(reaction);
  }

  void _showReactionPicker(BuildContext context) {
    if (message.deleted || currentUserId == null || onToggleReaction == null) {
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AppGlassSurface(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 0, 6, 4),
                  child: Text(
                    'React to message',
                    style: TextStyle(
                      color: AppGlassColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                MessageReactionPicker(
                  reactions: message.reactions,
                  currentUserId: currentUserId!,
                  onSelected: (reaction) => _toggleReaction(ctx, reaction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    if (message.deleted) return;
    showModalBottomSheet(
      context: context,
      sheetAnimationStyle: AppMotion.overlayStyle(context),
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: AppGlassSurface(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppGlassColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                if (currentUserId != null && onToggleReaction != null) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        'React',
                        style: TextStyle(
                          color: AppGlassColors.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  MessageReactionPicker(
                    reactions: message.reactions,
                    currentUserId: currentUserId!,
                    onSelected: (reaction) => _toggleReaction(ctx, reaction),
                  ),
                  const Divider(height: 18, color: AppGlassColors.border),
                ],
                if (message.text != null && onEdit != null)
                  ListTile(
                    leading: const Icon(Icons.edit, color: AppGlassColors.aqua),
                    title: const Text(
                      'Edit message',
                      style: TextStyle(
                        color: AppGlassColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onEdit!();
                    },
                  ),
                if (onDelete != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: AppGlassColors.rose,
                    ),
                    title: const Text(
                      'Delete message',
                      style: TextStyle(
                        color: AppGlassColors.rose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDelete!();
                    },
                  ),
                if (!isSelf && onReportMessage != null)
                  ListTile(
                    leading: const Icon(
                      Icons.flag_outlined,
                      color: AppGlassColors.gold,
                    ),
                    title: const Text(
                      'Report message',
                      style: TextStyle(
                        color: AppGlassColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onReportMessage!();
                    },
                  ),
                if (!isSelf && onReportUser != null)
                  ListTile(
                    leading: const Icon(
                      Icons.person_off_outlined,
                      color: AppGlassColors.gold,
                    ),
                    title: const Text(
                      'Report user',
                      style: TextStyle(
                        color: AppGlassColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onReportUser!();
                    },
                  ),
                if (!isSelf && onBlockUser != null)
                  ListTile(
                    leading: const Icon(
                      Icons.block,
                      color: AppGlassColors.rose,
                    ),
                    title: Text(
                      'Block ${message.senderName}',
                      style: const TextStyle(
                        color: AppGlassColors.rose,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      onBlockUser!();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = message.deleted;
    final bubbleColor = isDeleted
        ? AppGlassColors.inkMuted.withValues(alpha: 0.08)
        : isSelf
            ? AppGlassColors.aqua.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.08);
    final borderColor = isSelf && !isDeleted
        ? AppGlassColors.aqua.withValues(alpha: 0.28)
        : AppGlassColors.border;

    return Padding(
      padding: EdgeInsets.only(
        left: isSelf ? 60 : 12,
        right: isSelf ? 12 : 60,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSelf) ...[
            AvatarWidget(name: message.senderName, size: 32),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showActions(context),
              child: Column(
                crossAxisAlignment:
                    isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isSelf)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text(
                        message.senderName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppGlassColors.inkMuted,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isSelf ? 16 : 4),
                        bottomRight: Radius.circular(isSelf ? 4 : 16),
                      ),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.mediaUrl != null && !isDeleted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 220),
                                child: AspectRatio(
                                  aspectRatio: 11 / 8,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ExcludeSemantics(
                                        child: Image.network(
                                          message.mediaUrl!,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (_, child, progress) {
                                            if (progress == null) return child;
                                            final total =
                                                progress.expectedTotalBytes;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: total == null
                                                    ? null
                                                    : progress
                                                            .cumulativeBytesLoaded /
                                                        total,
                                                color: AppGlassColors.aqua,
                                              ),
                                            );
                                          },
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: AppGlassColors.inkMuted,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label:
                                            'Open photo from ${message.senderName}',
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            key: Key(
                                              'chat-image-${message.id}',
                                            ),
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      ImageViewerScreen(
                                                    imageUrl: message.mediaUrl!,
                                                    title:
                                                        'Photo from ${message.senderName}',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Text(
                          isDeleted
                              ? 'This message was deleted'
                              : message.text ?? '',
                          style: TextStyle(
                            color: isDeleted
                                ? AppGlassColors.inkMuted
                                : AppGlassColors.ink,
                            fontSize: isDeleted ? 13 : 15,
                            fontWeight:
                                isDeleted ? FontWeight.w500 : FontWeight.w600,
                            fontStyle:
                                isDeleted ? FontStyle.italic : FontStyle.normal,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDeleted &&
                      currentUserId != null &&
                      onToggleReaction != null)
                    MessageReactionBar(
                      reactions: message.reactions,
                      currentUserId: currentUserId!,
                      onReactionTap: (reaction) =>
                          showMessageReactionUsersSheet(
                            context,
                            reactions: message.reactions,
                            initialReaction: reaction,
                            users: users,
                          ),
                      onAddReaction: () => _showReactionPicker(context),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppUtils.formatTime(message.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppGlassColors.inkMuted,
                        ),
                      ),
                      if (message.editedAt != null && !isDeleted) ...[
                        const SizedBox(width: 4),
                        const Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: AppGlassColors.inkMuted,
                          ),
                        ),
                      ],
                      if (isSelf && !isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.readBy.length > 1
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message.readBy.length > 1
                              ? AppGlassColors.aqua
                              : AppGlassColors.inkMuted,
                        ),
                      ] else if (!isDeleted &&
                          (onReportMessage != null ||
                              onReportUser != null ||
                              onBlockUser != null)) ...[
                        const SizedBox(width: 4),
                        Semantics(
                          button: true,
                          label: 'Message actions for ${message.senderName}',
                          child: GestureDetector(
                            onTap: () => _showActions(context),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: AppGlassColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
