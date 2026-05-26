import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/message.dart';
import 'app_glass.dart';
import 'avatar_widget.dart';

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isSelf;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isSelf,
    this.onEdit,
    this.onDelete,
  });

  void _showActions(BuildContext context) {
    if (!isSelf || message.deleted) return;
    showModalBottomSheet(
      context: context,
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
                              child: Image.network(
                                message.mediaUrl!,
                                width: 220,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 220,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: AppGlassColors.inkMuted,
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
