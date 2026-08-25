import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/design_system.dart';
import '../services/app_update_service.dart';
import 'app_glass.dart';

class MandatoryUpdateCoordinator extends StatefulWidget {
  final Widget child;
  final AppUpdateService? updateService;
  final Stream<List<ConnectivityResult>>? connectivityChanges;

  const MandatoryUpdateCoordinator({
    super.key,
    required this.child,
    this.updateService,
    this.connectivityChanges,
  });

  @override
  State<MandatoryUpdateCoordinator> createState() =>
      _MandatoryUpdateCoordinatorState();
}

class _MandatoryUpdateCoordinatorState extends State<MandatoryUpdateCoordinator>
    with WidgetsBindingObserver {
  late final AppUpdateService _updateService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  AppUpdateCheckResult? _requiredUpdate;
  bool _isChecking = false;
  bool _isLaunching = false;
  String? _launchError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateService = widget.updateService ?? StoreAppUpdateService();
    _connectivitySubscription =
        (widget.connectivityChanges ?? Connectivity().onConnectivityChanged)
            .listen(_handleConnectivityChange);
    Future<void>.microtask(_checkForUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (isOnline) _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      final result = await _updateService.checkForUpdate();
      if (!mounted) return;
      if (result.status == AppUpdateStatus.updateRequired) {
        setState(() {
          _requiredUpdate = result;
          _launchError = null;
        });
      } else if (result.status == AppUpdateStatus.upToDate &&
          _requiredUpdate != null) {
        setState(() {
          _requiredUpdate = null;
          _launchError = null;
        });
      }
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _launchUpdate() async {
    final update = _requiredUpdate;
    if (update == null || _isLaunching) return;
    setState(() {
      _isLaunching = true;
      _launchError = null;
    });

    final launched = await _updateService.launchUpdate(update);
    if (!mounted) return;
    setState(() {
      _isLaunching = false;
      if (!launched) {
        _launchError = 'The store could not be opened. Please try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = _requiredUpdate;
    if (update == null) return widget.child;

    return PopScope(
      canPop: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(child: IgnorePointer(child: widget.child)),
          const ModalBarrier(dismissible: false, color: Color(0xA6000000)),
          SafeArea(
            minimum: const EdgeInsets.all(AppSpacing.xl),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Semantics(
                    scopesRoute: true,
                    explicitChildNodes: true,
                    label: 'Update required',
                    child: AppGlassSurface(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      radius: 30,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppGlassColors.aqua.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.card,
                                ),
                                border: Border.all(
                                  color: AppGlassColors.aqua.withValues(
                                    alpha: 0.34,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                Icons.system_update_alt_rounded,
                                color: AppGlassColors.aqua,
                                size: 32,
                                semanticLabel: 'Software update',
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const Text(
                            'Update required',
                            style: TextStyle(
                              color: AppGlassColors.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'A newer version is available and is required to '
                            'continue. Update now to get the latest features, '
                            'improvements, and fixes.',
                            style: TextStyle(
                              color: AppGlassColors.inkSecondary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                          if (_launchError != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _launchError!,
                                style: const TextStyle(
                                  color: AppGlassColors.rose,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          FilledButton.icon(
                            onPressed: _isLaunching ? null : _launchUpdate,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppGlassColors.aqua,
                              foregroundColor: AppGlassColors.pageTop,
                              disabledBackgroundColor: AppGlassColors.aqua
                                  .withValues(alpha: 0.48),
                              disabledForegroundColor: AppGlassColors.pageTop
                                  .withValues(alpha: 0.72),
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
                              ),
                            ),
                            icon: _isLaunching
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: AppGlassColors.pageTop,
                                    ),
                                  )
                                : const Icon(Icons.open_in_new_rounded),
                            label: Text(
                              _isLaunching ? 'Opening store…' : 'Update now',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
