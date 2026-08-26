import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/league_branding.dart';
import '../core/picked_file.dart';
import '../core/scope_defaults.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_motion.dart';
import '../core/design_system.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_room_avatar.dart';
import '../widgets/entity_avatar.dart';
import '../widgets/glass_form_widgets.dart';
import 'chat_list_screen.dart';

enum _NewChatStep { choose, groupRoom, eventRoom, directMessage }

enum _SharedRoomScope { league, hub, team }

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _nameController = TextEditingController();

  _NewChatStep _step = _NewChatStep.choose;
  _SharedRoomScope _sharedRoomScope = _SharedRoomScope.league;
  String? _selectedLeagueId;
  String? _selectedHubId;
  String? _selectedTeamId;
  final Set<String> _selectedTeamIds = {};
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
      case _NewChatStep.groupRoom:
        return 'New Group Room';
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

  ChatRoomPurpose get _roomPurpose => _step == _NewChatStep.groupRoom
      ? ChatRoomPurpose.group
      : ChatRoomPurpose.event;

  void _openSharedRoom(ChatRoomPurpose purpose) {
    setState(() {
      _step = purpose == ChatRoomPurpose.group
          ? _NewChatStep.groupRoom
          : _NewChatStep.eventRoom;
      _selectedIconName = purpose == ChatRoomPurpose.group ? 'group' : 'event';
      _selectedImageBytes = null;
      _selectedImageName = null;
      _selectedTeamIds.clear();
    });
  }

  Future<void> _createSharedRoom(String orgId) async {
    if (_nameController.text.trim().isEmpty) {
      AppUtils.showInfoSnackBar(context, 'Please enter a room name.');
      return;
    }
    if (_selectedLeagueId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a league.');
      return;
    }
    final usesMultiTeamAudience = _roomPurpose == ChatRoomPurpose.event &&
        _sharedRoomScope == _SharedRoomScope.team;
    if ((_sharedRoomScope == _SharedRoomScope.hub ||
            (_sharedRoomScope == _SharedRoomScope.team &&
                !usesMultiTeamAudience)) &&
        _selectedHubId == null) {
      AppUtils.showInfoSnackBar(context, 'Please select a hub.');
      return;
    }
    if (_sharedRoomScope == _SharedRoomScope.team &&
        (usesMultiTeamAudience
            ? _selectedTeamIds.isEmpty
            : _selectedTeamId == null)) {
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

      var selectedMultiTeams = const <Team>[];
      if (usesMultiTeamAudience) {
        final organizationTeams = await ref.read(
          organizationTeamsProvider.future,
        );
        selectedMultiTeams = organizationTeams
            .where(
              (team) =>
                  team.leagueId == _selectedLeagueId &&
                  _selectedTeamIds.contains(team.id),
            )
            .toList();
        if (selectedMultiTeams.length != _selectedTeamIds.length) {
          if (mounted) {
            AppUtils.showErrorSnackBar(
              context,
              'Some selected teams are no longer available. Please review the room scope.',
            );
            setState(() => _isCreating = false);
          }
          return;
        }
      }

      final selectedTeamIds =
          selectedMultiTeams.map((team) => team.id).toList();
      final selectedHubIds =
          selectedMultiTeams.map((team) => team.hubId).toSet().toList();
      final legacyTeam =
          selectedMultiTeams.isEmpty ? null : selectedMultiTeams.first;

      final orgUsers = ref.read(orgUsersProvider).valueOrNull ?? [];
      final participantIds = sharedRoomParticipantIds(
        creator: currentUser,
        users: orgUsers,
        leagueId: _selectedLeagueId!,
        hubId:
            _sharedRoomScope == _SharedRoomScope.league ? null : _selectedHubId,
        teamId:
            _sharedRoomScope == _SharedRoomScope.team ? _selectedTeamId : null,
        teamIds: selectedTeamIds,
      );

      final roomId = await createSharedChatRoom(
        currentUser: currentUser,
        orgId: orgId,
        roomName: _nameController.text,
        roomPurpose: _roomPurpose,
        selectedLeagueId: _selectedLeagueId!,
        selectedHubId: usesMultiTeamAudience
            ? legacyTeam?.hubId
            : _sharedRoomScope == _SharedRoomScope.league
                ? null
                : _selectedHubId,
        selectedTeamId:
            usesMultiTeamAudience ? legacyTeam?.id : _selectedTeamId,
        selectedHubIds: selectedHubIds,
        selectedTeamIds: selectedTeamIds,
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
              .updateChatRoomFields(currentUser, orgId, roomId, {
            'roomIconName': null,
            'roomImageUrl': roomImageUrl,
          });
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
      getOrCreateDMRoom: (_, __, ___, ____, _____) => ref
          .read(authorizedFirestoreServiceProvider)
          .getOrCreateDirectMessage(currentUser!, user, orgId),
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
      _selectedTeamIds.clear();
      _sharedRoomScope = _SharedRoomScope.league;
    }
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);
    final headerIcon = switch (_step) {
      _NewChatStep.choose => Icons.forum_outlined,
      _NewChatStep.groupRoom => Icons.groups_2_outlined,
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
              duration: AppMotion.accessible(context, AppMotion.emphasized),
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: AppMotion.enter,
                  reverseCurve: AppMotion.exit,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.035, 0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: switch (_step) {
                _NewChatStep.choose => _ChooseConversationType(
                    key: const ValueKey('choose'),
                    topPadding: topContentPadding,
                    bottomPadding: bottomContentPadding,
                    onGroupRoom: () => _openSharedRoom(ChatRoomPurpose.group),
                    onEventRoom: () => _openSharedRoom(ChatRoomPurpose.event),
                    canCreateSharedRoom: currentUser != null &&
                        const PermissionService()
                            .canCreateChatRoom(currentUser),
                    onDirectMessage: () =>
                        setState(() => _step = _NewChatStep.directMessage),
                  ),
                _NewChatStep.groupRoom ||
                _NewChatStep.eventRoom =>
                  _SharedRoomForm(
                    key: ValueKey(_roomPurpose.name),
                    topPadding: topContentPadding,
                    bottomPadding: bottomContentPadding,
                    nameController: _nameController,
                    roomPurpose: _roomPurpose,
                    selectedScope: _sharedRoomScope,
                    selectedLeagueId: _selectedLeagueId,
                    selectedHubId: _selectedHubId,
                    selectedTeamId: _selectedTeamId,
                    selectedIconName: _selectedIconName,
                    selectedImageName: _selectedImageName,
                    isCreating: _isCreating,
                    onScopeSelected: (scope) => setState(() {
                      _sharedRoomScope = scope;
                      _selectedHubId = null;
                      _selectedTeamId = null;
                      _selectedTeamIds.clear();
                    }),
                    onLeagueSelected: (id) => setState(() {
                      _selectedLeagueId = id;
                      _selectedHubId = null;
                      _selectedTeamId = null;
                      _selectedTeamIds.clear();
                      _sharedRoomScope = _SharedRoomScope.league;
                    }),
                    onHubSelected: (id) => setState(() {
                      _selectedHubId = id;
                      _selectedTeamId = null;
                      _selectedTeamIds.clear();
                    }),
                    onTeamSelected: (id) =>
                        setState(() => _selectedTeamId = id),
                    selectedTeamIds: _selectedTeamIds,
                    onTeamSelectionChanged: (ids) => setState(() {
                      _selectedTeamIds
                        ..clear()
                        ..addAll(ids);
                    }),
                    onIconSelected: (name) => setState(() {
                      _selectedIconName = name;
                      _selectedImageBytes = null;
                      _selectedImageName = null;
                    }),
                    onPickImage: _pickRoomImage,
                    onCreate: () => _createSharedRoom(orgId),
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

List<String> sharedRoomParticipantIds({
  required AppUser creator,
  required List<AppUser> users,
  required String leagueId,
  String? hubId,
  String? teamId,
  List<String> teamIds = const [],
}) {
  final matchingUsers = users.where((user) {
    if (!user.isActive) return false;
    if (teamIds.isNotEmpty) {
      return user.teamIds.any(teamIds.contains);
    }
    if (teamId != null) return user.teamIds.contains(teamId);
    if (hubId != null) return user.hubIds.contains(hubId);
    return user.leagueIds.contains(leagueId);
  });
  return {creator.id, ...matchingUsers.map((user) => user.id)}.toList();
}

List<Hub> manageableSharedRoomHubs({
  required AppUser? user,
  required List<Hub> hubs,
  required List<Team> organizationTeams,
  required bool forTeamScope,
}) {
  if (user == null) return const [];
  const permissions = PermissionService();
  return hubs.where((hub) {
    if (permissions.canManageContentScope(
      user,
      leagueId: hub.leagueId,
      hubId: hub.id,
    )) {
      return true;
    }
    if (!forTeamScope) return false;
    return organizationTeams.any(
      (team) =>
          team.leagueId == hub.leagueId &&
          team.hubId == hub.id &&
          permissions.canManageContentScope(
            user,
            leagueId: team.leagueId,
            hubId: team.hubId,
            teamId: team.id,
          ),
    );
  }).toList();
}

List<Team> manageableSharedRoomTeams({
  required AppUser? user,
  required List<Team> teams,
}) {
  if (user == null) return const [];
  const permissions = PermissionService();
  return teams
      .where(
        (team) => permissions.canManageContentScope(
          user,
          leagueId: team.leagueId,
          hubId: team.hubId,
          teamId: team.id,
        ),
      )
      .toList();
}

class _ChooseConversationType extends StatelessWidget {
  final double topPadding;
  final double bottomPadding;
  final VoidCallback onGroupRoom;
  final VoidCallback onEventRoom;
  final VoidCallback onDirectMessage;
  final bool canCreateSharedRoom;

  const _ChooseConversationType({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.onGroupRoom,
    required this.onEventRoom,
    required this.onDirectMessage,
    required this.canCreateSharedRoom,
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
        Text(
          canCreateSharedRoom
              ? 'Create a shared room for ongoing communication or an event.'
              : 'Start a private conversation with another member.',
          style: const TextStyle(
            fontSize: 14,
            color: AppGlassColors.inkSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 20),
        if (canCreateSharedRoom) ...[
          AppMotionReveal(
            index: 1,
            child: _ConversationTypeCard(
              icon: Icons.groups_2_outlined,
              title: 'Group Room',
              subtitle: 'An ongoing room for a league, Hub, or team.',
              color: AppGlassColors.aqua,
              onTap: onGroupRoom,
            ),
          ),
          const SizedBox(height: 12),
          AppMotionReveal(
            index: 2,
            child: _ConversationTypeCard(
              icon: Icons.event_outlined,
              title: 'Event Room',
              subtitle: 'A shared room for tournaments, games, or planning.',
              color: AppGlassColors.gold,
              onTap: onEventRoom,
            ),
          ),
          const SizedBox(height: 12),
        ],
        AppMotionReveal(
          index: 3,
          child: _ConversationTypeCard(
            icon: Icons.person_outline,
            title: 'Direct Message',
            subtitle: 'Message another member one-on-one.',
            color: AppGlassColors.aqua,
            onTap: onDirectMessage,
          ),
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

class _SharedRoomForm extends ConsumerWidget {
  final double topPadding;
  final double bottomPadding;
  final TextEditingController nameController;
  final ChatRoomPurpose roomPurpose;
  final _SharedRoomScope selectedScope;
  final String? selectedLeagueId;
  final String? selectedHubId;
  final String? selectedTeamId;
  final Set<String> selectedTeamIds;
  final String selectedIconName;
  final String? selectedImageName;
  final bool isCreating;
  final ValueChanged<_SharedRoomScope> onScopeSelected;
  final ValueChanged<String?> onLeagueSelected;
  final ValueChanged<String?> onHubSelected;
  final ValueChanged<String?> onTeamSelected;
  final ValueChanged<Set<String>> onTeamSelectionChanged;
  final ValueChanged<String> onIconSelected;
  final VoidCallback onPickImage;
  final VoidCallback onCreate;

  const _SharedRoomForm({
    super.key,
    required this.topPadding,
    required this.bottomPadding,
    required this.nameController,
    required this.roomPurpose,
    required this.selectedScope,
    required this.selectedLeagueId,
    required this.selectedHubId,
    required this.selectedTeamId,
    required this.selectedTeamIds,
    required this.selectedIconName,
    required this.selectedImageName,
    required this.isCreating,
    required this.onScopeSelected,
    required this.onLeagueSelected,
    required this.onHubSelected,
    required this.onTeamSelected,
    required this.onTeamSelectionChanged,
    required this.onIconSelected,
    required this.onPickImage,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaguesAsync = ref.watch(leaguesProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues = manageableLeaguesForUser(
      currentUser,
      leaguesAsync.valueOrNull ?? [],
    );
    final usesMultiTeamAudience = roomPurpose == ChatRoomPurpose.event &&
        selectedScope == _SharedRoomScope.team;
    final organizationTeamsAsync = usesMultiTeamAudience ||
            (currentUser?.role == UserRole.managerAdmin &&
                currentUser!.teamIds.isNotEmpty)
        ? ref.watch(organizationTeamsProvider)
        : const AsyncValue<List<Team>>.data([]);
    final organizationTeams = organizationTeamsAsync.valueOrNull ?? [];
    final hubsAsync = selectedLeagueId == null
        ? const AsyncValue<List<Hub>>.data([])
        : ref.watch(hubsProvider(selectedLeagueId!));
    final hubs = manageableSharedRoomHubs(
      user: currentUser,
      hubs: hubsAsync.valueOrNull ?? [],
      organizationTeams: organizationTeams,
      forTeamScope: selectedScope == _SharedRoomScope.team,
    );
    final effectiveHubId =
        hubs.any((hub) => hub.id == selectedHubId) ? selectedHubId : null;
    final teamsAsync = selectedLeagueId == null || effectiveHubId == null
        ? const AsyncValue<List<Team>>.data([])
        : ref.watch(
            teamsProvider((leagueId: selectedLeagueId!, hubId: effectiveHubId)),
          );
    final teams = manageableSharedRoomTeams(
      user: currentUser,
      teams: teamsAsync.valueOrNull ?? [],
    );
    final effectiveTeamId =
        teams.any((team) => team.id == selectedTeamId) ? selectedTeamId : null;
    final multiTeamChoices = manageableSharedRoomTeams(
      user: currentUser,
      teams: organizationTeams
          .where((team) => team.leagueId == selectedLeagueId)
          .toList(),
    );
    final effectiveSelectedTeamIds = selectedTeamIds.intersection(
      multiTeamChoices.map((team) => team.id).toSet(),
    );
    final selectedHubCount = multiTeamChoices
        .where((team) => effectiveSelectedTeamIds.contains(team.id))
        .map((team) => team.hubId)
        .toSet()
        .length;

    if (selectedHubId != null && effectiveHubId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onHubSelected(null);
      });
    }
    if (selectedTeamId != null && effectiveTeamId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onTeamSelected(null);
      });
    }
    if (selectedTeamIds.length != effectiveSelectedTeamIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          onTeamSelectionChanged(effectiveSelectedTeamIds);
        }
      });
    }

    if ((selectedScope == _SharedRoomScope.hub ||
            (selectedScope == _SharedRoomScope.team &&
                !usesMultiTeamAudience)) &&
        selectedHubId == null &&
        hubs.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) onHubSelected(hubs.first.id);
      });
    }
    if (selectedScope == _SharedRoomScope.team &&
        !usesMultiTeamAudience &&
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
          hintText: roomPurpose == ChatRoomPurpose.group
              ? 'Coaches and Managers'
              : 'Spring Tournament',
          leadingIcon: roomPurpose == ChatRoomPurpose.group
              ? Icons.groups_2_outlined
              : Icons.event_outlined,
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
          GlassScopeSelector<_SharedRoomScope>(
            selected: selectedScope,
            onChanged: isCreating ? null : onScopeSelected,
            options: [
              const GlassChoiceOption(
                value: _SharedRoomScope.league,
                label: 'League',
                icon: Icons.emoji_events_outlined,
              ),
              const GlassChoiceOption(
                value: _SharedRoomScope.hub,
                label: 'Hub',
                icon: Icons.location_on_outlined,
              ),
              GlassChoiceOption(
                value: _SharedRoomScope.team,
                label: roomPurpose == ChatRoomPurpose.event ? 'Teams' : 'Team',
                icon: Icons.groups_2_outlined,
              ),
            ],
          ),
        ],
        if ((selectedScope == _SharedRoomScope.hub ||
                (selectedScope == _SharedRoomScope.team &&
                    !usesMultiTeamAudience)) &&
            selectedLeagueId != null) ...[
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Hub'),
          const SizedBox(height: 8),
          GlassDropdownField<String>(
            value: effectiveHubId,
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
        if (selectedScope == _SharedRoomScope.team &&
            !usesMultiTeamAudience &&
            effectiveHubId != null) ...[
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Team'),
          const SizedBox(height: 8),
          GlassDropdownField<String>(
            value: effectiveTeamId,
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
        if (usesMultiTeamAudience) ...[
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Teams'),
          const SizedBox(height: 6),
          Text(
            effectiveSelectedTeamIds.isEmpty
                ? 'Select one or more teams from any Hub in this league.'
                : '${effectiveSelectedTeamIds.length} ${effectiveSelectedTeamIds.length == 1 ? 'team' : 'teams'} selected across $selectedHubCount ${selectedHubCount == 1 ? 'Hub' : 'Hubs'}.',
            style: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          switch (organizationTeamsAsync) {
            AsyncLoading() => const AppGlassSurface(
                radius: 20,
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppGlassColors.aqua),
                ),
              ),
            AsyncError() => AppGlassSurface(
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Teams could not be loaded. Please try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppGlassColors.inkSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: isCreating
                          ? null
                          : () => ref.invalidate(organizationTeamsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            _ when multiTeamChoices.isEmpty => const AppGlassSurface(
                radius: 20,
                padding: EdgeInsets.all(16),
                child: Text(
                  'No teams are available in your managed scope.',
                  style: TextStyle(color: AppGlassColors.inkMuted),
                ),
              ),
            _ => _MultiTeamPicker(
                hubs: hubsAsync.valueOrNull ?? const [],
                teams: multiTeamChoices,
                selectedTeamIds: effectiveSelectedTeamIds,
                enabled: !isCreating,
                onChanged: onTeamSelectionChanged,
              ),
          },
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

class _MultiTeamPicker extends StatelessWidget {
  final List<Hub> hubs;
  final List<Team> teams;
  final Set<String> selectedTeamIds;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  const _MultiTeamPicker({
    required this.hubs,
    required this.teams,
    required this.selectedTeamIds,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hubNames = {for (final hub in hubs) hub.id: hub.name};
    final teamsByHub = <String, List<Team>>{};
    for (final team in teams) {
      teamsByHub.putIfAbsent(team.hubId, () => []).add(team);
    }

    return AppGlassSurface(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in teamsByHub.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                hubNames[entry.key] ?? 'Hub',
                style: const TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final team in entry.value)
              GlassCheckTile(
                leading: EntityAvatar(
                  name: team.name,
                  imageUrl: team.logoUrl,
                  iconName: team.iconName,
                  fallbackIcon: Icons.groups_2_outlined,
                  size: 34,
                  color: AppGlassColors.aqua,
                ),
                title: team.name,
                subtitle: [team.ageGroup, team.division]
                    .where((value) => value?.trim().isNotEmpty == true)
                    .join(' · '),
                value: selectedTeamIds.contains(team.id),
                onChanged: !enabled
                    ? null
                    : (checked) {
                        final next = {...selectedTeamIds};
                        if (checked == true) {
                          next.add(team.id);
                        } else {
                          next.remove(team.id);
                        }
                        onChanged(next);
                      },
              ),
          ],
        ],
      ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 7,
            ),
            leading: AvatarWidget(
              imageUrl: user.avatarUrl,
              name: user.displayName,
              size: 48,
              backgroundColor: AppUtils.roleColor(
                user.role,
              ).withValues(alpha: 0.22),
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
            trailing: const Icon(
              Icons.chevron_right,
              color: AppGlassColors.inkMuted,
            ),
          ),
        );
      },
    );
  }
}
