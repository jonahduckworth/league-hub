import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/league_branding.dart';
import '../../core/utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/app_icon_service.dart';
import '../../widgets/app_glass.dart';
import '../../widgets/app_shell_header.dart';
import '../../widgets/app_shell_scaffold.dart';

class AppIconScreen extends ConsumerStatefulWidget {
  const AppIconScreen({super.key});

  @override
  ConsumerState<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends ConsumerState<AppIconScreen> {
  String _selectedIconId = 'default';
  bool _supportsNativeIcons = true;
  bool _isLoadingCurrentIcon = true;
  bool _isApplying = false;

  AppIconOption get _selectedOption => appIconOptions.firstWhere(
        (option) => option.id == _selectedIconId,
        orElse: () => appIconOptions.first,
      );

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCurrentIcon);
  }

  Future<void> _loadCurrentIcon() async {
    final appIconService = ref.read(appIconServiceProvider);
    final supported = await appIconService.isSupported();
    final currentIconId = await appIconService.getCurrentIconId();

    if (!mounted) return;
    setState(() {
      _supportsNativeIcons = supported;
      _selectedIconId = currentIconId;
      _isLoadingCurrentIcon = false;
    });
  }

  Future<void> _save() async {
    final currentUser = await ref.read(currentUserProvider.future);
    if (currentUser == null) return;

    setState(() => _isApplying = true);

    try {
      await ref.read(appIconServiceProvider).setIcon(_selectedIconId);

      if (!mounted) return;
      AppUtils.showSuccessSnackBar(
        context,
        'App icon updated on this device',
      );
    } on AppIconUnsupportedException {
      if (mounted) {
        AppUtils.showErrorSnackBar(
          context,
          'App icon switching is only available on iOS and Android devices.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(context, 'Failed to update icon: $e');
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final leagues = ref.watch(leaguesProvider).valueOrNull ?? [];
    final headerLeague = resolveHeaderLeague(leagues, null);
    final canEdit = user != null;
    final topContentPadding = appShellTopPadding(context);
    final bottomContentPadding = appShellBottomPadding(context, extra: 24);

    return AppShellScaffold(
      header: AppShellHeader(
        title: 'App Icon',
        leadingIcon: Icons.apps_outlined,
        leadingImageUrl: headerLeague?.logoUrl,
        leadingLabel: headerLeague?.name ?? 'League Hub',
        showBackButton: true,
        actions: [
          if (canEdit)
            AppGlassSurface(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              radius: 20,
              onTap: _isApplying || _isLoadingCurrentIcon ? null : _save,
              child: Center(
                child: _isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppGlassColors.ink,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppGlassColors.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
        ],
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          topContentPadding,
          16,
          bottomContentPadding,
        ),
        children: [
          _PreviewCard(
            option: _selectedOption,
            isLoading: _isLoadingCurrentIcon,
            supportsNativeIcons: _supportsNativeIcons,
          ),
          const SizedBox(height: 16),
          _IconOptionsSection(
            options: appIconOptions,
            selectedIconId: _selectedIconId,
            isEnabled: canEdit && !_isApplying && !_isLoadingCurrentIcon,
            onSelected: (iconId) => setState(() => _selectedIconId = iconId),
          ),
          if (!_supportsNativeIcons) ...[
            const SizedBox(height: 18),
            const _InfoCallout(
              icon: Icons.phone_iphone_outlined,
              text:
                  'Native app icon switching works on iOS and Android devices.',
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final AppIconOption option;
  final bool isLoading;
  final bool supportsNativeIcons;

  const _PreviewCard({
    required this.option,
    required this.isLoading,
    required this.supportsNativeIcons,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _AppIconPreview(option: option, size: 72),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current icon',
                  style: TextStyle(
                    color: AppGlassColors.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLoading ? 'Checking device...' : option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  supportsNativeIcons
                      ? option.description
                      : 'Preview only on this platform',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.inkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _IconOptionsSection extends StatelessWidget {
  final List<AppIconOption> options;
  final String selectedIconId;
  final bool isEnabled;
  final ValueChanged<String> onSelected;

  const _IconOptionsSection({
    required this.options,
    required this.selectedIconId,
    required this.isEnabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'HOME SCREEN ICONS',
            style: TextStyle(
              color: AppGlassColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AppGlassSurface(
          padding: EdgeInsets.zero,
          radius: 20,
          child: Column(
            children: options.asMap().entries.map((entry) {
              final option = entry.value;
              final isLast = entry.key == options.length - 1;
              return Column(
                children: [
                  _IconOptionRow(
                    option: option,
                    isSelected: option.id == selectedIconId,
                    isEnabled: isEnabled,
                    onTap: () => onSelected(option.id),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 70,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _IconOptionRow extends StatelessWidget {
  final AppIconOption option;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _IconOptionRow({
    required this.option,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled || isSelected ? 1 : 0.58,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        leading: _AppIconPreview(option: option, size: 42),
        title: Text(
          option.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? AppGlassColors.ink : AppGlassColors.inkMuted,
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppGlassColors.aqua.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppGlassColors.aqua.withValues(alpha: 0.34),
                  ),
                ),
                child: const Icon(
                  Icons.check,
                  color: AppGlassColors.aqua,
                  size: 16,
                ),
              )
            : const Icon(
                Icons.chevron_right,
                color: AppGlassColors.inkMuted,
                size: 20,
              ),
        onTap: isEnabled ? onTap : null,
      ),
    );
  }
}

class _AppIconPreview extends StatelessWidget {
  final AppIconOption option;
  final double size;

  const _AppIconPreview({
    required this.option,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        option.assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InfoCallout extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCallout({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: AppGlassColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppGlassColors.inkSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
