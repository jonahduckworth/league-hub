import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/organization.dart';
import '../models/league.dart';
import '../models/hub.dart';
import '../models/team.dart';
import '../models/app_user.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/document.dart';
import '../models/announcement.dart';
import '../core/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Helpers ---

  CollectionReference _chatRoomsRef(String orgId) => _db
      .collection(AppConstants.orgsCollection)
      .doc(orgId)
      .collection(AppConstants.chatRoomsCollection);

  CollectionReference _messagesRef(String orgId, String roomId) =>
      _chatRoomsRef(orgId).doc(roomId).collection(AppConstants.messagesCollection);

  /// Recursively converts Firestore Timestamp objects to ISO strings so models
  /// can parse them without importing cloud_firestore.
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _convertTimestamps(value));
      }
      return MapEntry(key, value);
    });
  }

  // --- Organizations ---

  Future<Organization?> getOrganization(String orgId) async {
    final doc = await _db.collection(AppConstants.orgsCollection).doc(orgId).get();
    if (!doc.exists) return null;
    return Organization.fromJson({'id': doc.id, ...doc.data()!});
  }

  // --- Leagues ---

  Stream<List<League>> leaguesStream(String orgId) {
    return _db
        .collection(AppConstants.leaguesCollection)
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => League.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  // --- Hubs ---

  Stream<List<Hub>> hubsStream(String orgId, {String? leagueId}) {
    Query query = _db
        .collection(AppConstants.hubsCollection)
        .where('orgId', isEqualTo: orgId);
    if (leagueId != null) query = query.where('leagueId', isEqualTo: leagueId);
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => Hub.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>})).toList());
  }

  // --- Teams ---

  Stream<List<Team>> teamsStream(String orgId, {String? hubId}) {
    Query query = _db
        .collection(AppConstants.teamsCollection)
        .where('orgId', isEqualTo: orgId);
    if (hubId != null) query = query.where('hubId', isEqualTo: hubId);
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => Team.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>})).toList());
  }

  // --- Users ---

  Future<AppUser?> getUser(String userId) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromJson({'id': doc.id, ...doc.data()!});
  }

  Future<void> updateUser(AppUser user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .set(user.toJson(), SetOptions(merge: true));
  }

  // --- Chat Rooms ---

  /// Creates a new chat room under organizations/{orgId}/chatRooms.
  Future<String> createChatRoom(
    String orgId,
    String name,
    ChatRoomType type, {
    String? leagueId,
  }) async {
    final ref = _chatRoomsRef(orgId).doc();
    await ref.set({
      'orgId': orgId,
      'name': name,
      'type': type.name,
      'leagueId': leagueId,
      'participants': [],
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Stream of all non-archived chat rooms for [orgId], sorted by most recent message.
  Stream<List<ChatRoom>> getChatRooms(String orgId) {
    return _chatRoomsRef(orgId)
        .where('isArchived', isEqualTo: false)
        .snapshots()
        .map((snap) {
      final rooms = snap.docs
          .map((d) => ChatRoom.fromJson(
              {'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
          .toList();
      // Sort client-side: rooms with messages first, then by recency.
      rooms.sort((a, b) {
        if (a.lastMessageAt == null && b.lastMessageAt == null) return 0;
        if (a.lastMessageAt == null) return 1;
        if (b.lastMessageAt == null) return -1;
        return b.lastMessageAt!.compareTo(a.lastMessageAt!);
      });
      return rooms;
    });
  }

  /// Stream of a single chat room document.
  Stream<ChatRoom?> getChatRoom(String orgId, String roomId) {
    return _chatRoomsRef(orgId).doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatRoom.fromJson(
          {'id': doc.id, ..._convertTimestamps(doc.data() as Map<String, dynamic>)});
    });
  }

  /// Finds an existing DM room between two users or creates one.
  Future<ChatRoom> getOrCreateDirectMessage(
      String orgId, String userId1, String userId2) async {
    final participants = ([userId1, userId2]..sort());
    final query = await _chatRoomsRef(orgId)
        .where('type', isEqualTo: 'direct')
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return ChatRoom.fromJson(
          {'id': doc.id, ..._convertTimestamps(doc.data() as Map<String, dynamic>)});
    }

    final roomRef = _chatRoomsRef(orgId).doc();
    await roomRef.set({
      'orgId': orgId,
      'name': 'Direct Message',
      'type': 'direct',
      'participants': participants,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    final roomDoc = await roomRef.get();
    return ChatRoom.fromJson(
        {'id': roomRef.id, ..._convertTimestamps(roomDoc.data() as Map<String, dynamic>)});
  }

  // --- Messages ---

  /// Stream of messages in a room, oldest first.
  Stream<List<Message>> getMessages(String orgId, String roomId) {
    return _messagesRef(orgId, roomId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Message.fromJson(
                {'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
            .toList());
  }

  /// Sends a message and updates the room's last-message preview atomically.
  Future<void> sendMessage(
    String orgId,
    String roomId, {
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final batch = _db.batch();

    final msgRef = _messagesRef(orgId, roomId).doc();
    batch.set(msgRef, {
      'chatRoomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [senderId],
    });

    final roomRef = _chatRoomsRef(orgId).doc(roomId);
    batch.update(roomRef, {
      'lastMessage': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // --- Documents ---

  Stream<List<Document>> documentsStream(String orgId, {String? leagueId, String? category}) {
    Query query = _db
        .collection(AppConstants.documentsCollection)
        .where('orgId', isEqualTo: orgId);
    if (leagueId != null) query = query.where('leagueId', isEqualTo: leagueId);
    if (category != null && category != 'All') query = query.where('category', isEqualTo: category);
    return query
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Document.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>}))
            .toList());
  }

  Future<void> uploadDocument(Document doc) async {
    await _db
        .collection(AppConstants.documentsCollection)
        .doc(doc.id)
        .set(doc.toJson());
  }

  // --- Announcements ---

  Stream<List<Announcement>> announcementsStream(String orgId, {String? leagueId}) {
    Query query = _db
        .collection(AppConstants.announcementsCollection)
        .where('orgId', isEqualTo: orgId);
    if (leagueId != null) query = query.where('leagueId', isEqualTo: leagueId);
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Announcement.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>}))
            .toList());
  }

  Future<void> createAnnouncement(Announcement announcement) async {
    await _db
        .collection(AppConstants.announcementsCollection)
        .doc(announcement.id)
        .set(announcement.toJson());
  }
}
