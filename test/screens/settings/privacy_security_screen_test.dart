import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
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
    overrides: [
      organizationProvider.overrideWith((ref) async => null),
      leaguesProvider.overrideWith((ref) => Stream.value([])),
      ...overrides,
    ],
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
      expect(find.text('SESSIONS'), findsNothing);
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

    testWidgets('does not expose email address updates', (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Email Address'), findsNothing);
      expect(find.text('test@example.com'), findsNothing);
      expect(find.text('Change Email'), findsNothing);
    });

    testWidgets('shows privacy, support, and account deletion actions',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Active Sessions'), findsNothing);
      expect(find.text('Sign Out All Devices'), findsNothing);
      expect(find.text('Export My Data'), findsNothing);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Community Guidelines'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('requires confirmation and a password before deletion',
        (tester) async {
      await tester.pumpWidget(_buildTestWidget(
        overrides: [
          currentUserProvider.overrideWith((ref) async => _testUser()),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Delete Account'), findsOneWidget);
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
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });
  });
}
