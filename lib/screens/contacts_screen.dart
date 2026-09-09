import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/league_branding.dart';
import '../models/app_user.dart';
import '../models/hub.dart';
import '../models/league.dart';
import '../models/team.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/contact_assignment_visibility.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_states.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/glass_form_widgets.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedHubId;
  String? _selectedTeamId;
  bool _filtersExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final topContentPadding = appShellTopPadding(context);
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final usersAsync = ref.watch(orgUsersProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final hubsAsync = ref.watch(organizationHubsProvider);
    final teamsAsync = ref.watch(organizationTeamsProvider);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Contacts',
        leadingIcon: Icons.contacts_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
      ),
      child: _buildContent(
        usersAsync: usersAsync,
        currentUserAsync: currentUserAsync,
        hubsAsync: hubsAsync,
        teamsAsync: teamsAsync,
        leagues: leagues,
        topContentPadding: topContentPadding,
        bottomContentPadding: bottomContentPadding,
      ),
    );
  }

  Widget _buildContent({
    required AsyncValue<List<AppUser>> usersAsync,
    required AsyncValue<AppUser?> currentUserAsync,
    required AsyncValue<List<Hub>> hubsAsync,
    required AsyncValue<List<Team>> teamsAsync,
    required List<League> leagues,
    required double topContentPadding,
    required double bottomContentPadding,
  }) {
    if (usersAsync.hasError ||
        currentUserAsync.hasError ||
        hubsAsync.hasError ||
        teamsAsync.hasError) {
      return AppErrorState(
        title: 'Unable to load contacts',
        message: 'Check your connection and try again.',
        onRetry: () {
          ref.invalidate(orgUsersProvider);
          ref.invalidate(currentUserProvider);
          ref.invalidate(organizationHubsProvider);
          ref.invalidate(organizationTeamsProvider);
        },
      );
    }
    if (usersAsync.isLoading ||
        currentUserAsync.isLoading ||
        hubsAsync.isLoading ||
        teamsAsync.isLoading) {
      return const AppLoadingState(label: 'Loading contacts…');
    }

    final viewer = currentUserAsync.valueOrNull;
    if (viewer == null) {
      return const _ContactsMessageCard(message: 'Sign in to view contacts.');
    }

    final hubs = hubsAsync.valueOrNull ?? [];
    final teams = teamsAsync.valueOrNull ?? [];
    final directoryScope = contactDirectoryScope(
      viewer: viewer,
      hubs: hubs,
      teams: teams,
    );
    final selectedHub = _findHub(directoryScope.hubs, _selectedHubId);
    final availableTeams = _selectedHubId == null
        ? directoryScope.teams
        : directoryScope.teams
            .where((team) => team.hubId == _selectedHubId)
            .toList();
    final selectedTeam = _findTeam(availableTeams, _selectedTeamId);
    final allContacts = (usersAsync.valueOrNull ?? [])
        .where((user) => user.isActive)
        .map(
          (contact) => _VisibleContact(
            user: contact,
            assignments: visibleContactAssignments(
              viewer: viewer,
              contact: contact,
              leagues: leagues,
              hubs: hubs,
              teams: teams,
            ),
          ),
        )
        .toList()
      ..sort(
        (a, b) => a.user.displayName.toLowerCase().compareTo(
              b.user.displayName.toLowerCase(),
            ),
      );
    final normalizedQuery = _query.trim().toLowerCase();
    final contacts = allContacts.where((contact) {
      final matchesQuery = normalizedQuery.isEmpty ||
          contact.user.displayName.toLowerCase().contains(normalizedQuery) ||
          contact.assignments.hubNames.any(
            (hubName) => hubName.toLowerCase().contains(normalizedQuery),
          );
      final matchesHub = _selectedHubId == null ||
          contact.assignments.hubs.any((hub) => hub.id == _selectedHubId);
      final matchesTeam = _selectedTeamId == null ||
          contact.assignments.teams.any((team) => team.id == _selectedTeamId);
      return matchesQuery && matchesHub && matchesTeam;
    }).toList();
    final hasActiveFilters = _selectedHubId != null || _selectedTeamId != null;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        topContentPadding,
        16,
        bottomContentPadding,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ContactSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                onClear: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
            ),
            const SizedBox(width: 10),
            _ContactFilterButton(
              active: hasActiveFilters,
              expanded: _filtersExpanded,
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
            ),
          ],
        ),
        if (_filtersExpanded) ...[
          const SizedBox(height: 12),
          _ContactFilters(
            hubs: directoryScope.hubs,
            teams: availableTeams,
            selectedHubId: _selectedHubId,
            selectedTeamId: _selectedTeamId,
            onHubChanged: (hubId) {
              setState(() {
                _selectedHubId = hubId;
                if (hubId != null &&
                    directoryScope.teams.any(
                      (team) =>
                          team.id == _selectedTeamId && team.hubId != hubId,
                    )) {
                  _selectedTeamId = null;
                }
              });
            },
            onTeamChanged: (teamId) => setState(() => _selectedTeamId = teamId),
          ),
        ],
        if (hasActiveFilters) ...[
          const SizedBox(height: 10),
          _ActiveContactFilters(
            hub: selectedHub,
            team: selectedTeam,
            onClearHub: () => setState(() {
              _selectedHubId = null;
            }),
            onClearTeam: () => setState(() => _selectedTeamId = null),
            onClearAll: () => setState(() {
              _selectedHubId = null;
              _selectedTeamId = null;
            }),
          ),
        ],
        const SizedBox(height: 14),
        if (allContacts.isEmpty)
          const _ContactsMessageCard(message: 'No contacts yet.')
        else if (contacts.isEmpty)
          const _ContactsMessageCard(
            message: 'No contacts match the current search and filters.',
          )
        else
          _ContactsList(contacts: contacts),
      ],
    );
  }

  Hub? _findHub(List<Hub> hubs, String? id) {
    if (id == null) return null;
    for (final hub in hubs) {
      if (hub.id == id) return hub;
    }
    return null;
  }

  Team? _findTeam(List<Team> teams, String? id) {
    if (id == null) return null;
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }
}

