import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../models/app_user.dart';
import '../models/message_reaction.dart';
import 'app_glass.dart';
import 'avatar_widget.dart';

const _emojiFontFallback = [
  'Apple Color Emoji',
  'Noto Color Emoji',
  'Segoe UI Emoji',
];

String? get _emojiFontFamily => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.macOS => 'Apple Color Emoji',
  TargetPlatform.android => 'Noto Color Emoji',
  TargetPlatform.windows => 'Segoe UI Emoji',
  _ => null,
};

class MessageReactionPicker extends StatelessWidget {
  const MessageReactionPicker({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onSelected,
  });

  final Map<String, List<String>> reactions;
  final String currentUserId;
  final ValueChanged<MessageReaction> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        itemCount: MessageReaction.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final reaction = MessageReaction.values[index];
          final selected =
              reactions[reaction.key]?.contains(currentUserId) ?? false;
          return Semantics(
            button: true,
            selected: selected,
            excludeSemantics: true,
            label: selected
                ? 'Remove ${reaction.label} reaction'
                : 'React with ${reaction.label}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('reaction-picker-${reaction.key}'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(reaction),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedContainer(
                      duration: AppMotion.accessible(context, AppMotion.fast),
                      curve: AppMotion.enter,
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppGlassColors.aqua.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: selected
                              ? AppGlassColors.aqua.withValues(alpha: 0.55)
                              : AppGlassColors.border,
                        ),
                      ),
                      child: Text(
                        reaction.emoji,
                        style: TextStyle(
                          fontSize: 21,
                          fontFamily: _emojiFontFamily,
                          fontFamilyFallback: _emojiFontFallback,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MessageReactionBar extends StatelessWidget {
  const MessageReactionBar({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
    required this.onAddReaction,
  });

  final Map<String, List<String>> reactions;
  final String currentUserId;
  final ValueChanged<MessageReaction> onReactionTap;
  final VoidCallback onAddReaction;

  @override
  Widget build(BuildContext context) {
    final visible = MessageReaction.values
        .where((reaction) => reactions[reaction.key]?.isNotEmpty ?? false)
        .toList();

    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reaction in visible) ...[
              _ReactionChip(
                reaction: reaction,
                userIds: reactions[reaction.key]!,
                currentUserId: currentUserId,
                onTap: () => onReactionTap(reaction),
              ),
              const SizedBox(width: 4),
            ],
            _AddReactionButton(
              showLabel: visible.isEmpty,
              onTap: onAddReaction,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.userIds,
    required this.currentUserId,
    required this.onTap,
  });

  final MessageReaction reaction;
  final List<String> userIds;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = userIds.contains(currentUserId);
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label:
          '${reaction.label} reaction from ${userIds.length} ${userIds.length == 1 ? 'person' : 'people'}. View who reacted.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('reaction-chip-target-${reaction.key}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            alignment: Alignment.center,
            child: Container(
              key: ValueKey('reaction-chip-${reaction.key}'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? AppGlassColors.aqua.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: selected
                      ? AppGlassColors.aqua.withValues(alpha: 0.45)
                      : AppGlassColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction.emoji,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: _emojiFontFamily,
                      fontFamilyFallback: _emojiFontFallback,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${userIds.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppGlassColors.aqua
                          : AppGlassColors.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({required this.showLabel, required this.onTap});

  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Add reaction',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('add-reaction-target'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            alignment: Alignment.center,
            child: Container(
              key: const ValueKey('add-reaction-button'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppGlassColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_reaction_outlined,
                    size: 17,
                    color: AppGlassColors.inkSecondary,
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 5),
                    const Text(
                      'React',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppGlassColors.inkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMessageReactionUsersSheet(
  BuildContext context, {
  required Map<String, List<String>> reactions,
  required MessageReaction initialReaction,
  required List<AppUser> users,
}) {
  final visible = <String, List<String>>{
    for (final reaction in MessageReaction.values)
      if (reactions[reaction.key]?.isNotEmpty ?? false)
        reaction.key: reactions[reaction.key]!,
  };
  if (visible.isEmpty) return Future.value();
  final selected = visible.containsKey(initialReaction.key)
      ? initialReaction
      : MessageReaction.fromKey(visible.keys.first)!;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.overlayStyle(context),
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    builder: (_) => _ReactionUsersSheet(
      reactions: visible,
      initialReaction: selected,
      users: users,
    ),
  );
}

class _ReactionUsersSheet extends StatefulWidget {
  const _ReactionUsersSheet({
    required this.reactions,
    required this.initialReaction,
    required this.users,
  });

  final Map<String, List<String>> reactions;
  final MessageReaction initialReaction;
  final List<AppUser> users;

  @override
  State<_ReactionUsersSheet> createState() => _ReactionUsersSheetState();
}

class _ReactionUsersSheetState extends State<_ReactionUsersSheet> {
  late MessageReaction _selectedReaction;

  @override
  void initState() {
    super.initState();
    _selectedReaction = widget.initialReaction;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final total = widget.reactions.values.fold<int>(
      0,
      (sum, userIds) => sum + userIds.length,
    );
    final userById = {for (final user in widget.users) user.id: user};
    final userIds =
        List<String>.from(widget.reactions[_selectedReaction.key] ?? const [])
          ..sort(
            (a, b) => (userById[a]?.displayName ?? '').compareTo(
              userById[b]?.displayName ?? '',
            ),
          );
    final estimatedHeight = 142.0 + math.min(userIds.length, 7) * 58.0;
    final height = math.min(
      media.size.height * 0.72,
      math.max(300.0, estimatedHeight + media.padding.bottom),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: AppGlassSurface(
          height: height,
          radius: 28,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppGlassColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Reactions ($total)',
                    style: const TextStyle(
                      color: AppGlassColors.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: widget.reactions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final entry = widget.reactions.entries.elementAt(index);
                    final reaction = MessageReaction.fromKey(entry.key)!;
                    final selected = reaction == _selectedReaction;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label:
                          '${reaction.label}, ${entry.value.length} ${entry.value.length == 1 ? 'reaction' : 'reactions'}',
                      child: ChoiceChip(
                        key: ValueKey('reaction-filter-${reaction.key}'),
                        selected: selected,
                        showCheckmark: false,
                        avatar: Text(
                          reaction.emoji,
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: _emojiFontFamily,
                            fontFamilyFallback: _emojiFontFallback,
                          ),
                        ),
                        label: Text('${entry.value.length}'),
                        labelStyle: TextStyle(
                          color: selected
                              ? AppGlassColors.pageMid
                              : AppGlassColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                        selectedColor: AppGlassColors.aqua,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: selected
                              ? AppGlassColors.aqua
                              : AppGlassColors.border,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedReaction = reaction),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: AppGlassColors.border),
              Expanded(
                child: ListView.builder(
                  key: ValueKey('reaction-user-list-${_selectedReaction.key}'),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: userIds.length,
                  itemBuilder: (context, index) {
                    final userId = userIds[index];
                    final user = userById[userId];
                    return Semantics(
                      label:
                          '${user?.displayName ?? 'Unknown member'} reacted with ${_selectedReaction.label}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            AvatarWidget(
                              name: user?.displayName ?? 'Unknown member',
                              imageUrl: user?.avatarUrl,
                              size: 38,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                user?.displayName ?? 'Unknown member',
                                style: const TextStyle(
                                  color: AppGlassColors.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _selectedReaction.emoji,
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: _emojiFontFamily,
                                fontFamilyFallback: _emojiFontFallback,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
