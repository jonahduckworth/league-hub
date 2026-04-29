import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/hub.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/entity_avatar.dart';
import '../../widgets/status_badge.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  AppUser? _user;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  // Edit state
  UserRole? _editRole;
  final Set<String> _editHubIds = {};
  final Set<String> _editTeamIds = {};
  List<Hub> _allHubs = [];
  List<Team> _allTeams = [];
  bool _hubsLoading = true;
  bool _teamsLoading = true;
  String? _loadedHubsOrgId;
  String? _loadedTeamsOrgId;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadHubs();
    _loadTeams();
  }

  Future<void> _loadUser() async {
    final svc = ref.read(firestoreServiceProvider);
    final user = await svc.getUserById(widget.userId);
    if (mounted) {
      setState(() {
        _user = user;
        _loading = false;
        if (user != null) {
          _editRole = user.role;
          _editHubIds
            ..clear()
            ..addAll(user.hubIds);
          _editTeamIds
            ..clear()
            ..addAll(user.teamIds);
        }
      });
      if (user != null) {
        await Future.wait([
          _loadHubs(),
          _loadTeams(),
        ]);
      }
    }
  }

  Future<void> _loadHubs() async {
    final orgId = _targetOrgId();
    if (orgId == null) {
      setState(() => _hubsLoading = false);
      return;
    }
    if (_loadedHubsOrgId == orgId && !_hubsLoading) return;

    final hubs = await ref.read(firestoreServiceProvider).getAllHubsFlat(orgId);
    if (mounted) {
      setState(() {
        _allHubs = hubs;
        _hubsLoading = false;
        _loadedHubsOrgId = orgId;
      });
    }
  }

  Future<void> _loadTeams() async {
    final orgId = _targetOrgId();
    if (orgId == null) {
      setState(() => _teamsLoading = false);
      return;
    }
    if (_loadedTeamsOrgId == orgId && !_teamsLoading) return;

    final teams =
        await ref.read(firestoreServiceProvider).getAllTeamsFlat(orgId);
    if (mounted) {
      setState(() {
        _allTeams = teams;
        _teamsLoading = false;
        _loadedTeamsOrgId = orgId;
      });
    }
  }

  String? _targetOrgId() {
    return _user?.orgId ?? ref.read(organizationProvider).valueOrNull?.id;
  }

  Future<void> _saveChanges() async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) return;

      final authorizedSvc = ref.read(authorizedFirestoreServiceProvider);
      final fs = ref.read(firestoreServiceProvider);
      final orgId = _user!.orgId ??
          ref.read(organizationProvider).valueOrNull?.id ??
          currentUser.orgId;
      if (orgId == null) return;
      final teamIdsList = _editTeamIds.toList();
      final hubIdsList = _selectedHubIdsWithTeams();
      // Derive leagueIds from hub assignments.
      final leagueIds = await fs.deriveLeagueIdsFromHubs(orgId, hubIdsList);
      await _syncTeamMemberships(
        authorizedSvc,
        currentUser,
        orgId,
        _user!,
        teamIdsList,
      );
      await authorizedSvc.updateUserFields(currentUser, _user!, {
        'role': _editRole!.name,
        'hubIds': hubIdsList,
        'leagueIds': leagueIds,
        'teamIds': teamIdsList,
      });
      // Reload user
      await _loadUser();
      if (mounted) setState(() => _editing = false);
    } on PermissionDeniedException catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Permission denied: $e');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to save: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive() async {
    if (_user == null) return;
    final action = _user!.isActive ? 'Deactivate' : 'Reactivate';
    final confirmed = await showConfirmationDialog(
      context,
      title: '$action User',
      message: _user!.isActive
          ? 'Deactivate ${_user!.displayName}? They will lose access to the app.'
          : 'Reactivate ${_user!.displayName}? They will regain access.',
      confirmLabel: action,
      confirmColor: _user!.isActive ? AppColors.danger : AppColors.success,
    );
    if (confirmed != true) return;
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) return;

      final authorizedSvc = ref.read(authorizedFirestoreServiceProvider);
      if (_user!.isActive) {
        await authorizedSvc.deactivateUser(currentUser, _user!);
      } else {
        await authorizedSvc.reactivateUser(currentUser, _user!);
      }
      await _loadUser();
    } on PermissionDeniedException catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Permission denied: $e');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  List<String> _selectedHubIdsWithTeams() {
    final ids = <String>{..._editHubIds};
    for (final team in _allTeams) {
      if (_editTeamIds.contains(team.id)) {
        ids.add(team.hubId);
      }
    }
    return ids.toList();
  }

  Future<void> _syncTeamMemberships(
    AuthorizedFirestoreService authorizedSvc,
    AppUser currentUser,
    String orgId,
    AppUser targetUser,
    List<String> selectedTeamIds,
  ) async {
    final selectedIds = selectedTeamIds.toSet();
    final touchedIds = <String>{...targetUser.teamIds, ...selectedIds};

    for (final team
        in _allTeams.where((team) => touchedIds.contains(team.id))) {
      final hasMember = team.memberIds.contains(targetUser.id);
      final shouldHaveMember = selectedIds.contains(team.id);
      if (hasMember == shouldHaveMember) continue;

      final memberIds = shouldHaveMember
          ? {...team.memberIds, targetUser.id}.toList()
          : team.memberIds.where((id) => id != targetUser.id).toList();
      await authorizedSvc.updateTeamFields(
        currentUser,
        orgId,
        team.leagueId,
        team.hubId,
        team.id,
        {'memberIds': memberIds},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Detail')),
        body: const Center(child: Text('User not found.')),
      );
    }

    final user = _user!;
    final currentUserRole = ref.watch(currentUserProvider).valueOrNull?.role;
    final canEdit = currentUserRole == UserRole.platformOwner ||
        currentUserRole == UserRole.superAdmin;
    final canChangeRole = canEdit &&
        user.role != UserRole.platformOwner &&
        user.role != UserRole.superAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Detail'),
        actions: [
          if (canEdit && !_editing)
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _saveChanges,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          if (_editing)
            TextButton(
              onPressed: () {
                setState(() {
                  _editing = false;
                  _editRole = user.role;
                  _editHubIds
                    ..clear()
                    ..addAll(user.hubIds);
                  _editTeamIds
                    ..clear()
                    ..addAll(user.teamIds);
                });
              },
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(user),
          const SizedBox(height: 16),
          _buildInfoSection(user, canChangeRole),
          const SizedBox(height: 16),
          _buildHubSection(user),
          const SizedBox(height: 16),
          _buildTeamSection(user),
          const SizedBox(height: 16),
          _buildDatesSection(user),
          const SizedBox(height: 24),
          if (canEdit && user.role != UserRole.platformOwner)
            _buildDeactivateButton(user),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(AppUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          AvatarWidget(
            name: user.displayName,
            imageUrl: user.avatarUrl,
            size: 64,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(user.email,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusBadge(
                        label: user.roleLabel,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        textColor: Colors.white,
                        showBorder: false),
                    const SizedBox(width: 8),
                    StatusBadge(
                        label: user.isActive ? 'Active' : 'Inactive',
                        color: user.isActive
                            ? AppColors.success
                            : AppColors.danger,
                        backgroundColor: user.isActive
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.danger.withValues(alpha: 0.3),
                        textColor: Colors.white,
                        showBorder: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(AppUser user, bool canChangeRole) {
    return _SectionCard(
      title: 'Role & Access',
      child: _editing && canChangeRole
          ? _buildRolePicker()
          : _InfoRow(label: 'Role', value: user.roleLabel),
    );
  }

  Widget _buildRolePicker() {
    return RadioGroup<UserRole>(
      groupValue: _editRole,
      onChanged: (v) => setState(() => _editRole = v),
      child: Column(
        children: [
          RadioListTile<UserRole>(
            dense: true,
            title: const Text('Manager Admin'),
            value: UserRole.managerAdmin,
            activeColor: AppColors.primary,
          ),
          RadioListTile<UserRole>(
            dense: true,
            title: const Text('Staff'),
            value: UserRole.staff,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildHubSection(AppUser user) {
    if (!_editing) {
      return _SectionCard(
        title: 'Hub Assignments',
        child: user.hubIds.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No hubs assigned',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            : Column(
                children: user.hubIds
                    .map((id) => _HubChip(hubId: id, allHubs: _allHubs))
                    .toList(),
              ),
      );
    }

    return _SectionCard(
      title: 'Hub Assignments',
      child: _hubsLoading
          ? const Center(child: CircularProgressIndicator())
          : _allHubs.isEmpty
              ? const Text('No hubs available',
                  style: TextStyle(color: AppColors.textMuted))
              : Column(
                  children: _allHubs
                      .map((hub) => CheckboxListTile(
                            dense: true,
                            title: Text(hub.name),
                            subtitle: hub.location != null
                                ? Text(hub.location!)
                                : null,
                            value: _editHubIds.contains(hub.id),
                            activeColor: AppColors.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _editHubIds.add(hub.id);
                                } else {
                                  _editHubIds.remove(hub.id);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
    );
  }

  Widget _buildTeamSection(AppUser user) {
    if (!_editing) {
      return _SectionCard(
        title: 'Team Assignments',
        child: user.teamIds.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No teams assigned',
                    style: TextStyle(color: AppColors.textMuted)),
              )
            : Column(
                children: user.teamIds
                    .map((id) => _TeamChip(
                          teamId: id,
                          allTeams: _allTeams,
                          allHubs: _allHubs,
                        ))
                    .toList(),
              ),
      );
    }

    return _SectionCard(
      title: 'Team Assignments',
      child: _teamsLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTeams.isEmpty
              ? const Text('No teams available',
                  style: TextStyle(color: AppColors.textMuted))
              : Column(
                  children: _allTeams
                      .map((team) => CheckboxListTile(
                            dense: true,
                            secondary: EntityAvatar(
                              name: team.name,
                              imageUrl: team.logoUrl,
                              iconName: team.iconName,
                              fallbackIcon: Icons.groups_2_outlined,
                              size: 34,
                              color: AppColors.accent,
                            ),
                            title: Text(team.name),
                            subtitle: Text(_teamMeta(team, _allHubs)),
                            value: _editTeamIds.contains(team.id),
                            activeColor: AppColors.primary,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _editTeamIds.add(team.id);
                                  _editHubIds.add(team.hubId);
                                } else {
                                  _editTeamIds.remove(team.id);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
    );
  }

  Widget _buildDatesSection(AppUser user) {
    return _SectionCard(
      title: 'Dates',
      child: Column(
        children: [
          _InfoRow(label: 'Joined', value: AppUtils.formatDate(user.createdAt)),
        ],
      ),
    );
  }

  Widget _buildDeactivateButton(AppUser user) {
    return OutlinedButton.icon(
      onPressed: _toggleActive,
      style: OutlinedButton.styleFrom(
        foregroundColor: user.isActive ? AppColors.danger : AppColors.success,
        side: BorderSide(
            color: user.isActive ? AppColors.danger : AppColors.success),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(user.isActive ? Icons.block : Icons.check_circle_outline),
      label: Text(
        user.isActive ? 'Deactivate User' : 'Reactivate User',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
      ],
    );
  }
}

class _HubChip extends StatelessWidget {
  final String hubId;
  final List<Hub> allHubs;
  const _HubChip({required this.hubId, required this.allHubs});

  @override
  Widget build(BuildContext context) {
    final hub = allHubs.cast<Hub?>().firstWhere(
          (h) => h?.id == hubId,
          orElse: () => null,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.location_city, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            hub?.name ?? hubId,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ],
      ),
    );
  }
}

class _TeamChip extends StatelessWidget {
  final String teamId;
  final List<Team> allTeams;
  final List<Hub> allHubs;

  const _TeamChip({
    required this.teamId,
    required this.allTeams,
    required this.allHubs,
  });

  @override
  Widget build(BuildContext context) {
    final team = allTeams.cast<Team?>().firstWhere(
          (team) => team?.id == teamId,
          orElse: () => null,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          EntityAvatar(
            name: team?.name ?? teamId,
            imageUrl: team?.logoUrl,
            iconName: team?.iconName,
            fallbackIcon: Icons.groups_2_outlined,
            size: 30,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team?.name ?? teamId,
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
                if (team != null)
                  Text(
                    _teamMeta(team, allHubs),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _teamMeta(Team team, List<Hub> allHubs) {
  final hub = allHubs.cast<Hub?>().firstWhere(
        (hub) => hub?.id == team.hubId,
        orElse: () => null,
      );
  final details = [
    hub?.name,
    team.ageGroup,
    team.division,
  ].where((value) => value != null && value.isNotEmpty).cast<String>();
  return details.join(' · ');
}
