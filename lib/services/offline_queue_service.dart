import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/queued_mutation.dart';
import 'firestore_service.dart';

/// Manages a persistent queue of Firestore mutations that can be replayed
/// when the device regains connectivity.
class OfflineQueueService {
  static const String _boxName = 'offline_mutations';
  static const int _maxRetries = 3;

  final FirestoreService _firestoreService;
  final Connectivity _connectivity;
  final Box<String> _box;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isReplaying = false;

  /// Stream controller for pending mutation count changes.
  final _pendingCountController = StreamController<int>.broadcast();

  /// Stream of the current pending mutation count.
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  /// Stream controller for sync status events (e.g., conflict notifications).
  final _syncStatusController = StreamController<SyncStatusEvent>.broadcast();

  /// Stream of sync status events for UI feedback.
  Stream<SyncStatusEvent> get syncStatusStream => _syncStatusController.stream;

  OfflineQueueService({
    required FirestoreService firestoreService,
    required Box<String> box,
    Connectivity? connectivity,
  })  : _firestoreService = firestoreService,
        _box = box,
        _connectivity = connectivity ?? Connectivity();

  /// Opens the Hive box and starts listening for connectivity changes.
  static Future<OfflineQueueService> initialize(
    FirestoreService firestoreService, {
    Connectivity? connectivity,
  }) async {
    final box = await Hive.openBox<String>(_boxName);
    final service = OfflineQueueService(
      firestoreService: firestoreService,
      box: box,
      connectivity: connectivity,
    );
    service._startListening();
    return service;
  }

  /// Creates an instance with a pre-opened box (useful for testing).
  factory OfflineQueueService.withBox({
    required FirestoreService firestoreService,
    required Box<String> box,
    Connectivity? connectivity,
  }) {
    return OfflineQueueService(
      firestoreService: firestoreService,
      box: box,
      connectivity: connectivity,
    );
  }

