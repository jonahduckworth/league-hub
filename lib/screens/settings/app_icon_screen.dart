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
          const SizedBox(height: 18),
          const _SectionLabel('HOME SCREEN ICONS'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: appIconOptions.length,
            itemBuilder: (context, index) {
              final option = appIconOptions[index];
              return _IconOptionTile(
                option: option,
                isSelected: option.id == _selectedIconId,
                isEnabled: canEdit && !_isApplying && !_isLoadingCurrentIcon,
                onTap: () => setState(() => _selectedIconId = option.id),
              );
            },
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
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _AppIconPreview(option: option, size: 84),
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
                    fontSize: 22,
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

class _IconOptionTile extends StatelessWidget {
  final AppIconOption option;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _IconOptionTile({
    required this.option,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled || isSelected ? 1 : 0.58,
      child: AppGlassSurface(
        radius: 22,
        padding: const EdgeInsets.all(12),
        onTap: isEnabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _AppIconPreview(option: option, size: 58),
                if (isSelected)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppGlassColors.aqua,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppGlassColors.pageMid,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: AppGlassColors.pageTop,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              option.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isSelected ? AppGlassColors.ink : AppGlassColors.inkMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppGlassColors.inkMuted,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
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
