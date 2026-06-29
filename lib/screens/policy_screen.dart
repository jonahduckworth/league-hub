import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/league_branding.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/app_user.dart';
import '../models/policy.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/permission_service.dart';
import '../widgets/app_glass.dart';
import '../widgets/app_shell_header.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/league_filter.dart';

class PolicyScreen extends ConsumerStatefulWidget {
  const PolicyScreen({super.key});

  @override
  ConsumerState<PolicyScreen> createState() => _PolicyScreenState();
}

List<String> buildVisiblePolicyCategories(List<Policy> policies) {
  final existingCategories = policies.map((policy) => policy.category).toSet();
  return [
    'All',
    ..._policyCategories.where(existingCategories.contains),
  ];
}

const _policyCategories = [
  'Policy',
  'Protocol',
  'Code of Conduct',
  'Other',
];

class _PolicyScreenState extends ConsumerState<PolicyScreen> {
  bool _canUpload(AppUser? user) {
    if (user == null) return false;
    return PermissionService.isAtLeast(user.role, UserRole.managerAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final bottomContentPadding = appShellBottomPadding(context);
    final policiesAsync = ref.watch(policiesProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final selectedLeagueId = ref.watch(selectedLeagueProvider);
    final selectedCategory = ref.watch(selectedPolicyCategoryProvider);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final leagues = leaguesAsync.valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, selectedLeagueId);
    final showLeagueFilter = leagues.length > 1;
    final visibleCategories =
        buildVisiblePolicyCategories(policiesAsync.valueOrNull ?? const []);
    final stickyHeight = showLeagueFilter ? 82.0 : 36.0;
    final topContentPadding = appShellTopPadding(
      context,
      stickyHeight: stickyHeight,
    );

    return AppShellScaffold(
      floatingActionButton: _canUpload(currentUser)
          ? AppGlassFloatingActionButton(
              icon: Icons.add,
              tooltip: 'Upload policy',
              onTap: () => context.push('/policy/upload'),
            )
          : null,
      header: AppShellHeader(
        leadingIcon: Icons.folder_copy_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        title: 'Policy',
      ),
      stickyContent: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeagueFilter) ...[
            LeagueFilter(
              leagues: leagues,
              selectedLeagueId: selectedLeagueId,
              onSelected: (id) =>
                  ref.read(selectedLeagueProvider.notifier).state = id,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: visibleCategories
                  .map((cat) => _CategoryChip(
                        label: cat,
                        isSelected: selectedCategory == cat,
                        onTap: () => ref
                            .read(selectedPolicyCategoryProvider.notifier)
                            .state = cat,
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
      child: policiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (policies) {
          final filtered = policies;

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.folder_open,
              title: 'No policies found',
              action: _canUpload(currentUser)
                  ? ElevatedButton.icon(
                      onPressed: () => context.push('/policy/upload'),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Policy'),
                    )
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(policiesProvider),
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                  16, topContentPadding, 16, bottomContentPadding),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _PolicyTile(
                policy: filtered[index],
                leagues: leagues,
                onTap: () => context.push('/policy/${filtered[index].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PolicyGlassBadge(
      label: label,
      color: isSelected ? AppGlassColors.aqua : AppGlassColors.inkMuted,
      horizontalPadding: 16,
      verticalPadding: 10,
      fontSize: 13,
      minWidth: label == 'All' ? 60 : null,
      radius: 18,
      margin: const EdgeInsets.only(right: 8),
      onTap: onTap,
    );
  }
}

class _PolicyTile extends StatelessWidget {
  final Policy policy;
  final List<League> leagues;
  final VoidCallback onTap;

  const _PolicyTile({
    required this.policy,
    required this.leagues,
    required this.onTap,
  });

  IconData get _fileIcon {
    switch (policy.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get _fileColor {
    switch (policy.fileType.toLowerCase()) {
      case 'pdf':
        return AppColors.danger;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return AppColors.success;
      case 'docx':
      case 'doc':
        return AppColors.primaryLight;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String? get _leagueName {
    if (policy.leagueId == null) return null;
    return leagues
        .where((l) => l.id == policy.leagueId)
        .map((l) => l.abbreviation)
        .firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final versionCount = policy.versions.isEmpty ? 1 : policy.versions.length;
    final leagueName = _leagueName;

    return AppGlassSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      radius: 24,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _fileColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _fileColor.withValues(alpha: 0.28)),
            ),
            child: Icon(_fileIcon, color: _fileColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppGlassColors.ink,
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PolicyGlassBadge(
                      label: policy.category,
                      color: AppGlassColors.aqua,
                    ),
                    if (leagueName != null)
                      _PolicyGlassBadge(
                        label: leagueName,
                        color: AppGlassColors.gold,
                      ),
                    _PolicyGlassBadge(
                      label:
                          '${policy.fileType.toUpperCase()} • ${AppUtils.formatFileSize(policy.fileSize)}',
                      color: AppGlassColors.inkMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppUtils.formatDateTime(policy.updatedAt),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppGlassColors.inkMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'v$versionCount',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppGlassColors.inkSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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

class _PolicyGlassBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  final double? minWidth;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const _PolicyGlassBadge({
    required this.label,
    required this.color,
    this.horizontalPadding = 9,
    this.verticalPadding = 6,
    this.fontSize = 11,
    this.minWidth,
    this.radius = 12,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: FontWeight.w700,
      height: 1,
    );
    return AppGlassSurface(
      margin: margin,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      radius: radius,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth ?? 0),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}
