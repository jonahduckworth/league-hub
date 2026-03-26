import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:league_hub/models/queued_mutation.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/offline_queue_service.dart';

import '../helpers/firebase_test_helper.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreService firestoreService;
  late Box<String> box;
  late OfflineQueueService queueService;

  setUpAll(() async {
    await FirebaseTestHelper.setupFirestore();
    Hive.init('/tmp/hive_test_${DateTime.now().millisecondsSinceEpoch}');
  });

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    firestoreService = FirestoreService(firestore: fakeFirestore);
    box = await Hive.openBox<String>(
        'test_mutations_${DateTime.now().microsecondsSinceEpoch}');
    queueService = OfflineQueueService.withBox(
      firestoreService: firestoreService,
      box: box,
    );
  });

  tearDown(() async {
    await queueService.dispose();
    await box.clear();
    await box.close();
  });

  QueuedMutation makeMutation({
    String id = 'mut-1',
    String method = 'sendMessage',
    Map<String, dynamic>? params,
    DateTime? createdAt,
  }) =>
      QueuedMutation(
        id: id,
        method: method,
        params: params ??
            {
              'orgId': 'org1',
              'roomId': 'room1',
              'senderId': 'u1',
              'senderName': 'Test',
              'text': 'hello',
            },
        createdAt: createdAt ?? DateTime(2024, 1, 1),
      );

  group('OfflineQueueService - Queue Operations', () {
    test('starts with empty queue', () {
      expect(queueService.pendingCount, 0);
      expect(queueService.pendingMutations, isEmpty);
    });

    test('enqueue adds a mutation', () async {
      await queueService.enqueue(makeMutation());
      expect(queueService.pendingCount, 1);
    });

    test('enqueue multiple mutations', () async {
      await queueService.enqueue(makeMutation(id: 'mut-1'));
      await queueService.enqueue(makeMutation(id: 'mut-2'));
      await queueService.enqueue(makeMutation(id: 'mut-3'));
      expect(queueService.pendingCount, 3);
    });

    test('dequeue removes a specific mutation', () async {
      await queueService.enqueue(makeMutation(id: 'mut-1'));
      await queueService.enqueue(makeMutation(id: 'mut-2'));

      await queueService.dequeue('mut-1');
      expect(queueService.pendingCount, 1);

      final remaining = queueService.pendingMutations;
      expect(remaining.first.id, 'mut-2');
    });

    test('clearQueue removes all mutations', () async {
      await queueService.enqueue(makeMutation(id: 'mut-1'));
      await queueService.enqueue(makeMutation(id: 'mut-2'));

      await queueService.clearQueue();
      expect(queueService.pendingCount, 0);
    });

    test('pendingMutations returns mutations sorted by createdAt', () async {
      await queueService.enqueue(
          makeMutation(id: 'mut-2', createdAt: DateTime(2024, 1, 3)));
      await queueService.enqueue(
          makeMutation(id: 'mut-1', createdAt: DateTime(2024, 1, 1)));
      await queueService.enqueue(
          makeMutation(id: 'mut-3', createdAt: DateTime(2024, 1, 2)));

      final mutations = queueService.pendingMutations;
      expect(mutations[0].id, 'mut-1');
      expect(mutations[1].id, 'mut-3');
      expect(mutations[2].id, 'mut-2');
    });

    test('dequeue nonexistent id does not throw', () async {
      await queueService.enqueue(makeMutation());
      await queueService.dequeue('nonexistent');
      expect(queueService.pendingCount, 1);
    });
  });

  group('OfflineQueueService - Serialization', () {
    test('mutations survive serialization to Hive box', () async {
      final mutation = makeMutation(
        id: 'persist-1',
        method: 'createAnnouncement',
        params: {
          'orgId': 'org1',
          'data': {'title': 'Test', 'body': 'Content'},
        },
      );

      await queueService.enqueue(mutation);

      // Read directly from the box to verify serialization.
      final raw = box.get('persist-1');
      expect(raw, isNotNull);

      final decoded =
          QueuedMutation.fromJson(Map<String, dynamic>.from(jsonDecode(raw!)));
      expect(decoded.id, 'persist-1');
      expect(decoded.method, 'createAnnouncement');
      expect((decoded.params['data'] as Map)['title'], 'Test');
    });

    test('retry count is persisted', () async {
      final mutation = makeMutation(id: 'retry-1');
      mutation.retryCount = 2;
      await queueService.enqueue(mutation);

      final restored = queueService.pendingMutations.first;
      expect(restored.retryCount, 2);
    });
  });

  group('OfflineQueueService - Replay', () {
    test('replayQueue processes sendMessage mutations', () async {
      // Seed Firestore with a chat room.
      await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('chatRooms')
          .doc('room1')
          .set({
        'name': 'Test Room',
        'type': 'league',
        'participants': [],
        'isArchived': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await queueService.enqueue(makeMutation(
        id: 'msg-1',
        method: 'sendMessage',
        params: {
          'orgId': 'org1',
          'roomId': 'room1',
          'senderId': 'u1',
          'senderName': 'Test User',
          'text': 'queued message',
        },
      ));

      await queueService.replayQueue();
      expect(queueService.pendingCount, 0);

      // Verify message was created in Firestore.
      final messages = await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('chatRooms')
          .doc('room1')
          .collection('messages')
          .get();
      expect(messages.docs, isNotEmpty);
      expect(messages.docs.first.data()['text'], 'queued message');
    });

    test('replayQueue processes deleteAnnouncement', () async {
      // Seed an announcement.
      await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('announcements')
          .doc('a1')
          .set({'title': 'Test', 'body': 'Content'});

      await queueService.enqueue(makeMutation(
        id: 'del-1',
        method: 'deleteAnnouncement',
        params: {'orgId': 'org1', 'announcementId': 'a1'},
      ));

      await queueService.replayQueue();
      expect(queueService.pendingCount, 0);

      final doc = await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('announcements')
          .doc('a1')
          .get();
      expect(doc.exists, isFalse);
    });

    test('replayQueue processes togglePin', () async {
      await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('announcements')
          .doc('a1')
          .set({'title': 'Test', 'isPinned': false});

      await queueService.enqueue(makeMutation(
        id: 'pin-1',
        method: 'togglePin',
        params: {'orgId': 'org1', 'announcementId': 'a1', 'isPinned': true},
      ));

      await queueService.replayQueue();
      expect(queueService.pendingCount, 0);
    });

    test('replay order is chronological', () async {
      // Seed chat room.
      await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('chatRooms')
          .doc('room1')
          .set({
        'name': 'Test',
        'type': 'league',
        'participants': [],
        'isArchived': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await queueService.enqueue(makeMutation(
        id: 'msg-2',
        method: 'sendMessage',
        params: {
          'orgId': 'org1',
          'roomId': 'room1',
          'senderId': 'u1',
          'senderName': 'Test',
          'text': 'second',
        },
        createdAt: DateTime(2024, 1, 2),
      ));
      await queueService.enqueue(makeMutation(
        id: 'msg-1',
        method: 'sendMessage',
        params: {
          'orgId': 'org1',
          'roomId': 'room1',
          'senderId': 'u1',
          'senderName': 'Test',
          'text': 'first',
        },
        createdAt: DateTime(2024, 1, 1),
      ));

      await queueService.replayQueue();
      expect(queueService.pendingCount, 0);
    });

    test('replay emits sync status events', () async {
      await fakeFirestore
          .collection('organizations')
          .doc('org1')
          .collection('chatRooms')
          .doc('room1')
          .set({
        'name': 'Test',
        'type': 'league',
        'participants': [],
        'isArchived': false,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await queueService.enqueue(makeMutation());

      final events = <SyncStatusEvent>[];
      queueService.syncStatusStream.listen(events.add);

      await queueService.replayQueue();

      // Allow stream events to propagate.
      await Future.delayed(Duration.zero);

      expect(events.any((e) => e.status == SyncStatus.syncing), isTrue);
      expect(events.any((e) => e.status == SyncStatus.completed), isTrue);
    });
  });

  group('OfflineQueueService - Pending Count Stream', () {
    test('emits count on enqueue', () async {
      final counts = <int>[];
      queueService.pendingCountStream.listen(counts.add);

      await queueService.enqueue(makeMutation(id: 'a'));
      await queueService.enqueue(makeMutation(id: 'b'));

      await Future.delayed(Duration.zero);
      expect(counts, [1, 2]);
    });

    test('emits count on dequeue', () async {
      await queueService.enqueue(makeMutation(id: 'a'));
      await queueService.enqueue(makeMutation(id: 'b'));

      final counts = <int>[];
      queueService.pendingCountStream.listen(counts.add);

      await queueService.dequeue('a');
      await Future.delayed(Duration.zero);
      expect(counts, [1]);
    });

    test('emits 0 on clearQueue', () async {
      await queueService.enqueue(makeMutation(id: 'a'));

      final counts = <int>[];
      queueService.pendingCountStream.listen(counts.add);

      await queueService.clearQueue();
      await Future.delayed(Duration.zero);
      expect(counts.last, 0);
    });
  });

  group('OfflineQueueService - Error Handling', () {
    test('unknown method does not throw during replay', () async {
      await queueService.enqueue(makeMutation(
        id: 'unknown-1',
        method: 'nonExistentMethod',
        params: {},
      ));

      // Should not throw — unknown methods are skipped.
      await queueService.replayQueue();
      expect(queueService.pendingCount, 0);
    });
  });

  group('SyncStatusEvent', () {
    test('started event has syncing status', () {
      expect(SyncStatusEvent.started.status, SyncStatus.syncing);
    });

    test('completed event contains counts', () {
      final event = SyncStatusEvent.completed(synced: 3, failed: 1);
      expect(event.status, SyncStatus.completed);
      expect(event.synced, 3);
      expect(event.failed, 1);
    });

    test('conflict event contains message', () {
      final event = SyncStatusEvent.conflict('test error');
      expect(event.status, SyncStatus.conflict);
      expect(event.message, 'test error');
    });
  });
}
