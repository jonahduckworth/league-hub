import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/widgets/avatar_widget.dart';
import 'package:league_hub/widgets/chat_room_avatar.dart';

void main() {
  group('ChatRoomAvatar', () {
    testWidgets('uses peer profile picture for direct messages',
        (tester) async {
      final peer = AppUser(
        id: 'user-2',
        email: 'sam@example.com',
        displayName: 'Sam Orr',
        avatarUrl: 'https://example.com/sam.jpg',
        role: UserRole.staff,
        orgId: 'org-1',
        hubIds: const [],
        teamIds: const [],
        createdAt: DateTime(2026),
        isActive: true,
      );
      final room = ChatRoom(
        id: 'dm-1',
        orgId: 'org-1',
        name: 'Jonah Duckworth & Sam Orr',
        type: ChatRoomType.direct,
        participants: const ['user-1', 'user-2'],
        createdAt: DateTime(2026),
        isArchived: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatRoomAvatar(
              room: room,
              displayName: 'Sam Orr',
              directMessagePeer: peer,
            ),
          ),
        ),
      );

      final avatar = tester.widget<AvatarWidget>(find.byType(AvatarWidget));
      expect(avatar.imageUrl, 'https://example.com/sam.jpg');
      expect(avatar.name, 'Sam Orr');
    });

    testWidgets('uses selected event icon when room has no image',
        (tester) async {
      final room = ChatRoom(
        id: 'event-1',
        orgId: 'org-1',
        name: 'Spring Tournament',
        type: ChatRoomType.event,
        participants: const [],
        roomIconName: 'trophy',
        createdAt: DateTime(2026),
        isArchived: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatRoomAvatar(
              room: room,
              displayName: 'Spring Tournament',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('uses forum fallback for league rooms', (tester) async {
      final room = ChatRoom(
        id: 'league-1',
        orgId: 'org-1',
        name: 'JPHL General',
        type: ChatRoomType.league,
        participants: const [],
        createdAt: DateTime(2026),
        isArchived: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatRoomAvatar(
              room: room,
              displayName: 'JPHL General',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.forum), findsOneWidget);
    });

    testWidgets('uses room image for league rooms when available',
        (tester) async {
      final room = ChatRoom(
        id: 'league-2',
        orgId: 'org-1',
        name: 'JPHL General',
        type: ChatRoomType.league,
        participants: const [],
        roomImageUrl: 'https://example.com/jphl.png',
        createdAt: DateTime(2026),
        isArchived: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatRoomAvatar(
              room: room,
              displayName: 'JPHL General',
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CachedNetworkImage &&
              widget.imageUrl == 'https://example.com/jphl.png',
        ),
        findsOneWidget,
      );
    });
  });
}
