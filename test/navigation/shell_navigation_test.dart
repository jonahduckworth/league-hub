import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/navigation/shell_navigation.dart';

void main() {
  test('four fixed destinations retain their slots', () {
    for (final entry in {0: 0, 7: 1, 6: 2, 8: 3}.entries) {
      expect(shellBranchNavSlot(entry.key), entry.value);
      expect(shellBottomNavIndexFor(branchIndex: entry.key, location: '/'),
          entry.value);
    }
    for (final route in [
      '/',
      '/schedule',
      '/contacts',
      '/contacts/person',
      '/info'
    ]) {
      expect(shouldShowShellBottomNavigation(route), isTrue);
    }
  });
  test('utility pages cannot replace or falsely select the Info tab', () {
    for (final route in [
      '/chat',
      '/chat/new',
      '/chat/room/info',
      '/announcements',
      '/policy',
      '/policy/item',
      '/settings',
      '/profile'
    ]) {
      expect(shouldShowShellBottomNavigation(route), isFalse);
    }
    for (final branch in [1, 2, 3, 4, 5]) {
      expect(
          shellBottomNavIndexFor(branchIndex: branch, location: '/profile'), 0);
      expect(shellBranchNavSlot(branch), 0);
    }
  });
  test('quick destinations retain fallback routes for system back navigation',
      () {
    expect(shellQuickDestinationConfigForLocation('/settings/privacy')?.route,
        '/settings');
    expect(shellQuickDestinationConfigForLocation('/policy/item')?.route,
        '/policy');
    expect(shellQuickDestinationConfigForLocation('/chat')?.label, 'Chats');
    expect(shellQuickDestinationForLocation('/info'), isNull);
  });
}
