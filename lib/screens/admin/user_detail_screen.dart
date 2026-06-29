import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/league_branding.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/app_user.dart';
import '../../models/hub.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/entity_avatar.dart';
import '../../widgets/glass_form_widgets.dart';
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
  final _titleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

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

  @override
  void dispose() {
    _titleController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
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
          _titleController.text = user.title ?? '';
          _phoneController.text = user.phone ?? '';
          _addressController.text = user.address ?? '';
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
      final teamIdsList = _editableSelectedTeamIds().toList();
      final hubIdsList = _editHubIds.toList();
      // Derive leagueIds from hub assignments.
      final leagueIds = await fs.deriveLeagueIdsFromHubs(orgId, hubIdsList);
      final updates = <String, dynamic>{
        'role': (_editRole ?? _user!.role).name,
        'hubIds': hubIdsList,
        'leagueIds': leagueIds,
        'teamIds': teamIdsList,
      };
      _putOptionalProfileUpdate(
        updates,
        field: 'title',
        currentValue: _user!.title,
        nextValue: _titleController.text,
      );
      _putOptionalProfileUpdate(
        updates,
        field: 'phone',
        currentValue: _user!.phone,
        nextValue: _phoneController.text,
      );
      _putOptionalProfileUpdate(
        updates,
        field: 'address',
        currentValue: _user!.address,
        nextValue: _addressController.text,
      );
      await _syncTeamMemberships(
        authorizedSvc,
        currentUser,
        orgId,
        _user!,
        teamIdsList,
      );
      await authorizedSvc.updateUserFields(currentUser, _user!, updates);
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

  void _putOptionalProfileUpdate(
    Map<String, dynamic> updates, {
    required String field,
    required String? currentValue,
    required String nextValue,
  }) {
    final current = (currentValue ?? '').trim();
    final next = nextValue.trim();
    if (next == current) return;
    updates[field] = next.isEmpty ? FieldValue.delete() : next;
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

  Set<String> _editableSelectedTeamIds() {
    final availableIds = _teamsForSelectedHubs().map((team) => team.id).toSet();
    return _editTeamIds.intersection(availableIds);
  }

  List<Team> _teamsForSelectedHubs() {
    return _allTeams.where((team) => _editHubIds.contains(team.hubId)).toList();
  }

  void _removeTeamsForHub(String hubId) {
    _editTeamIds.removeWhere((teamId) {
      final team = _allTeams.cast<Team?>().firstWhere(
            (team) => team?.id == teamId,
            orElse: () => null,
          );
      return team?.hubId == hubId;
    });
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
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);

    if (_loading) {
      return AppShellScaffold(
        header: AppShellHeader(
          title: 'User Detail',
          leadingIcon: Icons.person_outline,
          leadingImageUrl: headerLeague?.logoUrl,
          leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
              ? headerLeague?.name
              : null,
          showBackButton: true,
          backFallbackLocation: '/settings/users',
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppGlassColors.aqua),
        ),
      );
    }
    if (_user == null) {
      return AppShellScaffold(
        header: AppShellHeader(
          title: 'User Detail',
          leadingIcon: Icons.person_outline,
          leadingImageUrl: headerLeague?.logoUrl,
          leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
              ? headerLeague?.name
              : null,
          showBackButton: true,
          backFallbackLocation: '/settings/users',
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            appShellTopPadding(context),
            16,
            appShellBottomPadding(context, extra: 24),
          ),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'User not found.',
                style: TextStyle(color: AppGlassColors.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    final user = _user!;
    final currentUserRole = ref.watch(currentUserProvider).valueOrNull?.role;
    final canEdit = currentUserRole == UserRole.platformOwner ||
        currentUserRole == UserRole.superAdmin;
    final canChangeRole = canEdit &&
        user.role != UserRole.platformOwner &&
        user.role != UserRole.superAdmin;

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'User Detail',
        leadingIcon: Icons.person_outline,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
            ? headerLeague?.name
            : null,
        showBackButton: true,
        backFallbackLocation: '/settings/users',
        actions: [
          if (canEdit && !_editing)
            _HeaderTextAction(
              label: 'Edit',
              onTap: () => setState(() => _editing = true),
            ),
          if (_editing) ...[
            _HeaderTextAction(
              label: 'Save',
              saving: _saving,
              onTap: _saving ? null : _saveChanges,
            ),
            const SizedBox(width: 8),
            _HeaderIconAction(
              icon: Icons.close,
              onTap: () {
                setState(() {
                  _editing = false;
                  _editRole = user.role;
                  _editHubIds
                    ..clear()
                    ..addAll(user.hubIds);
                  _editTeamIds
                    ..clear()
                    ..addAll(user.teamIds);
                  _titleController.text = user.title ?? '';
                  _phoneController.text = user.phone ?? '';
                  _addressController.text = user.address ?? '';
                });
              },
            ),
          ],
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          appShellTopPadding(context),
          16,
          appShellBottomPadding(context, extra: 24),
        ),
        children: [
          _buildProfileHeader(user),
          const SizedBox(height: 16),
          _buildInfoSection(user, canChangeRole),
          const SizedBox(height: 16),
          _buildContactSection(user),
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
    return AppGlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 26,
      child: Row(
        children: [
          AvatarWidget(
            name: user.displayName,
            imageUrl: user.avatarUrl,
            size: 64,
            backgroundColor: AppGlassColors.aqua.withValues(alpha: 0.25),
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
                        color: AppGlassColors.ink)),
                const SizedBox(height: 4),
                Text(user.email,
                    style: const TextStyle(
                        fontSize: 13, color: AppGlassColors.inkSecondary)),
                if (user.title != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppGlassColors.aqua,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                      label: user.isActive ? 'Active' : 'Inactive',
                      color:
                          user.isActive ? AppColors.success : AppColors.danger,
                      backgroundColor: user.isActive
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.danger.withValues(alpha: 0.3),
                      textColor: AppGlassColors.ink,
                      showBorder: false),
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
      title: 'Profile',
      child: Column(
        children: [
          if (_editing) ...[
            GlassTextFormField(
              controller: _titleController,
              labelText: 'Title',
              leadingIcon: Icons.work_outline,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
          ] else ...[
            _InfoRow(label: 'Title', value: user.title ?? 'Not set'),
            const SizedBox(height: 14),
          ],
          if (_editing && canChangeRole)
            _buildRolePicker()
          else
            _InfoRow(label: 'Role', value: user.roleLabel),
        ],
      ),
    );
  }

  Widget _buildContactSection(AppUser user) {
    return _SectionCard(
      title: 'Contact',
      child: _editing
          ? Column(
              children: [
                GlassTextFormField(
                  controller: _phoneController,
                  labelText: 'Phone',
                  leadingIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                GlassTextFormField(
                  controller: _addressController,
                  labelText: 'Address',
                  leadingIcon: Icons.location_on_outlined,
                  keyboardType: TextInputType.streetAddress,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.words,
                  minLines: 1,
                  maxLines: 3,
                ),
              ],
            )
          : Column(
              children: [
                if (user.phone == null && user.address == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No contact details shared.',
                      style: TextStyle(color: AppGlassColors.inkMuted),
                    ),
                  )
                else ...[
                  if (user.phone != null)
                    _InfoRow(label: 'Phone', value: user.phone!),
                  if (user.phone != null && user.address != null)
                    const SizedBox(height: 14),
                  if (user.address != null)
                    _InfoRow(label: 'Address', value: user.address!),
                ],
              ],
            ),
    );
  }

  Widget _buildRolePicker() {
    return RadioGroup<UserRole>(
      groupValue: _editRole,
      onChanged: (v) => setState(() => _editRole = v),
      child: Column(
        children: [
          const GlassRadioTile<UserRole>(
            label: 'Manager',
            value: UserRole.managerAdmin,
          ),
          const GlassRadioTile<UserRole>(
            label: 'Staff',
            value: UserRole.staff,
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
                    style: TextStyle(color: AppGlassColors.inkMuted)),
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
          ? const Center(
              child: CircularProgressIndicator(color: AppGlassColors.aqua))
          : _allHubs.isEmpty
              ? const Text('No hubs available',
                  style: TextStyle(color: AppGlassColors.inkMuted))
              : Column(
                  children: _allHubs
                      .map((hub) => GlassCheckTile(
                            title: hub.name,
                            subtitle: hub.location,
                            value: _editHubIds.contains(hub.id),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _editHubIds.add(hub.id);
                                } else {
                                  _editHubIds.remove(hub.id);
                                  _removeTeamsForHub(hub.id);
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
                    style: TextStyle(color: AppGlassColors.inkMuted)),
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

    final availableTeams = _teamsForSelectedHubs();

    return _SectionCard(
      title: 'Team Assignments',
      child: _teamsLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppGlassColors.aqua))
          : _editHubIds.isEmpty
              ? const Text('Select hubs to manage team assignments.',
                  style: TextStyle(color: AppGlassColors.inkMuted))
              : availableTeams.isEmpty
                  ? const Text('No teams available for the selected hubs.',
                      style: TextStyle(color: AppGlassColors.inkMuted))
                  : Column(
                      children: availableTeams
                          .map((team) => GlassCheckTile(
                                leading: EntityAvatar(
                                  name: team.name,
                                  imageUrl: team.logoUrl,
                                  iconName: team.iconName,
                                  fallbackIcon: Icons.groups_2_outlined,
                                  size: 34,
                                  color: AppGlassColors.aqua,
                                ),
                                title: team.name,
                                subtitle: _teamMeta(team, _allHubs),
                                value: _editTeamIds.contains(team.id),
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _editTeamIds.add(team.id);
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
    final color = user.isActive ? AppGlassColors.rose : AppGlassColors.aqua;
    return AppGlassSurface(
      onTap: _toggleActive,
      padding: const EdgeInsets.symmetric(vertical: 14),
      radius: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            user.isActive ? Icons.block : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            user.isActive ? 'Deactivate User' : 'Reactivate User',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppGlassColors.inkMuted,
                    letterSpacing: 0.8)),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _HeaderTextAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool saving;

  const _HeaderTextAction({
    required this.label,
    required this.onTap,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      radius: 20,
      child: Center(
        child: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: AppGlassColors.aqua,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: AppGlassColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }
}

class _HeaderIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconAction({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      width: 40,
      height: 40,
      padding: EdgeInsets.zero,
      radius: 20,
      child: Icon(icon, color: AppGlassColors.ink, size: 18),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 14, color: AppGlassColors.inkMuted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppGlassColors.ink,
            ),
          ),
        ),
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
          const Icon(Icons.location_city, size: 16, color: AppGlassColors.aqua),
          const SizedBox(width: 8),
          Text(
            hub?.name ?? hubId,
            style: const TextStyle(fontSize: 14, color: AppGlassColors.ink),
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
            color: AppGlassColors.aqua,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team?.name ?? teamId,
                  style:
                      const TextStyle(fontSize: 14, color: AppGlassColors.ink),
                ),
                if (team != null)
                  Text(
                    _teamMeta(team, allHubs),
                    style: const TextStyle(
                        fontSize: 12, color: AppGlassColors.inkMuted),
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
