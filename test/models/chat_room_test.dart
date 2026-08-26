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
          'name': 'Coaches Room',
          'type': 'event',
          'roomPurpose': 'group',
          'leagueId': 'league1',
          'participants': ['user1', 'user2', 'user3'],
          'createdAt': testDateStr,
          'isArchived': false,
          'lastMessage': 'Hello everyone!',
          'lastMessageAt': lastMsgDateStr,
          'lastMessageBy': 'user1',
          'roomIconName': 'trophy',
          'roomImageUrl': 'https://example.com/room.png',
          'participantNames': {'user1': 'Alice', 'user2': 'Bob'},
        };

        final room = ChatRoom.fromJson(json);

        expect(room.id, 'room1');
        expect(room.orgId, 'org1');
        expect(room.name, 'Coaches Room');
        expect(room.type, ChatRoomType.event);
        expect(room.roomPurpose, ChatRoomPurpose.group);
        expect(room.leagueId, 'league1');
        expect(room.participants, ['user1', 'user2', 'user3']);
        expect(room.createdAt, testDate);
        expect(room.isArchived, false);
        expect(room.lastMessage, 'Hello everyone!');
        expect(room.lastMessageAt, lastMsgDate);
        expect(room.lastMessageBy, 'user1');
        expect(room.roomIconName, 'trophy');
        expect(room.roomImageUrl, 'https://example.com/room.png');
        expect(room.participantNames, {'user1': 'Alice', 'user2': 'Bob'});
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

      test('keeps legacy event rooms categorized as events', () {
        final room = ChatRoom.fromJson({
          'id': 'legacy-event',
          'orgId': 'org1',
          'name': 'Legacy Event',
          'type': 'event',
          'participants': [],
          'createdAt': testDateStr,
          'isArchived': false,
        });

        expect(room.roomPurpose, isNull);
        expect(room.isEventRoom, isTrue);
        expect(room.isGroupRoom, isFalse);
      });

      test('parses group room purpose', () {
        final room = ChatRoom.fromJson({
          'id': 'group-room',
          'orgId': 'org1',
          'name': 'Coaches',
          'type': 'event',
          'roomPurpose': 'group',
          'participants': [],
          'createdAt': testDateStr,
          'isArchived': false,
        });

        expect(room.roomPurpose, ChatRoomPurpose.group);
        expect(room.isGroupRoom, isTrue);
        expect(room.isEventRoom, isFalse);
      });

      test('parses a multi-team Event Room audience', () {
        final room = ChatRoom.fromJson({
          'id': 'showcase',
          'orgId': 'org1',
          'name': 'Provincial Showcase',
          'type': 'event',
          'roomPurpose': 'event',
          'leagueId': 'league1',
          'hubId': 'alberta',
          'teamId': 'team-ab',
          'hubIds': ['alberta', 'bc'],
          'teamIds': ['team-ab', 'team-bc'],
          'participants': [],
          'createdAt': testDateStr,
          'isArchived': false,
        });

        expect(room.hasMultiTeamAudience, isTrue);
        expect(room.hubIds, ['alberta', 'bc']);
        expect(room.teamIds, ['team-ab', 'team-bc']);
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
        expect(room.roomIconName, isNull);
        expect(room.roomImageUrl, isNull);
        expect(room.participantNames, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final room = ChatRoom(
          id: 'room1',
          orgId: 'org1',
          name: 'Coaches Room',
          type: ChatRoomType.event,
          roomPurpose: ChatRoomPurpose.group,
          participants: ['userA', 'userB'],
          createdAt: testDate,
          isArchived: true,
          lastMessage: 'See you!',
          lastMessageAt: lastMsgDate,
          lastMessageBy: 'userA',
          roomIconName: 'group',
          roomImageUrl: 'https://example.com/group.png',
          participantNames: const {'userA': 'Alice', 'userB': 'Bob'},
        );

        final json = room.toJson();

        expect(json['id'], 'room1');
        expect(json['orgId'], 'org1');
        expect(json['name'], 'Coaches Room');
        expect(json['type'], 'event');
        expect(json['roomPurpose'], 'group');
        expect(json['participants'], ['userA', 'userB']);
        expect(json['createdAt'], testDateStr);
        expect(json['isArchived'], true);
        expect(json['lastMessage'], 'See you!');
        expect(json['lastMessageAt'], lastMsgDateStr);
        expect(json['lastMessageBy'], 'userA');
        expect(json['roomIconName'], 'group');
        expect(json['roomImageUrl'], 'https://example.com/group.png');
        expect(json['participantNames'], {'userA': 'Alice', 'userB': 'Bob'});
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

        expect(json.containsKey('roomPurpose'), isFalse);
        expect(json['leagueId'], isNull);
        expect(json['lastMessage'], isNull);
        expect(json['lastMessageAt'], isNull);
        expect(json['lastMessageBy'], isNull);
        expect(json['roomIconName'], isNull);
        expect(json['roomImageUrl'], isNull);
        expect(json['participantNames'], isEmpty);
      });

      test('serializes multi-team arrays only when populated', () {
        final room = ChatRoom(
          id: 'showcase',
          orgId: 'org1',
          name: 'Provincial Showcase',
          type: ChatRoomType.event,
          roomPurpose: ChatRoomPurpose.event,
          leagueId: 'league1',
          hubId: 'alberta',
          teamId: 'team-ab',
          hubIds: const ['alberta', 'bc'],
          teamIds: const ['team-ab', 'team-bc'],
          participants: const [],
          createdAt: testDate,
          isArchived: false,
        );

        expect(room.toJson()['hubIds'], ['alberta', 'bc']);
        expect(room.toJson()['teamIds'], ['team-ab', 'team-bc']);
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
        roomIconName: 'schedule',
        roomImageUrl: 'https://example.com/schedule.png',
        participantNames: const {'u1': 'Alice', 'u2': 'Bob'},
      );

      final restored =
          ChatRoom.fromJson({'id': original.id, ...original.toJson()});

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
      expect(restored.roomIconName, original.roomIconName);
      expect(restored.roomImageUrl, original.roomImageUrl);
      expect(restored.participantNames, original.participantNames);
    });
  });
}
