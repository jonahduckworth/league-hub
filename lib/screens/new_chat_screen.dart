import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/storage_service.dart';
import '../widgets/avatar_widget.dart';
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null || file!.bytes!.isEmpty) return;
    setState(() {
      _selectedImageBytes = file.bytes;
      _selectedImageName = file.name;
    });
  }

  Future<void> _createEventRoom(String orgId) async {
    if (_nameController.text.trim().isEmpty) {
      AppUtils.showInfoSnackBar(context, 'Please enter a room name.');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final currentUser = ref.read(currentUserProvider).valueOrNull;
      String? roomImageUrl;

      if (_selectedImageBytes != null) {
        final extension =
            (_selectedImageName ?? 'room.png').split('.').last.toLowerCase();
        roomImageUrl = await StorageService().uploadBytes(
          bytes: _selectedImageBytes!,
          path:
              'organizations/$orgId/chatRooms/${DateTime.now().microsecondsSinceEpoch}_${_selectedImageName ?? 'room.$extension'}',
          contentType: chatRoomImageContentType(extension),
        );
      }

      final roomId = await createEventChatRoom(
        currentUser: currentUser,
        orgId: orgId,
        roomName: _nameController.text,
        selectedLeagueId: _selectedLeagueId,
        roomIconName: _selectedImageBytes == null ? _selectedIconName : null,
        roomImageUrl: roomImageUrl,
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
    final currentUser = ref.read(currentUserProvider).valueOrNull;
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

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final orgId = ref.watch(organizationProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          icon: Icon(
              _step == _NewChatStep.choose ? Icons.close : Icons.arrow_back),
          onPressed: _isCreating ? null : _goBackOrClose,
        ),
      ),
      body: orgId == null
          ? const Center(child: Text('Organization unavailable.'))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (_step) {
                _NewChatStep.choose => _ChooseConversationType(
                    key: const ValueKey('choose'),
                    onEventRoom: () =>
                        setState(() => _step = _NewChatStep.eventRoom),
                    onDirectMessage: () =>
                        setState(() => _step = _NewChatStep.directMessage),
                  ),
                _NewChatStep.eventRoom => _EventRoomForm(
                    key: const ValueKey('event'),
                    nameController: _nameController,
                    selectedLeagueId: _selectedLeagueId,
                    selectedIconName: _selectedIconName,
                    selectedImageName: _selectedImageName,
                    isCreating: _isCreating,
                    inputDecoration: _inputDecoration,
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
                    onUserSelected: (user) => _openDirectMessage(orgId, user),
                  ),
              },
            ),
    );
  }
}

class _ChooseConversationType extends StatelessWidget {
  final VoidCallback onEventRoom;
  final VoidCallback onDirectMessage;

  const _ChooseConversationType({
    super.key,
    required this.onEventRoom,
    required this.onDirectMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'What are we starting?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Create an event room for a group or start a private conversation.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _ConversationTypeCard(
          icon: Icons.event_outlined,
          title: 'Event Room',
          subtitle: 'A shared room for tournaments, games, or planning.',
          color: AppColors.primary,
          onTap: onEventRoom,
        ),
        const SizedBox(height: 12),
        _ConversationTypeCard(
          icon: Icons.person_outline,
          title: 'Direct Message',
          subtitle: 'Message another member one-on-one.',
          color: AppColors.accent,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
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
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EventRoomForm extends ConsumerWidget {
  final TextEditingController nameController;
  final String? selectedLeagueId;
  final String selectedIconName;
  final String? selectedImageName;
  final bool isCreating;
  final InputDecoration Function(String hint) inputDecoration;
  final ValueChanged<String?> onLeagueSelected;
  final ValueChanged<String> onIconSelected;
  final VoidCallback onPickImage;
  final VoidCallback onCreate;

  const _EventRoomForm({
    super.key,
    required this.nameController,
    required this.selectedLeagueId,
    required this.selectedIconName,
    required this.selectedImageName,
    required this.isCreating,
    required this.inputDecoration,
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
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionLabel('Room Details'),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: inputDecoration('Spring Tournament').copyWith(
            labelText: 'Room Name',
            prefixIcon: const Icon(Icons.event_outlined),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionLabel('Room Look'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...chatRoomIconOptions.entries.map(
              (entry) => ChoiceChip(
                label: Icon(entry.value, size: 18),
                selected:
                    selectedImageName == null && selectedIconName == entry.key,
                onSelected:
                    isCreating ? null : (_) => onIconSelected(entry.key),
              ),
            ),
            ActionChip(
              avatar: Icon(
                selectedImageName == null
                    ? Icons.image_outlined
                    : Icons.check_circle,
                size: 18,
              ),
              label: Text(selectedImageName ?? 'Use Image'),
              onPressed: isCreating ? null : onPickImage,
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
              ChoiceChip(
                label: const Text('None'),
                selected: selectedLeagueId == null,
                onSelected: isCreating ? null : (_) => onLeagueSelected(null),
                selectedColor: AppColors.border,
              ),
              ...leagues.map(
                (league) => ChoiceChip(
                  label: Text(league.abbreviation),
                  selected: selectedLeagueId == league.id,
                  onSelected:
                      isCreating ? null : (_) => onLeagueSelected(league.id),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: chatLeagueChipLabelStyle(
                    selected: selectedLeagueId == league.id,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: isCreating ? null : onCreate,
          child: Text(isCreating ? 'Creating...' : 'Create Room'),
        ),
      ],
    );
  }
}

class _DirectMessagePicker extends ConsumerWidget {
  final ValueChanged<AppUser> onUserSelected;

  const _DirectMessagePicker({
    super.key,
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
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: otherUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final user = otherUsers[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: AvatarWidget(
              imageUrl: user.avatarUrl,
              name: user.displayName,
              size: 42,
            ),
            title: Text(
              user.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              user.roleLabel,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            trailing:
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () => onUserSelected(user),
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
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
