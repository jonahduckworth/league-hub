import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/queued_mutation.dart';

void main() {
  group('QueuedMutation', () {
    test('creates instance with required fields', () {
      final mutation = QueuedMutation(
        id: 'mut-1',
        method: 'sendMessage',
        params: {'orgId': 'org1', 'roomId': 'room1'},
        createdAt: DateTime(2024, 1, 1),
      );

      expect(mutation.id, 'mut-1');
      expect(mutation.method, 'sendMessage');
      expect(mutation.params['orgId'], 'org1');
      expect(mutation.retryCount, 0);
    });

    test('serializes to JSON correctly', () {
      final mutation = QueuedMutation(
        id: 'mut-1',
        method: 'sendMessage',
        params: {'orgId': 'org1', 'text': 'hello'},
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
        retryCount: 2,
      );

      final json = mutation.toJson();

      expect(json['id'], 'mut-1');
      expect(json['method'], 'sendMessage');
      expect(json['params']['orgId'], 'org1');
      expect(json['params']['text'], 'hello');
      expect(json['createdAt'], '2024-01-01T12:00:00.000');
      expect(json['retryCount'], 2);
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'mut-2',
        'method': 'deleteAnnouncement',
        'params': {'orgId': 'org1', 'announcementId': 'a1'},
        'createdAt': '2024-06-15T09:30:00.000',
        'retryCount': 1,
      };

      final mutation = QueuedMutation.fromJson(json);

      expect(mutation.id, 'mut-2');
      expect(mutation.method, 'deleteAnnouncement');
      expect(mutation.params['announcementId'], 'a1');
      expect(mutation.createdAt, DateTime(2024, 6, 15, 9, 30));
      expect(mutation.retryCount, 1);
    });

    test('round-trip serialization preserves all fields', () {
      final original = QueuedMutation(
        id: 'mut-3',
        method: 'createDocument',
        params: {
          'orgId': 'org1',
          'data': {'name': 'test.pdf', 'category': 'Policy'},
        },
        createdAt: DateTime(2024, 3, 10, 14, 45, 30),
        retryCount: 3,
      );

      final json = original.toJson();
      final restored = QueuedMutation.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.method, original.method);
      expect(restored.params['orgId'], original.params['orgId']);
      expect(
        (restored.params['data'] as Map)['name'],
        (original.params['data'] as Map)['name'],
      );
      expect(restored.createdAt, original.createdAt);
      expect(restored.retryCount, original.retryCount);
    });

    test('fromJson defaults retryCount to 0 when missing', () {
      final json = {
        'id': 'mut-4',
        'method': 'togglePin',
        'params': {'orgId': 'o1'},
        'createdAt': '2024-01-01T00:00:00.000',
      };

      final mutation = QueuedMutation.fromJson(json);
      expect(mutation.retryCount, 0);
    });

    test('copyWith updates retryCount', () {
      final mutation = QueuedMutation(
        id: 'mut-5',
        method: 'sendMessage',
        params: {},
        createdAt: DateTime(2024),
        retryCount: 0,
      );

      final updated = mutation.copyWith(retryCount: 2);

      expect(updated.retryCount, 2);
      expect(updated.id, mutation.id);
      expect(updated.method, mutation.method);
    });

    test('copyWith without args returns same values', () {
      final mutation = QueuedMutation(
        id: 'mut-6',
        method: 'archiveChatRoom',
        params: {'orgId': 'o1'},
        createdAt: DateTime(2024),
        retryCount: 1,
      );

      final copy = mutation.copyWith();
      expect(copy.retryCount, 1);
    });

    test('toString contains method and id', () {
      final mutation = QueuedMutation(
        id: 'mut-7',
        method: 'deleteDocument',
        params: {},
        createdAt: DateTime(2024),
      );

      expect(mutation.toString(), contains('mut-7'));
      expect(mutation.toString(), contains('deleteDocument'));
    });

    test('params can contain nested maps', () {
      final mutation = QueuedMutation(
        id: 'mut-8',
        method: 'createAnnouncement',
        params: {
          'orgId': 'org1',
          'data': {
            'title': 'Test',
            'body': 'Content',
            'scope': 'orgWide',
          },
        },
        createdAt: DateTime(2024),
      );

      final json = mutation.toJson();
      final restored = QueuedMutation.fromJson(json);
      final data = restored.params['data'] as Map;
      expect(data['title'], 'Test');
      expect(data['scope'], 'orgWide');
    });

    test('params can contain lists', () {
      final mutation = QueuedMutation(
        id: 'mut-9',
        method: 'sendMessage',
        params: {
          'tags': ['urgent', 'important'],
        },
        createdAt: DateTime(2024),
      );

      final json = mutation.toJson();
      final restored = QueuedMutation.fromJson(json);
      expect(restored.params['tags'], ['urgent', 'important']);
    });
  });
}
