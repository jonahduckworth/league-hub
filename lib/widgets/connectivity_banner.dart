import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

Future<List<InternetAddress>> defaultConnectivityBannerLookup(String host) {
  return InternetAddress.lookup(host).timeout(const Duration(seconds: 2));
}

Future<List<InternetAddress>> resolveConnectivityBannerLookup({
  required String host,
  Future<List<InternetAddress>> Function(String host)? lookup,
  Future<List<InternetAddress>> Function(String host)? fallbackLookup,
}) {
  return (lookup ?? fallbackLookup ?? defaultConnectivityBannerLookup)(host);
}

bool shouldHideOnlineBannerImmediately(bool wasOffline) => !wasOffline;

/// A banner that slides in from the top when the device loses connectivity
/// and slides out when it reconnects. Optionally shows a pending mutation count.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  /// Optional stream that emits the number of pending offline mutations.
  final Stream<int>? pendingCountStream;

  /// Initial pending count (for when the widget is first built).
  final int initialPendingCount;
  final Stream<List<ConnectivityResult>>? connectivityChanges;
  final Future<List<ConnectivityResult>> Function()? connectivityCheck;
  final Future<List<InternetAddress>> Function(String host)? internetLookup;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.pendingCountStream,
    this.initialPendingCount = 0,
    this.connectivityChanges,
    this.connectivityCheck,
    this.internetLookup,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  StreamSubscription<int>? _pendingSub;
  bool _isOffline = false;
  bool _wasOffline = false;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    final connectivity = Connectivity();
    _pendingCount = widget.initialPendingCount;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _subscription =
        (widget.connectivityChanges ?? connectivity.onConnectivityChanged)
            .listen(_onConnectivityChanged);
    // Check initial state.
    (widget.connectivityCheck ?? connectivity.checkConnectivity)
        .call()
        .then(_onConnectivityChanged);

    _pendingSub = widget.pendingCountStream?.listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    var offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);

    // connectivity_plus can report false negatives on iOS simulators.
    // Double-check with a real DNS lookup before showing the banner.
    if (offline) {
      try {
        final resolved = await resolveConnectivityBannerLookup(
          host: 'google.com',
          lookup: widget.internetLookup,
        );
        if (resolved.isNotEmpty && resolved[0].rawAddress.isNotEmpty) {
          offline = false;
        }
      } catch (_) {
        // Genuinely offline.
      }
    }

    if (!mounted) return;
    if (offline != _isOffline) {
      setState(() {
        _wasOffline = _isOffline;
        _isOffline = offline;
      });
      if (offline) {
        _animController.forward();
      } else {
        // Show "back online" briefly, then hide.
        if (_wasOffline) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && !_isOffline) _animController.reverse();
          });
        } else if (shouldHideOnlineBannerImmediately(_wasOffline)) {
          _animController.reverse();
        }
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _pendingSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  String get _bannerText {
    if (_isOffline) {
      if (_pendingCount > 0) {
        final s = _pendingCount == 1 ? '' : 's';
        return 'No internet connection — $_pendingCount change$s pending';
      }
      return 'No internet connection';
    }
    return 'Back online';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !_isOffline,
            child: SlideTransition(
              position: _slideAnimation,
              child: Material(
                elevation: 2,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 4,
                    bottom: 8,
                    left: 16,
                    right: 16,
                  ),
                  color: _isOffline ? AppColors.danger : AppColors.success,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isOffline ? Icons.wifi_off : Icons.wifi,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _bannerText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
