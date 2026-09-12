import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/providers/notification_preferences_provider.dart';

void main() {
  final createdAt = DateTime(2026, 9, 12);

  ChatRoom room(String id) => ChatRoom(
        id: id,
        orgId: 'org-1',
        name: id,
        type: ChatRoomType.event,
        participants: const [],
        createdAt: createdAt,
        isArchived: false,
      );

  test('total unread count aggregates every visible room', () async {
    final container = ProviderContainer(
      overrides: [
        chatRoomsProvider.overrideWith(
          (ref) => Stream.value([room('room-1'), room('room-2')]),
        ),
        unreadCountProvider.overrideWith(
          (ref, roomId) => Stream.value(roomId == 'room-1' ? 2 : 3),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatRoomsProvider.future);
    container.read(totalUnreadMessageCountProvider);
    await Future.wait([
      container.read(unreadCountProvider('room-1').future),
      container.read(unreadCountProvider('room-2').future),
    ]);

    expect(container.read(totalUnreadMessageCountProvider), 5);
  });

  test('turning Badge Count off immediately clears the native value', () {
    final container = ProviderContainer(
      overrides: [
        totalUnreadMessageCountProvider.overrideWithValue(7),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appBadgeCountProvider), 7);

    container.read(notificationPrefsProvider.notifier).toggle('badge_count');

    expect(container.read(appBadgeCountProvider), 0);
  });
}
