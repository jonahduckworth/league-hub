import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design_system.dart';
import '../core/utils.dart';
import '../models/league.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../services/app_icon_prompt_preferences.dart';
import '../services/app_icon_service.dart';
import 'app_glass.dart';

const _targetIconId = 'jphl';

bool hasJphlLeague(Iterable<League> leagues) {
  return leagues.any(_isJphlLeague);
}

bool _isJphlLeague(League league) {
  final id = league.id.trim().toLowerCase();
  final abbreviation = league.abbreviation.trim().toUpperCase();
  final name = league.name.trim().toLowerCase();
  return id == 'jphl' ||
      abbreviation == 'JPHL' ||
      name == 'junior prospects hockey league';
}

class AppIconPromptCoordinator extends ConsumerStatefulWidget {
  final Widget child;

  const AppIconPromptCoordinator({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AppIconPromptCoordinator> createState() =>
      _AppIconPromptCoordinatorState();
}

class _AppIconPromptCoordinatorState
    extends ConsumerState<AppIconPromptCoordinator> {
  String? _lastEvaluationKey;
  bool _isEvaluating = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final leaguesAsync = ref.watch(leaguesProvider);
    final user = userAsync.valueOrNull;
    final leagues = leaguesAsync.valueOrNull;

    if (user != null && leagues != null) {
      final jphlLeagueIds = leagues
          .where(_isJphlLeague)
          .map((league) => league.id)
          .toList()
        ..sort();
      final evaluationKey = '${user.id}:${jphlLeagueIds.join(',')}';

      if (_lastEvaluationKey != evaluationKey && !_isEvaluating) {
        _lastEvaluationKey = evaluationKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _evaluate(
            userId: user.id,
            isJphlUser: jphlLeagueIds.isNotEmpty,
          );
        });
      }
    }

    return widget.child;
  }

  Future<void> _evaluate({
    required String userId,
    required bool isJphlUser,
  }) async {
    if (_isEvaluating || !isJphlUser) return;
    _isEvaluating = true;

    try {
      final iconService = ref.read(appIconServiceProvider);
      if (!await iconService.isSupported()) return;
      if (await iconService.getCurrentIconId() == _targetIconId) return;

      final preferences = ref.read(appIconPromptPreferencesProvider);
      final suppressed = await preferences.isSuppressed(
        userId: userId,
        iconId: _targetIconId,
        campaign: jphlAppIconPromptCampaign,
      );
      if (suppressed || !mounted) return;

      final result = await _showJphlAppIconPrompt(context);
      if (result == null || !mounted) return;

      if (result.action == _AppIconPromptAction.useJphlIcon) {
        await iconService.setIcon(_targetIconId);
        await preferences.dismissForCampaign(
          userId: userId,
          iconId: _targetIconId,
          campaign: jphlAppIconPromptCampaign,
        );
        if (mounted) {
          AppUtils.showSuccessSnackBar(context, 'JPHL app icon selected');
        }
        return;
      }

      if (result.neverAskAgain) {
        await preferences.neverAskAgain(
          userId: userId,
          iconId: _targetIconId,
        );
      } else {
        await preferences.dismissForCampaign(
          userId: userId,
          iconId: _targetIconId,
          campaign: jphlAppIconPromptCampaign,
        );
      }
    } catch (_) {
      if (mounted) {
        AppUtils.showErrorSnackBar(
          context,
          'The app icon could not be changed. You can try again in Settings.',
        );
      }
    } finally {
      _isEvaluating = false;
    }
  }
}

enum _AppIconPromptAction { useJphlIcon, notNow }

class _AppIconPromptResult {
  final _AppIconPromptAction action;
  final bool neverAskAgain;

  const _AppIconPromptResult({
    required this.action,
    this.neverAskAgain = false,
  });
}

Future<_AppIconPromptResult?> _showJphlAppIconPrompt(BuildContext context) {
  var neverAskAgain = false;

  return showDialog<_AppIconPromptResult>(
    context: context,
    barrierDismissible: false,
    animationStyle: AppMotion.overlayStyle(context),
    barrierColor: Colors.black.withValues(alpha: 0.58),
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SafeArea(
          child: AppGlassSurface(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            radius: 30,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/app_icons/jphl.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Semantics(
                    header: true,
                    child: const Text(
                      'Use the JPHL app icon?',
                      style: TextStyle(
                        color: AppGlassColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Switch League Hub to the JPHL icon on this device. '
                    'You can change it anytime in Settings.',
                    style: TextStyle(
                      color: AppGlassColors.inkSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  MergeSemantics(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setDialogState(
                        () => neverAskAgain = !neverAskAgain,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: neverAskAgain,
                              onChanged: (value) => setDialogState(
                                () => neverAskAgain = value ?? false,
                              ),
                              activeColor: AppGlassColors.aqua,
                              checkColor: AppGlassColors.pageTop,
                            ),
                            const SizedBox(width: 4),
                            const Expanded(
                              child: Text(
                                'Don\'t ask again on this device',
                                style: TextStyle(
                                  color: AppGlassColors.inkSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            _AppIconPromptResult(
                              action: _AppIconPromptAction.notNow,
                              neverAskAgain: neverAskAgain,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppGlassColors.inkSecondary,
                            minimumSize: const Size(44, 44),
                          ),
                          child: const Text('Not Now'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            const _AppIconPromptResult(
                              action: _AppIconPromptAction.useJphlIcon,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppGlassColors.aqua,
                            foregroundColor: AppGlassColors.pageTop,
                            minimumSize: const Size(44, 44),
                          ),
                          child: const Text('Use JPHL Icon'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
