import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class ContactProfileScreen extends ConsumerWidget {
  final String userId;

  const ContactProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(orgUsersProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final hubsAsync = ref.watch(organizationHubsProvider);
    final teamsAsync = ref.watch(organizationTeamsProvider);
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'Profile',
        leadingIcon: Icons.person_outline_rounded,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        backFallbackLocation: '/contacts',
      ),
      child: _buildContent(
        ref: ref,
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
    required WidgetRef ref,
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
        title: 'Unable to load profile',
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
      return const AppLoadingState(label: 'Loading profile…');
    }

    final contact = _findContact(usersAsync.valueOrNull ?? const []);
    final viewer = currentUserAsync.valueOrNull;
    final assignments = contact == null || viewer == null
        ? null
        : visibleContactAssignments(
            viewer: viewer,
            contact: contact,
            leagues: leagues,
            hubs: hubsAsync.valueOrNull ?? const [],
            teams: teamsAsync.valueOrNull ?? const [],
          );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        topContentPadding,
        16,
        bottomContentPadding,
      ),
      children: [
        if (contact == null || viewer == null)
          _ContactMessageCard(
            message: viewer == null
                ? 'Sign in to view this profile.'
                : 'Profile not found.',
          )
        else ...[
          AppMotionReveal(child: _ContactProfileHero(user: contact)),
          const SizedBox(height: 16),
          if (assignments != null) ...[
            AppMotionReveal(
              index: 1,
              child: _ContactLeagueDetails(assignments: assignments),
            ),
            const SizedBox(height: 16),
          ],
          AppMotionReveal(index: 2, child: _ContactDetailsCard(user: contact)),
        ],
      ],
    );
  }

  AppUser? _findContact(List<AppUser> users) {
    for (final user in users) {
      if (user.id == userId && user.isActive) return user;
    }
    return null;
  }
}

class _ContactProfileHero extends StatelessWidget {
  final AppUser user;

  const _ContactProfileHero({required this.user});

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.all(22),
      radius: 26,
      child: Row(
        children: [
          AvatarWidget(
            name: user.displayName,
            imageUrl: user.avatarUrl,
            size: 72,
            backgroundColor: AppGlassColors.aqua.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.title ?? 'No title set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: user.title == null
                        ? AppGlassColors.inkMuted
                        : AppGlassColors.aqua,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class _ContactLeagueDetails extends StatelessWidget {
  final VisibleContactAssignments assignments;

  const _ContactLeagueDetails({required this.assignments});

  @override
  Widget build(BuildContext context) {
    return _ContactSectionCard(
      title: 'League Details',
      child: Column(
        children: [
          _ContactInfoRow(
            icon: Icons.shield_outlined,
            label: 'League',
            value: _joinedOrFallback(
              assignments.leagues.map((league) => league.name).toList(),
              assignments.hasHiddenLeagues
                  ? 'No shared league'
                  : 'No league assigned',
            ),
          ),
          const SizedBox(height: 14),
          _ContactInfoRow(
            icon: Icons.location_city_outlined,
            label: 'Hub',
            value: _joinedOrFallback(
              assignments.hubs.map((hub) => hub.name).toList(),
              assignments.hasHiddenHubs ? 'No shared hub' : 'No hub assigned',
            ),
          ),
          const SizedBox(height: 14),
          _ContactInfoRow(
            icon: Icons.groups_outlined,
            label: 'Team',
            value: _joinedOrFallback(
              assignments.teams.map((team) => team.name).toList(),
              assignments.hasHiddenTeams
                  ? 'No shared team'
                  : 'No team assigned',
            ),
          ),
        ],
      ),
    );
  }

  String _joinedOrFallback(List<String> values, String fallback) {
    if (values.isEmpty) return fallback;
    return values.join(', ');
  }
}

class _ContactDetailsCard extends StatelessWidget {
  final AppUser user;

  const _ContactDetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _ContactSectionCard(
      title: 'Contact',
      child: Column(
        children: [
          _ContactInfoRow(
            icon: Icons.email_outlined,
            label: 'Email address',
            value: user.email,
          ),
          if (user.phone != null) ...[
            const SizedBox(height: 14),
            _ContactInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ContactSectionCard({required this.title, required this.child});

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
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppGlassColors.inkMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _ContactInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppGlassColors.aqua.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppGlassColors.aqua, size: 18),
        ),
        const SizedBox(width: 12),
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

class _ContactMessageCard extends StatelessWidget {
  final String message;

  const _ContactMessageCard({required this.message});

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
