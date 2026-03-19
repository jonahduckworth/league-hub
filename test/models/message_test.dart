import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/message.dart';

void main() {
  group('LinkPreview', () {
    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'url': 'https://example.com',
          'title': 'Example Title',
          'description': 'A description',
          'thumbnailUrl': 'https://example.com/thumb.jpg',
        };

        final preview = LinkPreview.fromJson(json);

        expect(preview.url, 'https://example.com');
        expect(preview.title, 'Example Title');
        expect(preview.description, 'A description');
        expect(preview.thumbnailUrl, 'https://example.com/thumb.jpg');
      });

      test('optional fields are null when not provided', () {
        final json = {'url': 'https://example.com'};

        final preview = LinkPreview.fromJson(json);

        expect(preview.url, 'https://example.com');
        expect(preview.title, isNull);
        expect(preview.description, isNull);
        expect(preview.thumbnailUrl, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final preview = LinkPreview(
          url: 'https://example.com',
          title: 'Title',
          description: 'Desc',
          thumbnailUrl: 'https://example.com/t.jpg',
        );

        final json = preview.toJson();

        expect(json['url'], 'https://example.com');
        expect(json['title'], 'Title');
        expect(json['description'], 'Desc');
        expect(json['thumbnailUrl'], 'https://example.com/t.jpg');
      });

      test('serializes null optional fields', () {
        final preview = LinkPreview(url: 'https://example.com');
        final json = preview.toJson();

        expect(json['title'], isNull);
        expect(json['description'], isNull);
        expect(json['thumbnailUrl'], isNull);
      });
    });
  });

  group('Message', () {
    final testDate = DateTime(2024, 7, 4, 20, 0);
    final testDateStr = testDate.toIso8601String();

    group('fromJson', () {
      test('parses all fields correctly', () {
        final json = {
          'id': 'msg1',
          'chatRoomId': 'room1',
          'senderId': 'user1',
          'senderName': 'Alice',
          'text': 'Hello world',
          'mediaUrl': 'https://example.com/img.jpg',
          'mediaType': 'image',
          'linkPreview': {
            'url': 'https://example.com',
            'title': 'Example',
          },
          'createdAt': testDateStr,
          'readBy': ['user1', 'user2'],
        };

        final msg = Message.fromJson(json);

        expect(msg.id, 'msg1');
        expect(msg.chatRoomId, 'room1');
        expect(msg.senderId, 'user1');
        expect(msg.senderName, 'Alice');
        expect(msg.text, 'Hello world');
        expect(msg.mediaUrl, 'https://example.com/img.jpg');
        expect(msg.mediaType, 'image');
        expect(msg.linkPreview, isNotNull);
        expect(msg.linkPreview!.url, 'https://example.com');
        expect(msg.createdAt, testDate);
        expect(msg.readBy, ['user1', 'user2']);
      });

      test('optional fields are null when not provided', () {
        final json = {
          'id': 'msg1',
          'chatRoomId': 'room1',
          'senderId': 'user1',
          'senderName': 'Alice',
          'createdAt': testDateStr,
          'readBy': [],
        };

        final msg = Message.fromJson(json);

        expect(msg.text, isNull);
        expect(msg.mediaUrl, isNull);
        expect(msg.mediaType, isNull);
        expect(msg.linkPreview, isNull);
      });

      test('defaults readBy to empty list', () {
        final json = {
          'id': 'msg1',
          'chatRoomId': 'room1',
          'senderId': 'user1',
          'senderName': 'Alice',
          'createdAt': testDateStr,
        };

        expect(Message.fromJson(json).readBy, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final msg = Message(
          id: 'msg1',
          chatRoomId: 'room1',
          senderId: 'user1',
          senderName: 'Bob',
          text: 'Hey!',
          mediaUrl: null,
          mediaType: null,
          linkPreview: null,
          createdAt: testDate,
          readBy: ['user1'],
        );

        final json = msg.toJson();

        expect(json['id'], 'msg1');
        expect(json['chatRoomId'], 'room1');
        expect(json['senderId'], 'user1');
        expect(json['senderName'], 'Bob');
        expect(json['text'], 'Hey!');
        expect(json['createdAt'], testDateStr);
        expect(json['readBy'], ['user1']);
        expect(json['linkPreview'], isNull);
      });

      test('serializes linkPreview when present', () {
        final msg = Message(
          id: 'msg1',
          chatRoomId: 'room1',
          senderId: 'user1',
          senderName: 'Bob',
          createdAt: testDate,
          readBy: [],
          linkPreview: LinkPreview(url: 'https://example.com', title: 'Title'),
        );

        final json = msg.toJson();

        expect(json['linkPreview'], isNotNull);
        expect(json['linkPreview']['url'], 'https://example.com');
        expect(json['linkPreview']['title'], 'Title');
      });
    });

    test('roundtrip preserves all data', () {
      final original = Message(
        id: 'msg1',
        chatRoomId: 'room1',
        senderId: 'user1',
        senderName: 'Alice',
        text: 'Hi there',
        mediaUrl: 'https://example.com/media.mp4',
        mediaType: 'video',
        linkPreview: LinkPreview(
          url: 'https://example.com',
          title: 'Example',
          description: 'A great site',
        ),
        createdAt: testDate,
        readBy: ['user1', 'user2'],
      );

      final restored = Message.fromJson({'id': original.id, ...original.toJson()});

      expect(restored.id, original.id);
      expect(restored.chatRoomId, original.chatRoomId);
      expect(restored.senderId, original.senderId);
      expect(restored.senderName, original.senderName);
      expect(restored.text, original.text);
      expect(restored.mediaUrl, original.mediaUrl);
      expect(restored.mediaType, original.mediaType);
      expect(restored.linkPreview?.url, original.linkPreview?.url);
      expect(restored.createdAt, original.createdAt);
      expect(restored.readBy, original.readBy);
    });
  });
}
