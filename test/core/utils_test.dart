import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/utils.dart';

void main() {
  group('AppUtils', () {
    group('formatDate', () {
      test('formats date correctly', () {
        final date = DateTime(2024, 3, 5);
        expect(AppUtils.formatDate(date), 'Mar 5, 2024');
      });

      test('formats date with double-digit day', () {
        final date = DateTime(2024, 12, 25);
        expect(AppUtils.formatDate(date), 'Dec 25, 2024');
      });

      test('formats January correctly', () {
        final date = DateTime(2023, 1, 1);
        expect(AppUtils.formatDate(date), 'Jan 1, 2023');
      });
    });

    group('formatTime', () {
      test('formats AM time correctly', () {
        final date = DateTime(2024, 1, 1, 9, 30);
        expect(AppUtils.formatTime(date), '9:30 AM');
      });

      test('formats PM time correctly', () {
        final date = DateTime(2024, 1, 1, 15, 45);
        expect(AppUtils.formatTime(date), '3:45 PM');
      });

      test('formats midnight (12:00 AM)', () {
        final date = DateTime(2024, 1, 1, 0, 0);
        expect(AppUtils.formatTime(date), '12:00 AM');
      });

      test('formats noon (12:00 PM)', () {
        final date = DateTime(2024, 1, 1, 12, 0);
        expect(AppUtils.formatTime(date), '12:00 PM');
      });
    });

    group('formatDateTime', () {
      test('returns "Just now" for less than 1 minute ago', () {
        final now = DateTime.now();
        expect(AppUtils.formatDateTime(now), 'Just now');
      });

      test('returns "Just now" for 30 seconds ago', () {
        final date = DateTime.now().subtract(const Duration(seconds: 30));
        expect(AppUtils.formatDateTime(date), 'Just now');
      });

      test('returns minutes ago for less than 60 minutes', () {
        final date = DateTime.now().subtract(const Duration(minutes: 5));
        expect(AppUtils.formatDateTime(date), '5m ago');
      });

      test('returns 59m ago for 59 minutes ago', () {
        final date = DateTime.now().subtract(const Duration(minutes: 59));
        expect(AppUtils.formatDateTime(date), '59m ago');
      });

      test('returns hours ago for less than 24 hours', () {
        final date = DateTime.now().subtract(const Duration(hours: 3));
        expect(AppUtils.formatDateTime(date), '3h ago');
      });

      test('returns days ago for less than 7 days', () {
        final date = DateTime.now().subtract(const Duration(days: 2));
        expect(AppUtils.formatDateTime(date), '2d ago');
      });

      test('returns formatted date for 7 or more days ago', () {
        final date = DateTime(2020, 6, 15);
        expect(AppUtils.formatDateTime(date), AppUtils.formatDate(date));
      });
    });

    group('getInitials', () {
      test('returns two initials for full name', () {
        expect(AppUtils.getInitials('John Doe'), 'JD');
      });

      test('returns single initial for single name', () {
        expect(AppUtils.getInitials('Alice'), 'A');
      });

      test('uses only first two words for three-word names', () {
        expect(AppUtils.getInitials('John Michael Doe'), 'JM');
      });

      test('returns uppercased initials', () {
        expect(AppUtils.getInitials('john doe'), 'JD');
      });

      test('trims whitespace before computing initials', () {
        expect(AppUtils.getInitials('  Jane Smith  '), 'JS');
      });

      test('returns "?" for empty string', () {
        expect(AppUtils.getInitials(''), '?');
      });

      test('handles single character name', () {
        expect(AppUtils.getInitials('A'), 'A');
      });
    });

    group('formatFileSize', () {
      test('formats bytes correctly', () {
        expect(AppUtils.formatFileSize(500), '500 B');
      });

      test('formats 1023 bytes as bytes', () {
        expect(AppUtils.formatFileSize(1023), '1023 B');
      });

      test('formats kilobytes correctly', () {
        expect(AppUtils.formatFileSize(1024), '1.0 KB');
      });

      test('formats kilobytes with decimal', () {
        expect(AppUtils.formatFileSize(1536), '1.5 KB');
      });

      test('formats just under 1MB as KB', () {
        expect(AppUtils.formatFileSize(1024 * 1024 - 1), '1024.0 KB');
      });

      test('formats megabytes correctly', () {
        expect(AppUtils.formatFileSize(1024 * 1024), '1.0 MB');
      });

      test('formats megabytes with decimal', () {
        expect(AppUtils.formatFileSize((1024 * 1024 * 2.5).toInt()), '2.5 MB');
      });

      test('formats large file size in MB', () {
        expect(AppUtils.formatFileSize(100 * 1024 * 1024), '100.0 MB');
      });
    });
  });
}
