import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/navigation/shell_navigation.dart';

void main() {
  group('shouldShowShellBottomNavigation', () {
    test('shows nav on top-level shell destinations', () {
      expect(shouldShowShellBottomNavigation('/'), isTrue);
      expect(shouldShowShellBottomNavigation('/chat'), isTrue);
      expect(shouldShowShellBottomNavigation('/announcements'), isTrue);
      expect(shouldShowShellBottomNavigation('/contacts'), isTrue);
      expect(shouldShowShellBottomNavigation('/policy'), isTrue);
      expect(shouldShowShellBottomNavigation('/settings'), isTrue);
      expect(shouldShowShellBottomNavigation('/profile'), isTrue);
    });

    test('hides nav on nested chat pages', () {
      expect(shouldShowShellBottomNavigation('/chat/new'), isFalse);
      expect(shouldShowShellBottomNavigation('/chat/room-1'), isFalse);
      expect(shouldShowShellBottomNavigation('/chat/room-1/info'), isFalse);
    });
  });

  group('shellBottomNavIndexFor', () {
    test('uses fixed slots for primary shell pages', () {
      expect(shellBottomNavIndexFor(branchIndex: 0, location: '/'), 0);
      expect(
        shellBottomNavIndexFor(
          branchIndex: 3,
          location: '/announcements',
        ),
        1,
      );
      expect(shellBottomNavIndexFor(branchIndex: 1, location: '/chat'), 2);
      expect(shellBottomNavIndexFor(branchIndex: 5, location: '/profile'), 3);
    });

    test('uses the last slot for quick destinations', () {
      expect(shellBottomNavIndexFor(branchIndex: 0, location: '/contacts'), 3);
      expect(
        shellBottomNavIndexFor(branchIndex: 0, location: '/contacts/user-1'),
        3,
      );
      expect(shellBottomNavIndexFor(branchIndex: 2, location: '/policy'), 3);
      expect(
        shellBottomNavIndexFor(branchIndex: 2, location: '/policy/policy-1'),
        3,
      );
      expect(shellBottomNavIndexFor(branchIndex: 4, location: '/settings'), 3);
      expect(
        shellBottomNavIndexFor(branchIndex: 4, location: '/settings/users'),
        3,
      );
    });
  });

  group('shellQuickDestinationForLocation', () {
    test('detects dynamic last-slot destinations', () {
      expect(
        shellQuickDestinationForLocation('/contacts'),
        ShellQuickDestination.contacts,
      );
      expect(
        shellQuickDestinationForLocation('/policy/upload'),
        ShellQuickDestination.policy,
      );
      expect(
        shellQuickDestinationForLocation('/settings/users'),
        ShellQuickDestination.settings,
      );
      expect(shellQuickDestinationForLocation('/profile'), isNull);
      expect(shellQuickDestinationForLocation('/announcements'), isNull);
    });

    test('exposes label and route config', () {
      final settings =
          shellQuickDestinationConfigForLocation('/settings/privacy');

      expect(settings?.label, 'Settings');
      expect(settings?.route, '/settings');
    });
  });

  group('shellBranchNavSlot', () {
    test('orders branches by the visible bottom nav slots', () {
      expect(shellBranchNavSlot(0), 0);
      expect(shellBranchNavSlot(3), 1);
      expect(shellBranchNavSlot(1), 2);
      expect(shellBranchNavSlot(2), 3);
      expect(shellBranchNavSlot(4), 3);
      expect(shellBranchNavSlot(5), 3);
      expect(shellBranchNavSlot(6), 3);
    });
  });
}
