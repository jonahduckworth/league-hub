import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

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
      if (mounted) {
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
    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
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
  return Material(
    color: AppColors.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text('Oops! Something broke.',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text)),
            const SizedBox(height: 8),
            Text(
              details.exceptionAsString(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ),
  );
}
