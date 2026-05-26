import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/league_branding.dart';
import '../core/picked_file.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_room_avatar.dart';
import 'chat_list_screen.dart';

enum _NewChatStep { choose, eventRoom, directMessage }

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _nameController = TextEditingController();

  _NewChatStep _step = _NewChatStep.choose;
  String? _selectedLeagueId;
  String _selectedIconName = 'event';
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _title {
    switch (_step) {
      case _NewChatStep.choose:
        return 'New Conversation';
      case _NewChatStep.eventRoom:
        return 'New Event Room';
      case _NewChatStep.directMessage:
        return 'New Direct Message';
    }
  }

  void _goBackOrClose() {
    if (_step == _NewChatStep.choose) {
      context.pop();
      return;
    }
    setState(() => _step = _NewChatStep.choose);
  }

  Future<void> _pickRoomImage() async {
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
    setState(() {
      _selectedImageBytes = picked.bytes;
      _selectedImageName = picked.name;
    });
  }

  Future<void> _createEventRoom(String orgId) async {
    if (_nameController.text.trim().isEmpty) {
      AppUtils.showInfoSnackBar(context, 'Please enter a room name.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        if (mounted) {
          AppUtils.showErrorSnackBar(context, 'Please sign in again.');
          setState(() => _isCreating = false);
        }
        return;
      }
      if (!const PermissionService().canCreateChatRoom(currentUser)) {
        if (mounted) {
          AppUtils.showErrorSnackBar(
            context,
            'You do not have permission to create chat rooms',
          );
          setState(() => _isCreating = false);
        }
        return;
      }

      final orgUsers = ref.read(orgUsersProvider).valueOrNull ?? [];
      final participantIds = eventRoomParticipantIds(
        creator: currentUser,
        users: orgUsers,
        leagueId: _selectedLeagueId,
      );

      final roomId = await createEventChatRoom(
        currentUser: currentUser,
        orgId: orgId,
        roomName: _nameController.text,
        selectedLeagueId: _selectedLeagueId,
        roomIconName: _selectedIconName,
        participantIds: participantIds,
        createRoom: ref.read(authorizedFirestoreServiceProvider).createChatRoom,
        onPermissionDenied: () {
          if (mounted) {
            AppUtils.showErrorSnackBar(
              context,
              'You do not have permission to create chat rooms',
            );
          }
        },
      );

      if (roomId != null && _selectedImageBytes != null) {
        try {
          final extension =
              (_selectedImageName ?? 'room.png').split('.').last.toLowerCase();
          final roomImageUrl = await StorageService().uploadBytes(
            bytes: _selectedImageBytes!,
            path:
                'orgs/$orgId/chat/$roomId/room-images/${currentUser.id}/roomImage_${DateTime.now().microsecondsSinceEpoch}_${_selectedImageName ?? 'room.$extension'}',
            contentType: chatRoomImageContentType(extension),
          );
          await ref
              .read(authorizedFirestoreServiceProvider)
              .updateChatRoomFields(
            currentUser,
            orgId,
            roomId,
            {
              'roomIconName': null,
              'roomImageUrl': roomImageUrl,
            },
          );
        } catch (_) {
          if (mounted) {
            AppUtils.showErrorSnackBar(
              context,
              'Room created, but the image upload failed. You can add it from Chat Info.',
            );
          }
        }
      }

      if (roomId != null && mounted) {
        context.pushReplacement('/chat/$roomId');
      } else if (mounted) {
        setState(() => _isCreating = false);
      }
    } catch (_) {
      if (mounted) {
        AppUtils.showErrorSnackBar(
          context,
          'Could not create the chat room. Please try again.',
        );
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _openDirectMessage(String orgId, AppUser user) async {
    final currentUser = await ref.read(currentUserProvider.future);
    final roomId = await openDirectMessageRoom(
      currentUser: currentUser,
      otherUser: user,
      orgId: orgId,
      getOrCreateDMRoom: ref.read(firestoreServiceProvider).getOrCreateDMRoom,
    );
    if (roomId != null && mounted) {
      context.pushReplacement('/chat/$roomId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final orgId =
        ref.watch(organizationProvider).valueOrNull?.id ?? currentUser?.orgId;
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final topContentPadding = appShellTopPadding(context, extra: 12);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);
    final headerIcon = switch (_step) {
      _NewChatStep.choose => Icons.forum_outlined,
      _NewChatStep.eventRoom => Icons.event_outlined,
      _NewChatStep.directMessage => Icons.person_outline,
    };

    return AppShellScaffold(
      header: AppShellHeader(
        title: _title,
        leadingIcon: headerIcon,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: 'League Hub',
        showBackButton: true,
        backIcon: _step == _NewChatStep.choose
            ? Icons.close
            : Icons.arrow_back_ios_new,
        onBack: _isCreating ? () {} : _goBackOrClose,
      ),
      child: orgId == null
          ? const Center(
              child: Text(
                'Organization unavailable.',
                style: TextStyle(color: AppGlassColors.inkSecondary),
              ),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: switch (_step) {
                _NewChatStep.choose => _ChooseConversationType(
                    key: const ValueKey('choose'),
                    topPadding: topContentPadding,
                    bottomPadding: bottomContentPadding,
                    onEventRoom: () =>
                        setState(() => _step = _NewChatStep.eventRoom),
                    onDirectMessage: () =>
                        setState(() => _step = _NewChatStep.directMessage),
                  ),
                _NewChatStep.eventRoom => _EventRoomForm(
                    key: const ValueKey('event'),
                    topPadding: topContentPadding,
                    bottomPadding: bottomContentPadding,
                    nameController: _nameController,
                    selectedLeagueId: _selectedLeagueId,
                    selectedIconName: _selectedIconName,
                    selectedImageName: _selectedImageName,
                    isCreating: _isCreating,
                    onLeagueSelected: (id) =>
                        setState(() => _selectedLeagueId = id),
                    onIconSelected: (name) => setState(() {
                      _selectedIconName = name;
                      _selectedImageBytes = null;
                      _selectedImageName = null;
                    }),
                    onPickImage: _pickRoomImage,
                    onCreate: () => _createEventRoom(orgId),
                  ),
                _NewChatStep.directMessage => _DirectMessagePicker(
                    key: const ValueKey('dm'),
                    topPadding: topContentPadding,
                    bottomPadding: bottomContentPadding,
                    onUserSelected: (user) => _openDirectMessage(orgId, user),
                  ),
              },
            ),
    );
  }
}

List<String> eventRoomParticipantIds({
  required AppUser creator,
  required List<AppUser> users,
  required String? leagueId,
}) {
  final matchingUsers = users.where((user) {
    if (!user.isActive) return false;
    if (leagueId == null) return user.orgId == creator.orgId;
    return user.leagueIds.contains(leagueId);
  });
  return {
    creator.id,
    ...matchingUsers.map((user) => user.id),
  }.toList();
}

class _ChooseConversationType extends StatelessWidget {
  final double topPadding;
  final double bottomPadding;
  final VoidCallback onEventRoom;
  final VoidCallback onDirectMessage;

  const _ChooseConversationType({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.onEventRoom,
    required this.onDirectMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      children: [
        const Text(
          'What are we starting?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppGlassColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create an event room for a group or start a private conversation.',
          style: TextStyle(
            fontSize: 14,
            color: AppGlassColors.inkSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        _ConversationTypeCard(
          icon: Icons.event_outlined,
          title: 'Event Room',
          subtitle: 'A shared room for tournaments, games, or planning.',
          color: AppGlassColors.gold,
          onTap: onEventRoom,
        ),
        const SizedBox(height: 12),
        _ConversationTypeCard(
          icon: Icons.person_outline,
          title: 'Direct Message',
          subtitle: 'Message another member one-on-one.',
          color: AppGlassColors.aqua,
          onTap: onDirectMessage,
        ),
      ],
    );
  }
}

class _ConversationTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ConversationTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppGlassColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppGlassColors.inkSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppGlassColors.inkMuted),
        ],
      ),
    );
  }
}

