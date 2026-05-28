import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/league_branding.dart';
import '../core/picked_file.dart';
import '../core/scope_defaults.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_room_avatar.dart';
import '../widgets/glass_form_widgets.dart';
import 'chat_list_screen.dart';

enum _NewChatStep { choose, eventRoom, directMessage }

enum _EventRoomScope { league, hub, team }

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _nameController = TextEditingController();

  _NewChatStep _step = _NewChatStep.choose;
  _EventRoomScope _eventRoomScope = _EventRoomScope.league;
  String? _selectedLeagueId;
  String? _selectedHubId;
  String? _selectedTeamId;
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
    if (_selectedLeagueId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a league.');
      return;
    }
    if ((_eventRoomScope == _EventRoomScope.hub ||
            _eventRoomScope == _EventRoomScope.team) &&
        _selectedHubId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a hub.');
      return;
    }
    if (_eventRoomScope == _EventRoomScope.team && _selectedTeamId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a team.');
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
        leagueId: _selectedLeagueId!,
        hubId:
            _eventRoomScope == _EventRoomScope.league ? null : _selectedHubId,
        teamId:
            _eventRoomScope == _EventRoomScope.team ? _selectedTeamId : null,
      );

      final roomId = await createEventChatRoom(
        currentUser: currentUser,
        orgId: orgId,
        roomName: _nameController.text,
        selectedLeagueId: _selectedLeagueId!,
        selectedHubId:
            _eventRoomScope == _EventRoomScope.league ? null : _selectedHubId,
        selectedTeamId:
            _eventRoomScope == _EventRoomScope.team ? _selectedTeamId : null,
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
    final leagues = manageableLeaguesForUser(
      currentUser,
      ref.watch(leaguesProvider).valueOrNull ?? [],
    );
    final defaultLeagueId = singleManageableLeagueId(currentUser, leagues);
    if (_selectedLeagueId == null && defaultLeagueId != null) {
      _selectedLeagueId = defaultLeagueId;
    } else if (_selectedLeagueId != null &&
        leagues.isNotEmpty &&
        !leagues.any((league) => league.id == _selectedLeagueId)) {
      _selectedLeagueId = null;
      _selectedHubId = null;
      _selectedTeamId = null;
      _eventRoomScope = _EventRoomScope.league;
    }
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final topContentPadding = appShellTopPadding(context);
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
                    selectedScope: _eventRoomScope,
                    selectedLeagueId: _selectedLeagueId,
                    selectedHubId: _selectedHubId,
                    selectedTeamId: _selectedTeamId,
                    selectedIconName: _selectedIconName,
                    selectedImageName: _selectedImageName,
                    isCreating: _isCreating,
                    onScopeSelected: (scope) => setState(() {
                      _eventRoomScope = scope;
                      if (scope == _EventRoomScope.league) {
                        _selectedHubId = null;
                        _selectedTeamId = null;
                      } else if (scope == _EventRoomScope.hub) {
                        _selectedTeamId = null;
                      }
                    }),
                    onLeagueSelected: (id) => setState(() {
                      _selectedLeagueId = id;
                      _selectedHubId = null;
                      _selectedTeamId = null;
                      _eventRoomScope = _EventRoomScope.league;
                    }),
                    onHubSelected: (id) => setState(() {
                      _selectedHubId = id;
                      _selectedTeamId = null;
                    }),
                    onTeamSelected: (id) =>
                        setState(() => _selectedTeamId = id),
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
  required String leagueId,
  String? hubId,
  String? teamId,
}) {
  final matchingUsers = users.where((user) {
    if (!user.isActive) return false;
    if (teamId != null) return user.teamIds.contains(teamId);
    if (hubId != null) return user.hubIds.contains(hubId);
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
  final _EventRoomScope selectedScope;
  final String? selectedLeagueId;
  final String? selectedHubId;
  final String? selectedTeamId;
  final String selectedIconName;
  final String? selectedImageName;
  final bool isCreating;
  final ValueChanged<_EventRoomScope> onScopeSelected;
  final ValueChanged<String?> onLeagueSelected;
  final ValueChanged<String?> onHubSelected;
  final ValueChanged<String?> onTeamSelected;
  final ValueChanged<String> onIconSelected;
  final VoidCallback onPickImage;
  final VoidCallback onCreate;

  const _EventRoomForm({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.nameController,
    required this.selectedScope,
    required this.selectedLeagueId,
    required this.selectedHubId,
    required this.selectedTeamId,
    required this.selectedIconName,
    required this.selectedImageName,
    required this.isCreating,
    required this.onScopeSelected,
    required this.onLeagueSelected,
    required this.onHubSelected,
    required this.onTeamSelected,
    required this.onIconSelected,
    required this.onPickImage,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues =
        manageableLeaguesForUser(currentUser, leaguesAsync.valueOrNull ?? []);
    final hubsAsync = selectedLeagueId == null
        ? const AsyncValue<List<Hub>>.data([])
        : ref.watch(hubsProvider(selectedLeagueId!));
    final hubs = hubsAsync.valueOrNull ?? [];
    final teamsAsync = selectedLeagueId == null || selectedHubId == null
        ? const AsyncValue<List<Team>>.data([])
        : ref.watch(
            teamsProvider((leagueId: selectedLeagueId!, hubId: selectedHubId!)),
          );
    final teams = teamsAsync.valueOrNull ?? [];

    if ((selectedScope == _EventRoomScope.hub ||
            selectedScope == _EventRoomScope.team) &&
        selectedHubId == null &&
        hubs.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onHubSelected(hubs.first.id);
      });
    }
    if (selectedScope == _EventRoomScope.team &&
        selectedTeamId == null &&
        teams.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onTeamSelected(teams.first.id);
      });
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      children: [
        const GlassFormSectionLabel('Room Details'),
        const SizedBox(height: 8),
        GlassTextFormField(
          controller: nameController,
          labelText: 'Room Name',
          hintText: 'Spring Tournament',
          leadingIcon: Icons.event_outlined,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 18),
        const GlassFormSectionLabel('Room Look'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...chatRoomIconOptions.entries.map(
              (entry) => GlassIconChoice(
                icon: entry.value,
                selected:
                    selectedImageName == null && selectedIconName == entry.key,
                onTap: isCreating ? null : () => onIconSelected(entry.key),
              ),
            ),
            GlassChoiceChip(
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
          const GlassFormSectionLabel('League'),
          const SizedBox(height: 8),
          GlassDropdownField<String>(
            value: selectedLeagueId,
            hintText: 'Select league',
            items: leagues
                .map(
                  (league) => DropdownMenuItem<String>(
                    value: league.id,
                    child: Text(league.name),
                  ),
                )
                .toList(),
            onChanged: isCreating ? null : onLeagueSelected,
          ),
        ],
        if (selectedLeagueId != null) ...[
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Room Scope'),
          const SizedBox(height: 8),
          GlassScopeSelector<_EventRoomScope>(
            selected: selectedScope,
            onChanged: isCreating ? null : onScopeSelected,
            options: const [
              GlassChoiceOption(
                value: _EventRoomScope.league,
                label: 'League',
                icon: Icons.emoji_events_outlined,
              ),
              GlassChoiceOption(
                value: _EventRoomScope.hub,
                label: 'Hub',
                icon: Icons.location_on_outlined,
              ),
              GlassChoiceOption(
                value: _EventRoomScope.team,
                label: 'Team',
                icon: Icons.groups_2_outlined,
              ),
            ],
          ),
        ],
        if ((selectedScope == _EventRoomScope.hub ||
                selectedScope == _EventRoomScope.team) &&
            selectedLeagueId != null) ...[
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Hub'),
          const SizedBox(height: 8),
          GlassDropdownField<String>(
            value: selectedHubId,
            hintText: 'Select hub',
            items: hubs
                .map(
                  (hub) => DropdownMenuItem<String>(
                    value: hub.id,
                    child: Text(hub.name),
                  ),
                )
                .toList(),
            onChanged: isCreating ? null : onHubSelected,
          ),
        ],
        if (selectedScope == _EventRoomScope.team && selectedHubId != null) ...[
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Team'),
          const SizedBox(height: 8),
          GlassDropdownField<String>(
            value: selectedTeamId,
            hintText: 'Select team',
            items: teams
                .map(
                  (team) => DropdownMenuItem<String>(
                    value: team.id,
                    child: Text(team.name),
                  ),
                )
                .toList(),
            onChanged: isCreating ? null : onTeamSelected,
          ),
        ],
        const SizedBox(height: 24),
        GlassSubmitButton(
          onTap: isCreating ? null : onCreate,
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
