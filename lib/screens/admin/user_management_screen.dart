import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../models/hub.dart';
import '../../models/invitation.dart';
import '../../models/league.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar_widget.dart';

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

  static const _roleFilters = ['All', 'Super Admin', 'Manager Admin', 'Staff'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> _filtered(List<AppUser> users) {
    return users.where((u) {
      final matchesSearch = _searchQuery.isEmpty ||
          u.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _roleFilter == 'All' || u.roleLabel == _roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(orgUsersProvider);
    final pendingCount = ref.watch(pendingInviteCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.mail_outline),
                    onPressed: () => _showInvitationsSheet(context),
                    tooltip: 'Pending Invites',
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: usersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading users: $e')),
              data: (users) {
                final filtered = _filtered(users);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64,
                            color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No users found',
                            style: TextStyle(
                                fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _UserCard(user: filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteSheet(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text('Invite User',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search by name or email…',
          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _roleFilters.map((label) {
          final selected = _roleFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _roleFilter = label),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InviteUserSheet(),
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

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.platformOwner:
        return const Color(0xFF7C3AED);
      case UserRole.superAdmin:
        return AppColors.primary;
      case UserRole.managerAdmin:
        return AppColors.accent;
      case UserRole.staff:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/settings/users/${user.id}'),
      onLongPress: () => _showDeactivateDialog(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: user.isActive ? AppColors.border : AppColors.danger.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                AvatarWidget(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                  size: 48,
                  backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
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
                            fontWeight: FontWeight.w600,
                            color: user.isActive
                                ? AppColors.text
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                      _RoleBadge(
                          label: user.roleLabel,
                          color: _roleColor(user.role)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  if (user.hubIds.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user.hubIds.length} hub${user.hubIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                  if (!user.isActive) ...[
                    const SizedBox(height: 4),
                    const Text('Inactive',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref) {
    final action = user.isActive ? 'Deactivate' : 'Reactivate';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$action User'),
        content: Text(
          user.isActive
              ? 'Deactivate ${user.displayName}? They will lose access to the app.'
              : 'Reactivate ${user.displayName}? They will regain access.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  user.isActive ? AppColors.danger : AppColors.success,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final svc = ref.read(firestoreServiceProvider);
              if (user.isActive) {
                await svc.deactivateUser(user.id);
              } else {
                await svc.reactivateUser(user.id);
              }
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// --- Pending Invitations Sheet ---

class _PendingInvitationsSheet extends ConsumerWidget {
  const _PendingInvitationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(invitationsProvider);
    final pending = (invitationsAsync.valueOrNull ?? [])
        .where((i) => i.status == InvitationStatus.pending)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Pending Invitations',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: pending.isEmpty
                  ? const Center(
                      child: Text('No pending invitations',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _InvitationTile(invite: pending[i]),
                    ),
            ),
          ],
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: const CircleAvatar(
        backgroundColor: AppColors.accent,
        child: Icon(Icons.mail_outline, color: Colors.white, size: 20),
      ),
      title: Text(invite.email,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${invite.roleLabel} · Invited by ${invite.invitedByName}'),
      trailing: IconButton(
        icon: const Icon(Icons.copy, color: AppColors.textMuted),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: invite.token));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invite code copied!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        tooltip: 'Copy invite code',
      ),
    );
  }
}

// --- Invite User Sheet ---

class _InviteUserSheet extends ConsumerStatefulWidget {
  const _InviteUserSheet();

  @override
  ConsumerState<_InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends ConsumerState<_InviteUserSheet> {
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'staff';
  final Set<String> _selectedHubIds = {};
  bool _isLoading = false;
  bool _hubsLoading = true;
  List<League> _leagues = [];
  List<Hub> _allHubs = [];

  @override
  void initState() {
    super.initState();
    _loadHubs();
  }

  Future<void> _loadHubs() async {
    final org = ref.read(organizationProvider).valueOrNull;
    if (org == null) {
      setState(() => _hubsLoading = false);
      return;
    }
    final svc = ref.read(firestoreServiceProvider);
    final leagues = await svc.getLeagues(org.id).first;
    final hubs = await svc.getAllHubsFlat(org.id);
    if (mounted) {
      setState(() {
        _leagues = leagues;
        _allHubs = hubs;
        _hubsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email is required'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final org = ref.read(organizationProvider).valueOrNull;
      final currentUser = await ref.read(currentUserProvider.future);
      if (org == null || currentUser == null) return;

      final svc = ref.read(firestoreServiceProvider);
      final invitation = Invitation(
        id: '',
        orgId: org.id,
        email: email,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        role: _selectedRole,
        hubIds: _selectedHubIds.toList(),
        teamIds: [],
        invitedBy: currentUser.id,
        invitedByName: currentUser.displayName,
        createdAt: DateTime.now(),
        status: InvitationStatus.pending,
        token: '',
      );

      final token = await svc.createInvitation(org.id, invitation);
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context, token);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invite: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(BuildContext context, String token) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invitation Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Share this invite code with the user. They can enter it on the Accept Invitation screen.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      token,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text('Invite User',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name (optional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Role',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    _buildRolePicker(),
                    const SizedBox(height: 20),
                    const Text('Hub Access',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    _buildHubPicker(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendInvite,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Send Invite',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePicker() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        children: [
          RadioGroup<String>(
            groupValue: _selectedRole,
            onChanged: (v) => setState(() {
              if (v != null) _selectedRole = v;
            }),
            child: Column(
              children: [
                _RoleOption(
                  label: 'Manager Admin',
                  description: 'Can manage hubs, teams, and staff',
                  value: 'managerAdmin',
                ),
                const Divider(height: 1),
                _RoleOption(
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
        child: CircularProgressIndicator(),
      ));
    }
    if (_allHubs.isEmpty) {
      return const Text('No hubs available',
          style: TextStyle(color: AppColors.textMuted));
    }

    final hubsByLeague = <String, List<Hub>>{};
    for (final hub in _allHubs) {
      hubsByLeague.putIfAbsent(hub.leagueId, () => []).add(hub);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in hubsByLeague.entries) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _leagues
                    .firstWhere((l) => l.id == entry.key,
                        orElse: () => League(
                            id: entry.key,
                            orgId: '',
                            name: 'League',
                            abbreviation: '',
                            createdAt: DateTime.now()))
                    .name,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5),
              ),
            ),
            for (final hub in entry.value)
              CheckboxListTile(
                dense: true,
                title: Text(hub.name),
                subtitle: hub.location != null ? Text(hub.location!) : null,
                value: _selectedHubIds.contains(hub.id),
                activeColor: AppColors.primary,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedHubIds.add(hub.id);
                    } else {
                      _selectedHubIds.remove(hub.id);
                    }
                  });
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String description;
  final String value;

  const _RoleOption({
    required this.label,
    required this.description,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(description,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      value: value,
      activeColor: AppColors.primary,
    );
  }
}
