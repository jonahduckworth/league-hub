import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import 'avatar_widget.dart';

const chatRoomIconOptions = <String, IconData>{
  'event': Icons.event_outlined,
  'trophy': Icons.emoji_events_outlined,
  'group': Icons.groups_2_outlined,
  'schedule': Icons.schedule_outlined,
};

IconData iconForChatRoomIconName(String? iconName) {
  return chatRoomIconOptions[iconName] ?? Icons.event_outlined;
}

class ChatRoomAvatar extends StatelessWidget {
  final ChatRoom room;
  final String displayName;
  final AppUser? directMessagePeer;
  final double size;
  final double borderRadius;
  final double iconSize;
  final bool showImageBorder;

  const ChatRoomAvatar({
    super.key,
    required this.room,
    required this.displayName,
    this.directMessagePeer,
    this.size = 46,
    double? borderRadius,
    double? iconSize,
    this.showImageBorder = false,
  })  : borderRadius = borderRadius ?? 12,
        iconSize = iconSize ?? size * 0.48;

  @override
  Widget build(BuildContext context) {
    if (room.type == ChatRoomType.direct) {
      return AvatarWidget(
        imageUrl: directMessagePeer?.avatarUrl,
        name: displayName,
        size: size,
        backgroundColor: AppColors.accent,
      );
    }

    final imageUrl = room.roomImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: showImageBorder ? Border.all(color: AppColors.border) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, __) => _iconFallback(),
          errorWidget: (_, __, ___) => _iconFallback(),
        ),
      );
    }

    return _iconFallback();
  }

  Widget _iconFallback() {
    final isEvent = room.type == ChatRoomType.event;
    final fallbackIcon = isEvent
        ? iconForChatRoomIconName(room.roomIconName)
        : room.roomIconName != null
            ? iconForChatRoomIconName(room.roomIconName)
            : Icons.forum;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        fallbackIcon,
        color: AppColors.primary,
        size: iconSize,
      ),
    );
  }
}
