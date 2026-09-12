import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/notification_preferences_provider.dart';

void main() {
  AppUser user({bool badgeEnabled = true, int unreadCount = 0}) => AppUser(
        id: 'user-1',
        email: 'user@example.com',
        displayName: 'User',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: const [],
        teamIds: const [],
        createdAt: DateTime(2026, 9, 12),
        isActive: true,
        appBadgeEnabled: badgeEnabled,
        unreadChatCount: unreadCount,
      );

  test('badge count reads the single server-maintained unread stream',
      () async {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) async => user(unreadCount: 5)),
        unreadChatCountProvider.overrideWith((ref, uid) => Stream.value(5)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentUserProvider.future);
    await container.read(unreadChatCountProvider('user-1').future);

    expect(container.read(totalUnreadMessageCountProvider), 5);
    expect(container.read(appBadgeCountProvider), 5);
  });

  test('a disabled persisted preference clears the native value', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) async => user(badgeEnabled: false, unreadCount: 7),
        ),
        totalUnreadMessageCountProvider.overrideWithValue(7),
      ],
    );
    addTearDown(container.dispose);

    await container.read(currentUserProvider.future);

    expect(container.read(appBadgeCountProvider), 0);
  });
}