class _VisibleContact {
  final AppUser user;
  final VisibleContactAssignments assignments;

  const _VisibleContact({required this.user, required this.assignments});
}

class _ContactSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ContactSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search contacts by name or shared hub',
      textField: true,
      child: AppGlassSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        radius: 22,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          cursorColor: AppGlassColors.aqua,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search contacts or hubs…',
            hintStyle: const TextStyle(color: AppGlassColors.inkMuted),
            prefixIcon: const Icon(
              Icons.search,
              color: AppGlassColors.inkSecondary,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear contact search',
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.close,
                      color: AppGlassColors.inkSecondary,
                    ),
                  ),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _ContactFilterButton extends StatelessWidget {
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _ContactFilterButton({
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      width: 52,
      height: 52,
      padding: EdgeInsets.zero,
      radius: 22,
      onTap: onTap,
      semanticLabel: expanded ? 'Hide contact filters' : 'Show contact filters',
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.tune,
            color: active ? AppGlassColors.aqua : AppGlassColors.inkSecondary,
          ),
          if (active)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppGlassColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactFilters extends StatelessWidget {
  final List<Hub> hubs;
  final List<Team> teams;
  final String? selectedHubId;
  final String? selectedTeamId;
  final ValueChanged<String?> onHubChanged;
  final ValueChanged<String?> onTeamChanged;

  const _ContactFilters({
    required this.hubs,
    required this.teams,
    required this.selectedHubId,
    required this.selectedTeamId,
    required this.onHubChanged,
    required this.onTeamChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTER CONTACTS',
            style: TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          GlassDropdownField<String>(
            value: selectedHubId,
            hintText: 'All visible hubs',
            items: hubs
                .map(
                  (hub) =>
                      DropdownMenuItem(value: hub.id, child: Text(hub.name)),
                )
                .toList(),
            onChanged: hubs.isEmpty ? null : onHubChanged,
          ),
          const SizedBox(height: 10),
          GlassDropdownField<String>(
            value: selectedTeamId,
            hintText: selectedHubId == null
                ? 'All visible teams'
                : 'All teams in selected hub',
            items: teams
                .map(
                  (team) =>
                      DropdownMenuItem(value: team.id, child: Text(team.name)),
                )
                .toList(),
            onChanged: teams.isEmpty ? null : onTeamChanged,
          ),
        ],
      ),
    );
  }
}

class _ActiveContactFilters extends StatelessWidget {
  final Hub? hub;
  final Team? team;
  final VoidCallback onClearHub;
  final VoidCallback onClearTeam;
  final VoidCallback onClearAll;

  const _ActiveContactFilters({
    required this.hub,
    required this.team,
    required this.onClearHub,
    required this.onClearTeam,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (hub != null)
          _ActiveFilterChip(
            label: hub!.name,
            semanticLabel: 'Remove ${hub!.name} hub filter',
            onTap: onClearHub,
          ),
        if (team != null)
          _ActiveFilterChip(
            label: team!.name,
            semanticLabel: 'Remove ${team!.name} team filter',
            onTap: onClearTeam,
          ),
        TextButton(onPressed: onClearAll, child: const Text('Clear filters')),
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  const _ActiveFilterChip({
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: AppGlassSurface(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        radius: 20,
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppGlassColors.aqua,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Icon(Icons.close, color: AppGlassColors.aqua, size: 17),
          ],
        ),
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  final List<_VisibleContact> contacts;

  const _ContactsList({required this.contacts});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        children: contacts.asMap().entries.map((entry) {
          final isLast = entry.key == contacts.length - 1;
          return AppMotionReveal(
            index: entry.key,
            child: Column(
              children: [
                _ContactRow(
                  contact: entry.value,
                  onTap: () => context.push('/contacts/${entry.value.user.id}'),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 76,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final _VisibleContact contact;
  final VoidCallback onTap;

  const _ContactRow({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = contact.user;
    final hubSummary = contact.assignments.hubSummary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppGlassColors.aqua.withValues(alpha: 0.08),
        highlightColor: AppGlassColors.aqua.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                size: 48,
                backgroundColor: AppGlassColors.aqua.withValues(alpha: 0.18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppGlassColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hubSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: contact.assignments.hubs.isEmpty
                            ? AppGlassColors.inkMuted
                            : AppGlassColors.aqua,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: AppGlassColors.inkSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactsMessageCard extends StatelessWidget {
  final String message;

  const _ContactsMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Text(
        message,
        style: const TextStyle(
          color: AppGlassColors.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
