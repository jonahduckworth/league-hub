import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/chat_room.dart';

void main() {
  group('ChatRoom', () {
    final testDate = DateTime(2024, 6, 15, 14, 0);
    final testDateStr = testDate.toIso8601String();
    final lastMsgDate = DateTime(2024, 6, 15, 15, 30);
    final lastMsgDateStr = lastMsgDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'room1',
          'orgId': 'org1',
          'name': 'League Chat',
          'type': 'league',
          'leagueId': 'league1',
          'participants': ['user1', 'user2', 'user3'],
          'createdAt': testDateStr,
          'isArchived': false,
          'lastMessage': 'Hello everyone!',
          'lastMessageAt': lastMsgDateStr,
          'lastMessageBy': 'user1',
        };

        final room = ChatRoom.fromJson(json);

        expect(room.id, 'room1');
        expect(room.orgId, 'org1');
        expect(room.name, 'League Chat');
        expect(room.type, ChatRoomType.league);
        expect(room.leagueId, 'league1');
        expect(room.participants, ['user1', 'user2', 'user3']);
        expect(room.createdAt, testDate);
        expect(room.isArchived, false);
        expect(room.lastMessage, 'Hello everyone!');
        expect(room.lastMessageAt, lastMsgDate);
        expect(room.lastMessageBy, 'user1');
      });

      test('parses all ChatRoomType values', () {
        for (final type in ChatRoomType.values) {
          final json = {
            'id': 'r1',
            'orgId': 'o1',
            'name': 'Chat',
            'type': type.name,
            'participants': [],
            'createdAt': testDateStr,
            'isArchived': false,
          };
          expect(ChatRoom.fromJson(json).type, type);
        }
      });

      test('defaults type to league for unknown type string', () {
        final json = {
          'id': 'room1',
          'orgId': 'org1',
          'name': 'Chat',
          'type': 'unknown',
          'participants': [],
          'createdAt': testDateStr,
          'isArchived': false,
        };

        expect(ChatRoom.fromJson(json).type, ChatRoomType.league);
      });

      test('defaults isArchived to false', () {
        final json = {
          'id': 'room1',
          'orgId': 'org1',
          'name': 'Chat',
          'type': 'league',
          'participants': [],
          'createdAt': testDateStr,
        };

        expect(ChatRoom.fromJson(json).isArchived, false);
      });

      test('defaults participants to empty list', () {
        final json = {
          'id': 'room1',
          'orgId': 'org1',
          'name': 'Chat',
          'type': 'league',
          'createdAt': testDateStr,
          'isArchived': false,
        };

        expect(ChatRoom.fromJson(json).participants, isEmpty);
      });

      test('lastMessage fields are null when not provided', () {
        final json = {
          'id': 'room1',
          'orgId': 'org1',
          'name': 'Chat',
          'type': 'league',
          'participants': [],
          'createdAt': testDateStr,
          'isArchived': false,
        };

        final room = ChatRoom.fromJson(json);

        expect(room.lastMessage, isNull);
        expect(room.lastMessageAt, isNull);
        expect(room.lastMessageBy, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final room = ChatRoom(
          id: 'room1',
          orgId: 'org1',
          name: 'DM Room',
          type: ChatRoomType.direct,
          participants: ['userA', 'userB'],
          createdAt: testDate,
          isArchived: true,
          lastMessage: 'See you!',
          lastMessageAt: lastMsgDate,
          lastMessageBy: 'userA',
        );

        final json = room.toJson();

        expect(json['id'], 'room1');
        expect(json['orgId'], 'org1');
        expect(json['name'], 'DM Room');
        expect(json['type'], 'direct');
        expect(json['participants'], ['userA', 'userB']);
        expect(json['createdAt'], testDateStr);
        expect(json['isArchived'], true);
        expect(json['lastMessage'], 'See you!');
        expect(json['lastMessageAt'], lastMsgDateStr);
        expect(json['lastMessageBy'], 'userA');
      });

      test('serializes null optional fields', () {
        final room = ChatRoom(
          id: 'room1',
          orgId: 'org1',
          name: 'Chat',
          type: ChatRoomType.event,
          participants: [],
          createdAt: testDate,
          isArchived: false,
        );

        final json = room.toJson();

        expect(json['leagueId'], isNull);
        expect(json['lastMessage'], isNull);
        expect(json['lastMessageAt'], isNull);
        expect(json['lastMessageBy'], isNull);
      });
    });

    test('roundtrip preserves all data', () {
      final original = ChatRoom(
        id: 'room1',
        orgId: 'org1',
        name: 'Test Room',
        type: ChatRoomType.direct,
        leagueId: 'league1',
        participants: ['u1', 'u2'],
        createdAt: testDate,
        isArchived: false,
        lastMessage: 'Hi',
        lastMessageAt: lastMsgDate,
        lastMessageBy: 'u1',
      );

      final restored = ChatRoom.fromJson({'id': original.id, ...original.toJson()});

      expect(restored.id, original.id);
      expect(restored.orgId, original.orgId);
      expect(restored.name, original.name);
      expect(restored.type, original.type);
      expect(restored.leagueId, original.leagueId);
      expect(restored.participants, original.participants);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isArchived, original.isArchived);
      expect(restored.lastMessage, original.lastMessage);
      expect(restored.lastMessageAt, original.lastMessageAt);
      expect(restored.lastMessageBy, original.lastMessageBy);
    });
  });
}
