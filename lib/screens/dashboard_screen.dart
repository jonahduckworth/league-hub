import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/league_branding.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/league.dart';
import '../models/weather_snapshot.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/weather_provider.dart';
import '../services/weather_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/league_filter.dart';
import '../widgets/profile_summary_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const double _homeHeaderExtraSpacing = 8;
  static const double _bottomNavBottomInset = 12;
  static const double _quickLinksHeight = 52;
  static const double _quickLinksContentGap = 12;
  static const double _quickLinksNavGap = 40;

  String? _selectedLeagueId;

  @override
  Widget build(BuildContext context) {
    final quickLinksBottomOffset = MediaQuery.viewPaddingOf(context).bottom +
        leagueHubGlassBottomNavBarHeight +
        _bottomNavBottomInset +
        _quickLinksNavGap;
    final bottomContentPadding =
        quickLinksBottomOffset + _quickLinksHeight + _quickLinksContentGap;
    final leaguesAsync = ref.watch(leaguesProvider);
    final org = ref.watch(organizationProvider).valueOrNull;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;

    final leagues = leaguesAsync.valueOrNull ?? [];
    final showLeagueFilter = leagues.length > 1;
    final headerLeague = resolveHeaderLeague(leagues, _selectedLeagueId);
    final headerLabel = headerLeague?.name ?? org?.name ?? 'League Hub';
    final topContentPadding = appShellTopPadding(
      context,
      extra: _homeHeaderExtraSpacing,
      stickyHeight: showLeagueFilter ? 38 : 0,
    );

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
      topSpacing: _homeHeaderExtraSpacing,
      child: Stack(
        children: [
          Positioned.fill(
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
                  _HomeProfileCard(
                    user: currentUser,
                    onProfileTap: () => context.go('/profile'),
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeading(
                    icon: Icons.grid_view_rounded,
                    label: 'Quick Access',
                  ),
                  const SizedBox(height: 12),
                  _buildHomeGrid(context),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: quickLinksBottomOffset,
            child: _QuickLinksRow(
              league: headerLeague,
              fallbackLabel: headerLabel,
            ),
          ),
        ],
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
              icon: _weatherIconForCode(weather.weatherCode),
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

IconData _weatherIconForCode(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code >= 1 && code <= 3) return Icons.cloud;
  if (code == 45 || code == 48) return Icons.blur_on;
  if ((code >= 51 && code <= 57) ||
      (code >= 61 && code <= 67) ||
      (code >= 80 && code <= 82)) {
    return Icons.water_drop_outlined;
  }
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 95) return Icons.thunderstorm;
  return Icons.cloud_outlined;
}

Color _weatherAccentForCode(int code) {
  if (code == 0) return AppGlassColors.gold;
  if (code >= 71 && code <= 77) return AppGlassColors.inkSecondary;
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
      actionIcon: Icons.chevron_right,
      actionTooltip: 'Open profile',
      onTap: onProfileTap,
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppHeaderPill(
              text: greeting,
              icon: icon,
              iconSize: 18,
              showIconBubble: false,
              padding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
              textStyle: _homePillTextStyle(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        AppHeaderLogoMark(
          imageUrl: leagueLogoUrl,
          label: leagueLabel,
          size: 40,
        ),
      ],
    );
  }
}

class _ProfileHeaderPlaceholder extends StatelessWidget {
  const _ProfileHeaderPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: const EdgeInsets.all(16),
      radius: 21,
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
    );
  }
}