  void _startListening() {
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);
    if (online && !_isReplaying && pendingCount > 0) {
      replayQueue();
    }
  }

  // ---------------------------------------------------------------------------
  // Queue Operations
  // ---------------------------------------------------------------------------

  /// Number of mutations currently in the queue.
  int get pendingCount => _box.length;

  /// Returns all queued mutations in order.
  List<QueuedMutation> get pendingMutations {
    return _box.values.map((json) {
      return QueuedMutation.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Enqueues a mutation for later replay.
  Future<void> enqueue(QueuedMutation mutation) async {
    await _box.put(mutation.id, jsonEncode(mutation.toJson()));
    _emitCount();
  }

  /// Removes a specific mutation from the queue.
  Future<void> dequeue(String mutationId) async {
    await _box.delete(mutationId);
    _emitCount();
  }

  /// Clears the entire queue.
  Future<void> clearQueue() async {
    await _box.clear();
    _emitCount();
  }

  /// Replays all queued mutations in order, handling errors gracefully.
  Future<void> replayQueue() async {
    if (_isReplaying) return;
    _isReplaying = true;
    _syncStatusController.add(SyncStatusEvent.started);

    final mutations = pendingMutations;
    int successCount = 0;
    int failCount = 0;

    for (final mutation in mutations) {
      try {
        await _executeMutation(mutation);
        await dequeue(mutation.id);
        successCount++;
      } catch (e) {
        mutation.retryCount++;
        if (mutation.retryCount >= _maxRetries) {
          // Give up on this mutation — notify the user.
          await dequeue(mutation.id);
          failCount++;
          _syncStatusController.add(SyncStatusEvent.conflict(
            'Failed to sync "${mutation.method}" after $_maxRetries retries: $e',
          ));
        } else {
          // Update retry count in the box.
          await _box.put(mutation.id, jsonEncode(mutation.toJson()));
        }
      }
    }

    _isReplaying = false;
    _emitCount();
    _syncStatusController.add(SyncStatusEvent.completed(
      synced: successCount,
      failed: failCount,
    ));
  }

  /// Executes a single mutation against the Firestore service.
  Future<void> _executeMutation(QueuedMutation mutation) async {
    final p = mutation.params;

    switch (mutation.method) {
      case 'sendMessage':
        await _firestoreService.sendMessage(
          p['orgId'] as String,
          p['roomId'] as String,
          senderId: p['senderId'] as String,
          senderName: p['senderName'] as String,
          text: p['text'] as String,
        );
        break;

      case 'createAnnouncement':
        await _firestoreService.createAnnouncement(
          p['orgId'] as String,
          Map<String, dynamic>.from(p['data'] as Map),
        );
        break;

      case 'updateAnnouncement':
        await _firestoreService.updateAnnouncement(
          p['orgId'] as String,
          p['announcementId'] as String,
          Map<String, dynamic>.from(p['data'] as Map),
        );
        break;

      case 'deleteAnnouncement':
        await _firestoreService.deleteAnnouncement(
          p['orgId'] as String,
          p['announcementId'] as String,
        );
        break;

      case 'createDocument':
        await _firestoreService.createDocument(
          p['orgId'] as String,
          Map<String, dynamic>.from(p['data'] as Map),
        );
        break;

      case 'updateDocument':
        await _firestoreService.updateDocument(
          p['orgId'] as String,
          p['docId'] as String,
          Map<String, dynamic>.from(p['data'] as Map),
        );
        break;

      case 'deleteDocument':
        await _firestoreService.deleteDocument(
          p['orgId'] as String,
          p['docId'] as String,
        );
        break;

      case 'togglePin':
        await _firestoreService.togglePin(
          p['orgId'] as String,
          p['announcementId'] as String,
          p['isPinned'] as bool,
        );
        break;

      case 'archiveChatRoom':
        await _firestoreService.archiveChatRoom(
          p['orgId'] as String,
          p['roomId'] as String,
        );
        break;

      case 'sendMediaMessage':
        await _firestoreService.sendMediaMessage(
          p['orgId'] as String,
          p['roomId'] as String,
          senderId: p['senderId'] as String,
          senderName: p['senderName'] as String,
          mediaUrl: p['mediaUrl'] as String,
          mediaType: p['mediaType'] as String,
          caption: p['caption'] as String?,
        );
        break;

      case 'updateMessage':
        await _firestoreService.updateMessage(
          p['orgId'] as String,
          p['roomId'] as String,
          p['messageId'] as String,
          p['newText'] as String,
        );
        break;

      case 'deleteMessage':
        await _firestoreService.deleteMessage(
          p['orgId'] as String,
          p['roomId'] as String,
          p['messageId'] as String,
        );
        break;

      case 'updateTeamFields':
        await _firestoreService.updateTeamFields(
          p['orgId'] as String,
          p['leagueId'] as String,
          p['hubId'] as String,
          p['teamId'] as String,
          Map<String, dynamic>.from(p['data'] as Map),
        );
        break;

      default:
        debugPrint('OfflineQueueService: Unknown method ${mutation.method}');
    }
  }

  void _emitCount() {
    _pendingCountController.add(pendingCount);
  }

  /// Disposes subscriptions and controllers.
  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    await _pendingCountController.close();
    await _syncStatusController.close();
  }
}

/// Events emitted during queue replay.
class SyncStatusEvent {
  final SyncStatus status;
  final String? message;
  final int synced;
  final int failed;

  const SyncStatusEvent._({
    required this.status,
    this.message,
    this.synced = 0,
    this.failed = 0,
  });

  static const started = SyncStatusEvent._(status: SyncStatus.syncing);

  factory SyncStatusEvent.completed({int synced = 0, int failed = 0}) =>
      SyncStatusEvent._(
        status: SyncStatus.completed,
        synced: synced,
        failed: failed,
      );

  factory SyncStatusEvent.conflict(String message) => SyncStatusEvent._(
        status: SyncStatus.conflict,
        message: message,
      );
}

enum SyncStatus { syncing, completed, conflict }