class _EventRoomForm extends ConsumerWidget {
  final double topPadding;
  final double bottomPadding;
  final TextEditingController nameController;
  final String? selectedLeagueId;
  final String selectedIconName;
  final String? selectedImageName;
  final bool isCreating;
  final ValueChanged<String?> onLeagueSelected;
  final ValueChanged<String> onIconSelected;
  final VoidCallback onPickImage;
  final VoidCallback onCreate;

  const _EventRoomForm({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.nameController,
    required this.selectedLeagueId,
    required this.selectedIconName,
    required this.selectedImageName,
    required this.isCreating,
    required this.onLeagueSelected,
    required this.onIconSelected,
    required this.onPickImage,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final leagues = leaguesAsync.valueOrNull ?? [];

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      children: [
        const _SectionLabel('Room Details'),
        const SizedBox(height: 8),
        _GlassTextField(
          controller: nameController,
          labelText: 'Room Name',
          hintText: 'Spring Tournament',
          leadingIcon: Icons.event_outlined,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Room Look'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...chatRoomIconOptions.entries.map(
              (entry) => _GlassIconChoice(
                icon: entry.value,
                selected:
                    selectedImageName == null && selectedIconName == entry.key,
                onTap: isCreating ? null : () => onIconSelected(entry.key),
              ),
            ),
            _GlassTextChoice(
              icon: selectedImageName == null
                  ? Icons.image_outlined
                  : Icons.check_circle,
              label: selectedImageName ?? 'Use Image',
              selected: selectedImageName != null,
              onTap: isCreating ? null : onPickImage,
            ),
          ],
        ),
        if (shouldShowEventRoomLeagueSelector(leaguesAsync)) ...[
          const SizedBox(height: 18),
          const _SectionLabel('League Optional'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassTextChoice(
                label: 'None',
                icon: Icons.check,
                selected: selectedLeagueId == null,
                onTap: isCreating ? null : () => onLeagueSelected(null),
              ),
              ...leagues.map(
                (league) => _GlassTextChoice(
                  label: league.abbreviation,
                  selected: selectedLeagueId == league.id,
                  onTap: isCreating ? null : () => onLeagueSelected(league.id),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        _GlassSubmitButton(
          onPressed: isCreating ? null : onCreate,
          label: isCreating ? 'Creating...' : 'Create Room',
        ),
      ],
    );
  }
}

class _DirectMessagePicker extends ConsumerWidget {
  final double topPadding;
  final double bottomPadding;
  final ValueChanged<AppUser> onUserSelected;

  const _DirectMessagePicker({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final users = ref.watch(orgUsersProvider).valueOrNull ?? [];
    final otherUsers = visibleDirectMessageUsers(users, currentUser);

    if (otherUsers.isEmpty) {
      return const Center(
        child: Text(
          'No other members in your organization.',
          style: TextStyle(fontSize: 14, color: AppGlassColors.inkMuted),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      itemCount: otherUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final user = otherUsers[index];
        return AppGlassSurface(
          radius: 22,
          padding: EdgeInsets.zero,
          onTap: () => onUserSelected(user),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            leading: AvatarWidget(
              imageUrl: user.avatarUrl,
              name: user.displayName,
              size: 48,
              backgroundColor:
                  AppUtils.roleColor(user.role).withValues(alpha: 0.22),
            ),
            title: Text(
              user.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppGlassColors.ink,
              ),
            ),
            subtitle: Text(
              user.roleLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppGlassColors.inkSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppGlassColors.inkMuted),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppGlassColors.inkMuted,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? labelText;
  final String hintText;
  final IconData? leadingIcon;
  final TextInputAction? textInputAction;

  const _GlassTextField({
    required this.controller,
    required this.hintText,
    this.labelText,
    this.leadingIcon,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
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
          textInputAction: textInputAction,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            labelText: labelText,
            hintText: hintText,
            prefixIcon: leadingIcon == null
                ? null
                : Icon(
                    leadingIcon,
                    color: AppGlassColors.inkSecondary,
                    size: 20,
                  ),
            hintStyle: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
            labelStyle: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontWeight: FontWeight.w700,
            ),
            filled: false,
            fillColor: Colors.transparent,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

class _GlassIconChoice extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _GlassIconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      width: 60,
      height: 50,
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppGlassColors.aqua.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppGlassColors.aqua.withValues(alpha: 0.34)
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

class _GlassTextChoice extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const _GlassTextChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      height: 50,
      padding: EdgeInsets.zero,
      radius: 18,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? AppGlassColors.aqua.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppGlassColors.aqua.withValues(alpha: 0.34)
                : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? AppGlassColors.aqua
                      : AppGlassColors.inkSecondary,
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 156),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        selected ? AppGlassColors.ink : AppGlassColors.inkMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _GlassSubmitButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      height: 58,
      padding: EdgeInsets.zero,
      radius: 22,
      onTap: onPressed,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: onPressed == null
                ? AppGlassColors.inkMuted
                : AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
