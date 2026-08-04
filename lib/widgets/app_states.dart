import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'app_glass.dart';
import 'app_motion.dart';
import 'empty_state.dart';

class AppLoadingState extends StatelessWidget {
  final String label;

  const AppLoadingState({
    super.key,
    this.label = 'Loading…',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppMotionReveal(
        child: AppGlassSurface(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          radius: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppGlassColors.aqua,
                  strokeWidth: 2.4,
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppGlassColors.inkSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      subtitle: message,
      action: onRetry == null
          ? null
          : ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
            ),
    );
  }
}
