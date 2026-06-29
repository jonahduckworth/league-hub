import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_glass.dart';

bool isRecoverableHardwareKeyboardMismatch(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  return message.contains('KeyUpEvent is dispatched') &&
      message.contains('physical key is not pressed');
}

bool isRecoverableSnackBarLayoutError(FlutterErrorDetails details) {
  return details
      .exceptionAsString()
      .contains('Floating SnackBar presented off screen');
}

bool isRecoverableSemanticsNeedsLayout(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  return message.contains("!childSemantics.renderObject._needsLayout") ||
      message.contains("!_childSemantics.renderObject._needsLayout");
}

bool isRecoverableRenderFlexOverflow(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  return message.contains('A RenderFlex overflowed by');
}

bool isRecoverableFrameworkError(FlutterErrorDetails details) {
  return isRecoverableHardwareKeyboardMismatch(details) ||
      isRecoverableSnackBarLayoutError(details) ||
      isRecoverableSemanticsNeedsLayout(details) ||
      isRecoverableRenderFlexOverflow(details);
}

/// A widget that catches errors in its child tree and displays a
/// user-friendly fallback instead of crashing.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  FlutterErrorDetails? _errorDetails;
  FlutterExceptionHandler? _originalOnError;

  @override
  void initState() {
    super.initState();
    // Intercept Flutter framework errors.
    _originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final shouldShowFallback = !isRecoverableFrameworkError(details);
      if (mounted && shouldShowFallback) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _hasError = true;
            _errorDetails = details;
          });
        });
      }
      // Still forward to the original handler for logging.
      _originalOnError?.call(details);
    };
  }

  @override
  void dispose() {
    FlutterError.onError = _originalOnError;
    super.dispose();
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorDetails = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _ErrorFallback(
        message: _errorDetails?.exceptionAsString() ?? 'Something went wrong',
        onRetry: _retry,
      );
    }
    return widget.child;
  }
}

/// Fallback UI shown when an unhandled error occurs.
class _ErrorFallback extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorFallback({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppGlassRouteBackground(
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AppGlassSurface(
                radius: 30,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        color: AppGlassColors.rose.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppGlassColors.rose.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 38,
                        color: AppGlassColors.rose,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppGlassColors.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppGlassColors.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.12),
                          foregroundColor: AppGlassColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh, color: AppGlassColors.aqua),
                            SizedBox(width: 10),
                            Text(
                              'Try Again',
                              style: TextStyle(
                                color: AppGlassColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
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
    );
  }
}

/// Custom error widget shown by Flutter when a widget build fails.
/// Register via [ErrorWidget.builder] in main.dart.
Widget appErrorWidget(FlutterErrorDetails details) {
  return AppGlassRouteBackground(
    child: Material(
      color: Colors.transparent,
      child: Center(
        child: AppGlassSurface(
          radius: 28,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: AppGlassColors.gold,
              ),
              const SizedBox(height: 16),
              const Text(
                'Oops! Something broke.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppGlassColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppGlassColors.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
