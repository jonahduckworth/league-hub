import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/design_system.dart';
import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/league.dart';
import '../models/schedule_event.dart';
import '../models/schedule_team_logos.dart';
import '../models/weather_snapshot.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/weather_provider.dart';
import '../services/weather_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_motion.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/dashboard_empty_schedule_state.dart';
import '../widgets/league_filter.dart';
import '../widgets/profile_summary_card.dart';
import '../widgets/schedule_game_card.dart';
import '../widgets/schedule_team_logo.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // The shared shell reserves 12pt below its 40pt header. Home uses a tighter
  // 4pt relationship between the borderless greeting row and profile card.
  static const double _compactHeaderSpacing = -AppSpacing.xs;

  String? _selectedLeagueId;

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final leaguesAsync = ref.watch(leaguesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final visibleUpcoming = ref.watch(upcomingScheduleEventsProvider);
    final scheduleTeamLogos =
        ref.watch(scheduleTeamLogosProvider).valueOrNull ??
            const ScheduleTeamLogos();

    final leagues = leaguesAsync.valueOrNull ?? [];
    final showLeagueFilter = leagues.length > 1;
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final headerLabel = headerLeague?.name ?? org?.name ?? 'League Hub';
    final topContentPadding = appShellTopPadding(
      context,
      extra: _compactHeaderSpacing,
      stickyHeight: showLeagueFilter ? 38 : 0,
    );
    final filteredUpcoming = visibleUpcoming
        .where((event) =>
            _selectedLeagueId == null ||
            event.leagueIds.contains(_selectedLeagueId))
        .toList();
    final nextGame = filteredUpcoming.firstOrNull;

    return AppShellScaffold(
      header: AppShellHeader(
        title: headerLabel,
        content: _GreetingRow(
          leagueLogoUrl: headerLeague?.logoUrl,
          leagueLabel: headerLeague?.name ?? headerLabel,
        ),
      ),
      stickyContent: showLeagueFilter
          ? LeagueFilter(
              leagues: leagues,
              selectedLeagueId: _selectedLeagueId,
              onSelected: (id) => setState(() => _selectedLeagueId = id),
            )
          : null,
      topSpacing: _compactHeaderSpacing,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppMotionReveal(
              child: _HomeProfileCard(
                user: currentUser,
                onProfileTap: () => context.go('/profile'),
              ),
            ),
            const SizedBox(height: 18),
            AppMotionReveal(
              index: 1,
              child: _NextGameCard(
                event: nextGame,
                upcomingCount: filteredUpcoming.length,
                teamLogos: scheduleTeamLogos,
                onTap: () => context.go('/schedule'),
              ),
            ),
            const SizedBox(height: 18),
            const AppMotionReveal(
              index: 2,
              child: _SectionHeading(
                icon: Icons.grid_view_rounded,
                label: 'Quick Access',
              ),
            ),
            const SizedBox(height: 12),
            AppMotionReveal(
              index: 3,
              child: _buildHomeGrid(context),
            ),
            const SizedBox(height: AppSpacing.md),
            AppMotionReveal(
              index: 4,
              child: _QuickLinksRow(
                league: headerLeague,
                fallbackLabel: headerLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CompactHomeTile(
                icon: Icons.folder_copy_outlined,
                label: 'Policy',
                subtitle: 'Files and rules',
                accentColor: AppGlassColors.aqua,
                onTap: () => context.go('/policy'),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: _WeatherHomeTile()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _CompactHomeTile(
                icon: Icons.contacts_outlined,
                label: 'Contacts',
                subtitle: 'People and roles',
                accentColor: AppGlassColors.rose,
                onTap: () => context.go('/contacts'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CompactHomeTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                subtitle: 'Profile and tools',
                accentColor: AppGlassColors.gold,
                onTap: () => context.go('/settings'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NextGameCard extends StatelessWidget {
  static const _ink = Color(0xFF061D3A);
  static const _mutedInk = Color(0xFF34516F);

  final ScheduleEvent? event;
  final int upcomingCount;
  final ScheduleTeamLogos teamLogos;
  final VoidCallback onTap;

  const _NextGameCard({
    required this.event,
    required this.upcomingCount,
    required this.teamLogos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final game = event;
    if (game != null) {
      final dateLabel = DateFormat('EEE, MMM d').format(game.scheduleDate);
      final details = [game.division, game.location]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join('  •  ');
      final semanticLabel = 'Next game, ${game.cleanFirstTeamName} versus '
          '${game.cleanSecondTeamName}, $dateLabel at '
          '${scheduleTimeLabel(game)}';

      return Semantics(
        button: true,
        label: semanticLabel,
        child: AppGlassSurface(
          key: const ValueKey('next-game-card'),
          onTap: onTap,
          radius: AppRadius.card,
          padding: EdgeInsets.zero,
          child: Stack(
            children: [
              const Positioned.fill(
                child: _DashboardCardArtwork(
                  imageKey: ValueKey('next-game-active-background'),
                  frameKey: ValueKey('next-game-active-frame'),
                  overlayKey: ValueKey('next-game-active-overlay'),
                  assetPath: 'assets/dashboard/upcoming_games_active.jpg',
                  alignment: Alignment.centerRight,
                  borderColor: Color(0x803A5875),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 190),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_available_outlined,
                            color: _ink,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Next Game',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (upcomingCount > 1)
                            Text(
                              'View all $upcomingCount',
                              style: const TextStyle(
                                color: _mutedInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: _mutedInk,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$dateLabel  •  ${scheduleTimeLabel(game)}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NextGameTeamRow(
                        name: game.cleanFirstTeamName,
                        logoUrl: teamLogos.logoFor(
                          teamId: game.firstTeamId,
                          teamName: game.firstTeamName,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _NextGameTeamRow(
                        name: game.cleanSecondTeamName,
                        logoUrl: teamLogos.logoFor(
                          teamId: game.secondTeamId,
                          teamName: game.secondTeamName,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: _mutedInk,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              details.isEmpty ? 'Game details' : details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _mutedInk,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

    final accessibilityLayout =
        DashboardEmptyScheduleState.shouldUseAccessibilityLayout(context);
    return Semantics(
      button: true,
      label: 'No upcoming games. Open schedule.',
      child: AppGlassSurface(
        key: const ValueKey('next-game-card'),
        onTap: onTap,
        radius: AppRadius.card,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Positioned.fill(
              child: _DashboardCardArtwork(
                imageKey: const ValueKey('next-game-empty-background'),
                frameKey: const ValueKey('next-game-empty-frame'),
                overlayKey: const ValueKey('next-game-empty-overlay'),
                assetPath: 'assets/dashboard/upcoming_games_empty.jpg',
                alignment: Alignment.centerRight,
                borderColor: const Color(0x803A5875),
                overlay: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: accessibilityLayout
                      ? const [
                          Color(0xEBFFFFFF),
                          Color(0xD6FFFFFF),
                          Color(0xA8FFFFFF),
                        ]
                      : const [
                          Color(0xCCFFFFFF),
                          Color(0x66FFFFFF),
                          Color(0x00FFFFFF),
                        ],
                  stops: accessibilityLayout
                      ? const [0, 0.62, 1]
                      : const [0, 0.48, 0.78],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: DashboardEmptyScheduleState(
                  accessibilityLayout: accessibilityLayout,
                  titleColor: _ink,
                  bodyColor: _mutedInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextGameTeamRow extends StatelessWidget {
  final String name;
  final String? logoUrl;

  const _NextGameTeamRow({
    required this.name,
    required this.logoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ScheduleTeamLogo(
          teamName: name,
          imageUrl: logoUrl,
          size: 30,
          fallbackTextColor: _NextGameCard._ink,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _NextGameCard._ink,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCardArtwork extends StatelessWidget {
  final Key imageKey;
  final Key frameKey;
  final Key? overlayKey;
  final String assetPath;
  final AlignmentGeometry alignment;
  final Gradient? overlay;
  final Color borderColor;
  final double borderRadius;

  const _DashboardCardArtwork({
    required this.imageKey,
    required this.frameKey,
    required this.assetPath,
    required this.alignment,
    required this.borderColor,
    this.overlayKey,
    this.overlay,
    this.borderRadius = AppRadius.card,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            assetPath,
            key: imageKey,
            fit: BoxFit.cover,
            alignment: alignment,
            filterQuality: FilterQuality.medium,
          ),
          if (overlay != null)
            DecoratedBox(
              key: overlayKey,
              decoration: BoxDecoration(gradient: overlay),
            ),
          DecoratedBox(
            key: frameKey,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeading({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppGlassColors.ink.withValues(alpha: 0.9),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _homePillTextStyle(),
          ),
        ],
      ),
    );
  }
}

TextStyle _homePillTextStyle() {
  return TextStyle(
    color: AppGlassColors.ink.withValues(alpha: 0.9),
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );
}

class _QuickLinksRow extends StatelessWidget {
  final League? league;
  final String fallbackLabel;

  const _QuickLinksRow({
    required this.league,
    required this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final label = league?.name ?? fallbackLabel;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickLinkButton(
          tooltip: 'League Website',
          url: league?.websiteUrl,
          icon: _LeagueLogoQuickLinkIcon(
            imageUrl: league?.logoUrl,
            label: label,
          ),
        ),
        _QuickLinkButton(
          tooltip: 'League Instagram',
          url: league?.instagramUrl,
          icon: const _InstagramLogoIcon(),
        ),
        _QuickLinkButton(
          tooltip: 'League X',
          url: league?.xUrl,
          icon: const _XLogoIcon(),
        ),
      ],
    );
  }
}

class _QuickLinkButton extends StatelessWidget {
  final String tooltip;
  final String? url;
  final Widget icon;

  const _QuickLinkButton({
    required this.tooltip,
    required this.url,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openLink(context),
          child: SizedBox(
            width: 58,
            height: 52,
            child: Center(
              child: Opacity(
                opacity: hasUrl ? 1 : 0.4,
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final rawUrl = url?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      AppUtils.showInfoSnackBar(context, 'Add this link in league settings');
      return;
    }

    final uri = _normaliseUrl(rawUrl);
    if (uri == null) {
      AppUtils.showErrorSnackBar(context, 'This link is not a valid URL');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      AppUtils.showErrorSnackBar(context, 'Could not open link');
    }
  }
}

class _CompactHomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _CompactHomeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      height: 136,
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeTileIcon(icon: icon, accentColor: accentColor),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppGlassColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

Uri? _normaliseUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return null;

  final withScheme = value.contains('://') ? value : 'https://$value';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  return uri;
}

class _LeagueLogoQuickLinkIcon extends StatelessWidget {
  final String? imageUrl;
  final String label;

  const _LeagueLogoQuickLinkIcon({
    required this.imageUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    if (!hasImage) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppGlassColors.aqua.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border:
              Border.all(color: AppGlassColors.aqua.withValues(alpha: 0.24)),
        ),
        child: Center(
          child: Text(
            AppUtils.getInitials(label),
            style: const TextStyle(
              color: AppGlassColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppGlassColors.aqua.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: AppGlassColors.aqua.withValues(alpha: 0.22)),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) => Center(
              child: Text(
                AppUtils.getInitials(label),
                style: const TextStyle(
                  color: AppGlassColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstagramLogoIcon extends StatelessWidget {
  const _InstagramLogoIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppGlassColors.rose, width: 2.4),
          ),
        ),
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppGlassColors.rose, width: 2),
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: AppGlassColors.rose,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _XLogoIcon extends StatelessWidget {
  const _XLogoIcon();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'X',
      style: TextStyle(
        color: AppGlassColors.ink,
        fontSize: 26,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _WeatherHomeTile extends ConsumerWidget {
  const _WeatherHomeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(currentWeatherProvider);

    return weatherAsync.when(
      data: (weather) => _WeatherTileSurface(
        onTap: () => ref.invalidate(currentWeatherProvider),
        child: _WeatherDataContent(weather: weather),
      ),
      loading: () => _WeatherTileSurface(
        onTap: () => ref.invalidate(currentWeatherProvider),
        child: const _WeatherMessageContent(
          icon: Icons.my_location_outlined,
          title: 'Weather',
          subtitle: 'Locating...',
          accentColor: AppGlassColors.aqua,
        ),
      ),
      error: (error, _) {
        final message = error is WeatherLocationException
            ? error.message
            : 'Tap to refresh';
        return _WeatherTileSurface(
          onTap: () => ref.invalidate(currentWeatherProvider),
          child: _WeatherMessageContent(
            icon: Icons.location_off_outlined,
            title: 'Weather',
            subtitle: message,
            accentColor: AppGlassColors.rose,
          ),
        );
      },
    );
  }
}

class _WeatherTileSurface extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _WeatherTileSurface({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      onTap: onTap,
      height: 136,
      padding: const EdgeInsets.all(18),
      radius: 22,
      child: child,
    );
  }
}

class _WeatherDataContent extends StatelessWidget {
  final WeatherSnapshot weather;

  const _WeatherDataContent({required this.weather});

  @override
  Widget build(BuildContext context) {
    final accentColor = _weatherAccentForCode(weather.weatherCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeTileIcon(
              icon: _weatherIconForCode(
                weather.weatherCode,
                isDay: weather.isDay,
              ),
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    weather.temperatureLabel,
                    style: const TextStyle(
                      color: AppGlassColors.ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          'Weather',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                weather.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppGlassColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              weather.windLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppGlassColors.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WeatherMessageContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;

  const _WeatherMessageContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HomeTileIcon(icon: icon, accentColor: accentColor),
        const Spacer(),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppGlassColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppGlassColors.inkMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HomeTileIcon extends StatelessWidget {
  final IconData icon;
  final Color accentColor;

  const _HomeTileIcon({
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, color: accentColor, size: 24),
    );
  }
}

IconData _weatherIconForCode(int code, {required bool isDay}) {
  if (code == 0) {
    return isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined;
  }
  if (code >= 1 && code <= 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.blur_on;
  if ((code >= 51 && code <= 57) ||
      (code >= 61 && code <= 67) ||
      (code >= 80 && code <= 82)) {
    return Icons.water_drop_outlined;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return Icons.ac_unit;
  }
  if (code >= 95) return Icons.thunderstorm;
  return Icons.cloud_outlined;
}

Color _weatherAccentForCode(int code) {
  if (code == 0) return AppGlassColors.gold;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return AppGlassColors.inkSecondary;
  }
  if (code >= 95) return AppGlassColors.rose;
  return AppGlassColors.aqua;
}

class _HomeProfileCard extends StatelessWidget {
  final AppUser? user;
  final VoidCallback onProfileTap;

  const _HomeProfileCard({
    required this.user,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return const _ProfileHeaderPlaceholder();

    return ProfileSummaryCard(
      user: user!,
      showEmail: false,
      compact: true,
      minHeight: 112,
      actionIcon: Icons.chevron_right,
      actionTooltip: 'Open profile',
      onTap: onProfileTap,
      background: const _DashboardCardArtwork(
        imageKey: ValueKey('home-profile-background'),
        frameKey: ValueKey('home-profile-frame'),
        assetPath: 'assets/dashboard/profile_hockey_arena.jpg',
        alignment: Alignment.centerRight,
        borderColor: Color(0x70FFFFFF),
        borderRadius: 21,
        overlay: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xD9071428),
            Color(0xA6081C35),
            Color(0x33020A14),
          ],
          stops: [0, 0.58, 1],
        ),
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  final String? leagueLogoUrl;
  final String leagueLabel;

  const _GreetingRow({
    required this.leagueLogoUrl,
    required this.leagueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final icon = hour < 12
        ? Icons.wb_sunny_outlined
        : hour < 17
            ? Icons.wb_sunny
            : Icons.nightlight_outlined;

    return SizedBox(
      key: const ValueKey('home-greeting-row'),
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: AppGlassColors.ink.withValues(alpha: 0.9),
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    greeting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _homePillTextStyle(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _BorderlessLeagueMark(
            imageUrl: leagueLogoUrl,
            label: leagueLabel,
          ),
        ],
      ),
    );
  }
}

class _BorderlessLeagueMark extends StatelessWidget {
  final String? imageUrl;
  final String label;

  const _BorderlessLeagueMark({
    required this.imageUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Semantics(
      image: hasImage,
      label: '$label logo',
      child: SizedBox(
        key: const ValueKey('home-header-league-mark'),
        width: 40,
        height: 40,
        child: hasImage
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => _fallback(),
                  errorWidget: (_, __, ___) => _fallback(),
                ),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Text(
        AppUtils.getInitials(label),
        style: const TextStyle(
          color: AppGlassColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ProfileHeaderPlaceholder extends StatelessWidget {
  const _ProfileHeaderPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: EdgeInsets.zero,
      radius: 21,
      child: Stack(
        children: [
          const Positioned.fill(
            child: _DashboardCardArtwork(
              imageKey: ValueKey('home-profile-background'),
              frameKey: ValueKey('home-profile-frame'),
              assetPath: 'assets/dashboard/profile_hockey_arena.jpg',
              alignment: Alignment.centerRight,
              borderColor: Color(0x70FFFFFF),
              borderRadius: 21,
              overlay: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xD9071428),
                  Color(0xA6081C35),
                  Color(0x33020A14),
                ],
                stops: [0, 0.58, 1],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Loading profile...',
                      style: TextStyle(
                        color: AppGlassColors.inkSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
