import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import 'theme.dart';

class AppUtils {
  static void showErrorSnackBar(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      color: AppColors.danger,
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
    );
  }

  static void showInfoSnackBar(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      color: AppColors.primary,
    );
  }

  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  static String formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(date);
  }

  static String getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Color roleColor(UserRole role) {
    switch (role) {
      case UserRole.platformOwner:
        return const Color(0xFF7C3AED);
      case UserRole.superAdmin:
        return AppColors.primary;
      case UserRole.managerAdmin:
        return AppColors.accent;
      case UserRole.staff:
        return AppColors.success;
    }
  }
}
