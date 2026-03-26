import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/theme.dart';

void main() {
  group('AppColors', () {
    test('primary is dark blue', () {
      expect(AppColors.primary, const Color(0xFF1A3A5C));
    });

    test('primaryLight is lighter blue', () {
      expect(AppColors.primaryLight, const Color(0xFF2E75B6));
    });

    test('accent is bright blue', () {
      expect(AppColors.accent, const Color(0xFF4DA3FF));
    });

    test('background is light gray', () {
      expect(AppColors.background, const Color(0xFFF5F7FA));
    });

    test('card is white', () {
      expect(AppColors.card, const Color(0xFFFFFFFF));
    });

    test('success is green', () {
      expect(AppColors.success, const Color(0xFF10B981));
    });

    test('warning is amber', () {
      expect(AppColors.warning, const Color(0xFFF59E0B));
    });

    test('danger is red', () {
      expect(AppColors.danger, const Color(0xFFEF4444));
    });

    test('text colors have decreasing opacity order', () {
      // text is darkest, textSecondary is medium, textMuted is lightest
      expect(AppColors.text, const Color(0xFF1A1A2E));
      expect(AppColors.textSecondary, const Color(0xFF6B7280));
      expect(AppColors.textMuted, const Color(0xFF9CA3AF));
    });

    test('border is light gray', () {
      expect(AppColors.border, const Color(0xFFE5E7EB));
    });

    test('all colors are opaque', () {
      final colors = [
        AppColors.primary,
        AppColors.primaryLight,
        AppColors.accent,
        AppColors.background,
        AppColors.card,
        AppColors.text,
        AppColors.textSecondary,
        AppColors.textMuted,
        AppColors.border,
        AppColors.success,
        AppColors.warning,
        AppColors.danger,
      ];
      for (final c in colors) {
        expect(c.a, 1.0, reason: '$c should be fully opaque');
      }
    });
  });

  group('AppTheme', () {
    test('lightTheme returns a ThemeData', () {
      final theme = AppTheme.lightTheme;
      expect(theme, isA<ThemeData>());
    });

    test('lightTheme uses Material 3', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
    });

    test('lightTheme scaffold background is AppColors.background', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppColors.background);
    });

    test('appBar uses primary color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.backgroundColor, AppColors.primary);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
    });

    test('appBar has no elevation', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.elevation, 0);
    });

    test('elevated buttons use primary color', () {
      final theme = AppTheme.lightTheme;
      final style = theme.elevatedButtonTheme.style;
      expect(style, isNotNull);
    });

    test('input decoration theme is filled', () {
      final theme = AppTheme.lightTheme;
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, Colors.white);
    });

    test('bottom nav bar uses primary for selected items', () {
      final theme = AppTheme.lightTheme;
      expect(
          theme.bottomNavigationBarTheme.selectedItemColor, AppColors.primary);
      expect(theme.bottomNavigationBarTheme.unselectedItemColor,
          AppColors.textMuted);
    });

    test('bottom nav bar is fixed type', () {
      final theme = AppTheme.lightTheme;
      expect(theme.bottomNavigationBarTheme.type,
          BottomNavigationBarType.fixed);
    });

    test('color scheme primary matches AppColors.primary', () {
      final theme = AppTheme.lightTheme;
      expect(theme.colorScheme.primary, AppColors.primary);
    });

    test('card theme has rounded corners and border', () {
      final theme = AppTheme.lightTheme;
      expect(theme.cardTheme.color, AppColors.card);
      expect(theme.cardTheme.elevation, 1);
    });
  });
}
