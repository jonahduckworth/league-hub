import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/league_branding.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/hub.dart';
import '../../models/invitation.dart';
import '../../models/league.dart';
import '../../models/team.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/authorized_firestore_service.dart';
import '../../core/utils.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/bottom_sheet_handle.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/entity_avatar.dart';
import '../../widgets/glass_form_widgets.dart';
import '../../widgets/status_badge.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'All';

  static const _roleFilters = ['All', 'Admin', 'Manager', 'Staff'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filtered(List<AppUser> users) {
    final filtered = users.where((u) {
      final matchesSearch = _searchQuery.isEmpty ||
          u.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'All' || u.roleLabel == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();

    filtered.sort(_compareUsersByLastName);
    return filtered;
  }

  int _compareUsersByLastName(AppUser a, AppUser b) {
    final aName = _nameSortParts(a.displayName);
    final bName = _nameSortParts(b.displayName);
    final lastName = aName.last.compareTo(bName.last);
    if (lastName != 0) return lastName;
    final firstName = aName.first.compareTo(bName.first);
    if (firstName != 0) return firstName;
    return a.email.toLowerCase().compareTo(b.email.toLowerCase());
  }

  ({String first, String last}) _nameSortParts(String displayName) {
    final parts = displayName
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return (first: '', last: '');
    }
    if (parts.length == 1) {
      return (first: '', last: parts.first);
    }
    return (
      first: parts.take(parts.length - 1).join(' '),
      last: parts.last,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(orgUsersProvider);
    final pendingCount = ref.watch(pendingInviteCountProvider);
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context, extra: 0);
    final bottomContentPadding = appShellBottomPadding(context, extra: 98);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'User Management',
        leadingIcon: Icons.manage_accounts_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.logoUrl?.isNotEmpty == true
            ? headerLeague?.name
            : null,
        showBackButton: true,
        backFallbackLocation: '/settings',
        actions: [
          if (pendingCount > 0)
            _HeaderInviteButton(
              count: pendingCount,
              onTap: () => _showInvitationsSheet(context),
            ),
        ],
      ),
      floatingActionButton: _GlassInviteButton(
        onTap: () => context.push('/settings/users/invite'),
      ),
      child: usersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppGlassColors.aqua),
        ),
        error: (e, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            topContentPadding,
            16,
            appShellBottomPadding(context, extra: 24),
          ),
          children: [
            _GlassMessageCard(
              icon: Icons.error_outline,
              title: 'Could not load users',
              message: '$e',
              color: AppGlassColors.rose,
            ),
          ],
        ),
        data: (users) {
          final filtered = _filtered(users);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              topContentPadding,
              16,
              bottomContentPadding,
            ),
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilterChips(),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 96),
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: 'No users found',
                  ),
                )
              else
                for (final user in filtered) _UserCard(user: user),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return AppGlassSurface(
      key: const ValueKey('user-management-search'),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      radius: 22,
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: AppGlassColors.inkSecondary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              cursorColor: AppGlassColors.aqua,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: _roleFilters.map((label) {
          final selected = _roleFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _GlassFilterChip(
              key: ValueKey('role-filter-$label'),
              label: Text(label),
              selected: selected,
              onSelected: () => setState(() => _roleFilter = label),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showInvitationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PendingInvitationsSheet(),
    );
  }
}

// --- User Card ---

class _UserCard extends ConsumerWidget {
  final AppUser user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/settings/users/${user.id}'),
      onLongPress: () => _showDeactivateDialog(context, ref),
      child: AppGlassSurface(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        radius: 22,
        child: Row(
          children: [
            Stack(
              children: [
                AvatarWidget(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                  size: 48,
                  backgroundColor: AppUtils.roleColor(user.role)
                      .withValues(alpha: user.isActive ? 0.75 : 0.28),
                ),
                if (!user.isActive)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: user.isActive
                                ? AppGlassColors.ink
                                : AppGlassColors.inkMuted,
                          ),
                        ),
                      ),
                      StatusBadge(
                          label: user.roleLabel,
                          color: AppUtils.roleColor(user.role)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 13, color: AppGlassColors.inkSecondary)),
                  if (user.hubIds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user.hubIds.length} hub${user.hubIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppGlassColors.inkMuted),
                    ),
                  ],
                  if (!user.isActive) ...[
                    const SizedBox(height: 4),
                    const Text('Inactive',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppGlassColors.rose,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppGlassColors.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeactivateDialog(
      BuildContext context, WidgetRef ref) async {
    final action = user.isActive ? 'Deactivate' : 'Reactivate';
    final ok = await showConfirmationDialog(
      context,
      title: '$action User',
      message: user.isActive
          ? 'Deactivate ${user.displayName}? They will lose access to the app.'
          : 'Reactivate ${user.displayName}? They will regain access.',
      confirmLabel: action,
      confirmColor: user.isActive ? AppColors.danger : AppColors.success,
    );
    if (ok != true) return;

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (!context.mounted) return;
      if (currentUser == null) {
        AppUtils.showErrorSnackBar(context, 'User not authenticated');
        return;
      }
      final authorizedSvc = ref.read(authorizedFirestoreServiceProvider);
      if (user.isActive) {
        await authorizedSvc.deactivateUser(currentUser, user);
      } else {
        await authorizedSvc.reactivateUser(currentUser, user);
      }
    } on PermissionDeniedException catch (e) {
      if (context.mounted) {
        AppUtils.showErrorSnackBar(context, 'Permission denied: $e');
      }
    } catch (e) {
      if (context.mounted) {
        AppUtils.showErrorSnackBar(context, 'Error: $e');
      }
    }
  }
}

// --- Pending Invitations Sheet ---

class _PendingInvitationsSheet extends ConsumerWidget {
  const _PendingInvitationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(activePendingInvitationsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: AppGlassSurface(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: EdgeInsets.zero,
          radius: 30,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const BottomSheetHandle(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread_outlined,
                        color: AppGlassColors.aqua, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Pending Invitations',
                      style: TextStyle(
                        color: AppGlassColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: pending.isEmpty
                    ? const Center(
                        child: Text(
                          'No pending invitations',
                          style: TextStyle(color: AppGlassColors.inkMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        itemCount: pending.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _InvitationTile(invite: pending[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  final Invitation invite;
  const _InvitationTile({required this.invite});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppGlassColors.aqua.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppGlassColors.aqua.withValues(alpha: 0.26),
              ),
            ),
            child: const Icon(Icons.mail_outline,
                color: AppGlassColors.aqua, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${invite.roleLabel} · Invited by ${invite.invitedByName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: AppGlassColors.inkMuted),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: invite.token));
              AppUtils.showInfoSnackBar(context, 'Invite code copied!');
            },
            tooltip: 'Copy invite code',
          ),
        ],
      ),
    );
  }
}

// --- Invite User Page ---

class InviteUserScreen extends ConsumerStatefulWidget {
  const InviteUserScreen({super.key});

  @override
  ConsumerState<InviteUserScreen> createState() => _InviteUserScreenState();
}

class _InviteUserScreenState extends ConsumerState<InviteUserScreen> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'staff';
  final Set<String> _selectedHubIds = {};
  final Set<String> _selectedTeamIds = {};
  bool _isLoading = false;
  bool _hubsLoading = true;
  bool _teamsLoading = true;
  List<League> _leagues = [];
  List<Hub> _allHubs = [];
  List<Team> _allTeams = [];

  @override
  void initState() {
    super.initState();
    _loadHubs();
  }

  Future<void> _loadHubs() async {
    final org = ref.read(organizationProvider).valueOrNull;
    if (org == null) {
      setState(() {
        _hubsLoading = false;
        _teamsLoading = false;
      });
      return;
    }
    final svc = ref.read(firestoreServiceProvider);
    final leagues = await svc.getLeagues(org.id).first;
    final hubs = await svc.getAllHubsFlat(org.id);
    final teams = await svc.getAllTeamsFlat(org.id);
    if (mounted) {
      setState(() {
        _leagues = leagues;
        _allHubs = hubs;
        _allTeams = teams;
        _hubsLoading = false;
        _teamsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Set<String> _selectedTeamIdsForSelectedHubs() {
    final availableTeamIds = _allTeams
        .where((team) => _selectedHubIds.contains(team.hubId))
        .map((team) => team.id)
        .toSet();
    return _selectedTeamIds.intersection(availableTeamIds);
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppUtils.showErrorSnackBar(context, 'Email is required');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final org = ref.read(organizationProvider).valueOrNull;
      final currentUser = await ref.read(currentUserProvider.future);
      if (org == null || currentUser == null) return;

      final invitation = Invitation(
        id: '',
        orgId: org.id,
        email: email,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        role: _selectedRole,
        hubIds: _selectedHubIds.toList(),
        teamIds: _selectedTeamIdsForSelectedHubs().toList(),
        invitedBy: currentUser.id,
        invitedByName: currentUser.displayName,
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        token: '',
      );

      final authorizedSvc = ref.read(authorizedFirestoreServiceProvider);
      final token =
          await authorizedSvc.createInvitation(currentUser, org.id, invitation);
      if (!mounted) return;
      _showSuccessDialog(context, token);
    } on PermissionDeniedException catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Permission denied: $e');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to send invite: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(BuildContext context, String token) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.56),
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AppGlassSurface(
          radius: 30,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Invitation Created',
                style: TextStyle(
                  color: AppGlassColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Share this invite code with the user. They can enter it on the Accept Invitation screen.',
                style: TextStyle(
                  color: AppGlassColors.inkSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              AppGlassSurface(
                padding: const EdgeInsets.all(12),
                radius: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        token,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppGlassColors.aqua,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          color: AppGlassColors.ink, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: token));
                        AppUtils.showInfoSnackBar(context, 'Copied!');
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppGlassSurface(
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/settings/users');
                    },
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    radius: 18,
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: AppGlassColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Invite User',
        leadingIcon: Icons.person_add_alt_1_outlined,
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
        children: [
          const GlassFormSectionLabel('User Details'),
          const SizedBox(height: 8),
          GlassTextFormField(
            controller: _emailController,
            labelText: 'Email *',
            hintText: 'name@example.com',
            leadingIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          GlassTextFormField(
            controller: _nameController,
            labelText: 'Display Name',
            hintText: 'Optional',
            leadingIcon: Icons.person_outline,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Role'),
          const SizedBox(height: 8),
          _buildRolePicker(),
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Hub Access'),
          const SizedBox(height: 8),
          _buildHubPicker(),
          const SizedBox(height: 18),
          const GlassFormSectionLabel('Team Access'),
          const SizedBox(height: 8),
          _buildTeamPicker(),
          const SizedBox(height: 22),
          GlassSubmitButton(
            label: 'Send Invite',
            isLoading: _isLoading,
            onTap: _isLoading ? null : _sendInvite,
          ),
        ],
      ),
    );
  }

  Widget _buildRolePicker() {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 20,
      child: Column(
        children: [
          RadioGroup<String>(
            groupValue: _selectedRole,
            onChanged: (v) => setState(() {
              if (v != null) _selectedRole = v;
            }),
            child: const Column(
              children: [
                GlassRadioTile<String>(
                  label: 'Manager',
                  description: 'Can manage hubs, teams, and staff',
                  value: 'managerAdmin',
                ),
                _GlassDivider(),
                GlassRadioTile<String>(
                  label: 'Staff',
                  description: 'Can view and interact with assigned hubs',
                  value: 'staff',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubPicker() {
    if (_hubsLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: AppGlassColors.aqua),
      ));
    }
    if (_allHubs.isEmpty) {
      return const Text('No hubs available',
          style: TextStyle(color: AppGlassColors.inkMuted));
    }

    final hubsByLeague = <String, List<Hub>>{};
    for (final hub in _allHubs) {
      hubsByLeague.putIfAbsent(hub.leagueId, () => []).add(hub);
    }

    return AppGlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 6),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in hubsByLeague.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _leagueName(entry.key),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppGlassColors.inkMuted,
                    letterSpacing: 0.5),
              ),
            ),
            for (final hub in entry.value)
              GlassCheckTile(
                title: hub.name,
                subtitle: hub.location,
                value: _selectedHubIds.contains(hub.id),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedHubIds.add(hub.id);
                    } else {
                      _selectedHubIds.remove(hub.id);
                      _selectedTeamIds.removeWhere((teamId) {
                        final team = _allTeams.cast<Team?>().firstWhere(
                              (team) => team?.id == teamId,
                              orElse: () => null,
                            );
                        return team?.hubId == hub.id;
                      });
                    }
                  });
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamPicker() {
    if (_teamsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppGlassColors.aqua),
        ),
      );
    }
    if (_selectedHubIds.isEmpty) {
      return const AppGlassSurface(
        padding: EdgeInsets.all(14),
        radius: 18,
        child: Text(
          'Select hubs to choose team assignments.',
          style: TextStyle(color: AppGlassColors.inkMuted),
        ),
      );
    }

    final availableTeams = _allTeams
        .where((team) => _selectedHubIds.contains(team.hubId))
        .toList();
    if (availableTeams.isEmpty) {
      return const AppGlassSurface(
        padding: EdgeInsets.all(14),
        radius: 18,
        child: Text(
          'No teams available for the selected hubs.',
          style: TextStyle(color: AppGlassColors.inkMuted),
        ),
      );
    }

    return AppGlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 6),
      radius: 20,
      child: Column(
        children: [
          for (final team in availableTeams)
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
              subtitle: _teamMeta(team, _allHubs),
              value: _selectedTeamIds.contains(team.id),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedTeamIds.add(team.id);
                  } else {
                    _selectedTeamIds.remove(team.id);
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  String _leagueName(String leagueId) {
    return _leagues
        .firstWhere(
          (league) => league.id == leagueId,
          orElse: () => League(
            id: leagueId,
            orgId: '',
            name: 'League',
            abbreviation: '',
            createdAt: DateTime.now(),
          ),
        )
        .name;
  }
}

class _HeaderInviteButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _HeaderInviteButton({
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppGlassSurface(
          onTap: onTap,
          width: 40,
          height: 40,
          padding: EdgeInsets.zero,
          radius: 20,
          child: const Icon(
            Icons.mail_outline,
            color: AppGlassColors.ink,
            size: 20,
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            height: 17,
            constraints: const BoxConstraints(minWidth: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppGlassColors.rose,
              shape: BoxShape.circle,
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassInviteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlassInviteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      radius: 24,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_add_outlined, color: AppGlassColors.aqua, size: 21),
          SizedBox(width: 10),
          Text(
            'Invite User',
            style: TextStyle(
              color: AppGlassColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassFilterChip extends StatelessWidget {
  final Widget label;
  final bool selected;
  final VoidCallback onSelected;

  const _GlassFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onSelected,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      radius: 20,
      settings: selected
          ? const LiquidGlassSettings(
              thickness: 38,
              blur: 7,
              glassColor: Color(0x3324DCCB),
              lightIntensity: 1.25,
              saturation: 1.2,
              refractiveIndex: 1.18,
              chromaticAberration: 0.18,
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, color: AppGlassColors.aqua, size: 16),
            const SizedBox(width: 7),
          ],
          DefaultTextStyle(
            style: TextStyle(
              color: selected ? AppGlassColors.aqua : AppGlassColors.inkMuted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              fontSize: 13,
            ),
            child: label,
          ),
        ],
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Colors.white.withValues(alpha: 0.1));
  }
}

class _GlassMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const _GlassMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppGlassColors.inkSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
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
