import 'package:flutter/material.dart';

import '../models/app_user.dart';
import 'app_glass.dart';
import 'avatar_widget.dart';

class ProfileSummaryCard extends StatelessWidget {
  final AppUser user;
  final bool showEmail;
  final IconData actionIcon;
  final String actionTooltip;
  final VoidCallback? onActionTap;
  final VoidCallback? onTap;
  final bool compact;
  final Widget? background;
  final double? minHeight;

  const ProfileSummaryCard({
    super.key,
    required this.user,
    this.showEmail = true,
    this.actionIcon = Icons.chevron_right,
    this.actionTooltip = 'Open profile',
    this.onActionTap,
    this.onTap,
    this.compact = false,
    this.background,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = compact ? 52.0 : 60.0;
    final padding = compact ? 16.0 : 20.0;
    final titleSize = compact ? 16.0 : 18.0;
    final detailSize = compact ? 13.0 : 14.0;

    final content = Row(
      children: [
        AvatarWidget(
          imageUrl: user.avatarUrl,
          name: user.displayName,
          size: avatarSize,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
        ),
        SizedBox(width: compact ? 14 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (user.title != null) ...[
                SizedBox(height: compact ? 3 : 5),
                Text(
                  user.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: detailSize,
                    color: AppGlassColors.aqua,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (showEmail) ...[
                SizedBox(height: compact ? 3 : 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
        Tooltip(
          message: actionTooltip,
          child: IconButton(
            icon: Icon(actionIcon, color: Colors.white),
            onPressed: onActionTap ?? onTap,
          ),
        ),
      ],
    );

    final card = AppGlassSurface(
      padding: background == null ? EdgeInsets.all(padding) : EdgeInsets.zero,
      radius: compact ? 21 : 24,
      onTap: onTap,
      child: background == null
          ? content
          : Stack(
              children: [
                Positioned.fill(child: background!),
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight ?? 0),
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: content,
                  ),
                ),
              ],
            ),
    );

    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: actionTooltip,
      child: card,
    );
  }
}
