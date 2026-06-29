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
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/profile_summary_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.valueOrNull;
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final assignments = user == null
        ? null
        : _ProfileAssignmentDetailsData.resolve(
            ref: ref,
            user: user,
            leagues: leagues,
          );
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Profile',
        leadingIcon: Icons.person_outline_rounded,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, topContentPadding, 16, bottomContentPadding),
        children: [
          if (user == null)
            _ProfileLoadingCard(
              isLoading: userAsync.isLoading,
              error: userAsync.error,
            )
          else ...[
            ProfileSummaryCard(
              user: user,
              showEmail: false,
              compact: true,
              actionIcon: Icons.edit_outlined,
              actionTooltip: 'Edit profile',
              onTap: () => context.push('/profile/edit'),
              onActionTap: () => context.push('/profile/edit'),
            ),
            const SizedBox(height: 18),
            if (assignments != null) ...[
              _ProfileLeagueDetails(assignments: assignments),
              const SizedBox(height: 18),
            ],
            _ProfileContactDetails(user: user),
          ],
        ],
      ),
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  final bool isLoading;
  final Object? error;

  const _ProfileLoadingCard({
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final message = error != null
        ? 'Unable to load your profile.'
        : isLoading
            ? 'Loading profile...'
            : 'Profile setup is still finishing.';

    return AppGlassSurface(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Row(
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppGlassColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAssignmentDetailsData {
  final List<String> leagueNames;
  final List<String> hubNames;
  final List<String> teamNames;

  const _ProfileAssignmentDetailsData({
    required this.leagueNames,
    required this.hubNames,
    required this.teamNames,
  });

  static _ProfileAssignmentDetailsData resolve({
    required WidgetRef ref,
    required AppUser user,
    required List<League> leagues,
  }) {
    final hubs = <Hub>[];
    for (final league in leagues) {
      hubs.addAll(
        ref.watch(hubsProvider(league.id)).valueOrNull ?? const <Hub>[],
      );
    }

    final teams = <Team>[];
    for (final hub in hubs) {
      teams.addAll(
        ref
                .watch(teamsProvider((leagueId: hub.leagueId, hubId: hub.id)))
                .valueOrNull ??
            const <Team>[],
      );
    }

    final selectedTeams =
        teams.where((team) => user.teamIds.contains(team.id)).toList();
    final selectedHubs = hubs
        .where(
          (hub) =>
              user.hubIds.contains(hub.id) ||
              selectedTeams.any((team) => team.hubId == hub.id),
        )
        .toList();
    final leagueIds = <String>{
      ...user.leagueIds,
      ...selectedHubs.map((hub) => hub.leagueId),
      ...selectedTeams.map((team) => team.leagueId),
    };

    return _ProfileAssignmentDetailsData(
      leagueNames: leagues
          .where((league) => leagueIds.contains(league.id))
          .map((league) => league.name)
          .toList(),
      hubNames: selectedHubs.map((hub) => hub.name).toList(),
      teamNames: selectedTeams.map((team) => team.name).toList(),
    );
  }
}

class _ProfileLeagueDetails extends StatelessWidget {
  final _ProfileAssignmentDetailsData assignments;

  const _ProfileLeagueDetails({required this.assignments});

  @override
  Widget build(BuildContext context) {
    return _ProfileSectionShell(
      title: 'League Details',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ProfileContactRow(
              icon: Icons.shield_outlined,
              label: 'League',
              value: _joinedOrFallback(
                assignments.leagueNames,
                'No league assigned',
              ),
            ),
            const SizedBox(height: 14),
            _ProfileContactRow(
              icon: Icons.location_city_outlined,
              label: 'Hub',
              value: _joinedOrFallback(assignments.hubNames, 'No hub assigned'),
            ),
            const SizedBox(height: 14),
            _ProfileContactRow(
              icon: Icons.groups_outlined,
              label: 'Team',
              value:
                  _joinedOrFallback(assignments.teamNames, 'No team assigned'),
            ),
          ],
        ),
      ),
    );
  }

  String _joinedOrFallback(List<String> values, String fallback) {
    if (values.isEmpty) return fallback;
    return values.join(', ');
  }
}

class _ProfileContactDetails extends StatelessWidget {
  final AppUser user;

  const _ProfileContactDetails({required this.user});

  @override
  Widget build(BuildContext context) {
    final hasDetails = user.phone != null || user.address != null;

    return _ProfileSectionShell(
      title: 'Contact',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hasDetails
            ? Column(
                children: [
                  if (user.phone != null)
                    _ProfileContactRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: user.phone!,
                    ),
                  if (user.phone != null && user.address != null)
                    const SizedBox(height: 14),
                  if (user.address != null)
                    _ProfileContactRow(
                      icon: Icons.location_on_outlined,
                      label: 'Address',
                      value: user.address!,
                    ),
                ],
              )
            : const Text(
                'No contact details shared yet.',
                style: TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _ProfileContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 36,
          child: Center(
            child: Icon(icon, color: AppGlassColors.aqua, size: 21),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppGlassColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSectionShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _ProfileSectionShell({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppGlassColors.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AppGlassSurface(
          padding: EdgeInsets.zero,
          radius: 20,
          child: child,
        ),
      ],
    );
  }
}
