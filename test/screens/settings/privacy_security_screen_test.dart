import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/screens/settings/privacy_security_screen.dart';

AppUser _testUser() => AppUser(
      id: 'u1',
      email: 'test@example.com',
      displayName: 'Test User',
      role: UserRole.platformOwner,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

Widget _buildTestWidget({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: PrivacySecurityScreen(),
    ),
  );
}

void main() {
  group('PrivacySecurityScreen', () {
    testWidgets('renders all sections', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('ACCOUNT SECURITY'), findsOneWidget);
      expect(find.text('SESSIONS'), findsOneWidget);
      expect(find.text('DATA & PRIVACY'), findsOneWidget);
    });

    testWidgets('shows Change Password option', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update your account password'), findsOneWidget);
    });

    testWidgets('shows user email address', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('shows session info', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Active Sessions'), findsOneWidget);
      expect(find.text('This device'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('shows Sign Out All Devices option', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Sign Out All Devices'), findsOneWidget);
    });

    testWidgets('shows Export and Delete options', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Export My Data'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('tapping Change Password opens dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Password'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
    });

    testWidgets('tapping Sign Out All shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign Out All Devices'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('server-side setup'),
          findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('tapping Delete Account shows confirmation dialog',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('This action is permanent'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);
    });
  });
}
