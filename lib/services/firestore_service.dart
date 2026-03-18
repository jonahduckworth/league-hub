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

  // Organizations
  Future<Organization?> getOrganization(String orgId) async {
    final doc = await _db.collection(AppConstants.orgsCollection).doc(orgId).get();
    if (!doc.exists) return null;
    return Organization.fromJson({'id': doc.id, ...doc.data()!});
  }

  // Leagues
  Stream<List<League>> leaguesStream(String orgId) {
    return _db
        .collection(AppConstants.leaguesCollection)
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => League.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  // Hubs
  Stream<List<Hub>> hubsStream(String orgId, {String? leagueId}) {
    Query query = _db
        .collection(AppConstants.hubsCollection)
        .where('orgId', isEqualTo: orgId);
    if (leagueId != null) query = query.where('leagueId', isEqualTo: leagueId);
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => Hub.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>})).toList());
  }

  // Teams
  Stream<List<Team>> teamsStream(String orgId, {String? hubId}) {
    Query query = _db
        .collection(AppConstants.teamsCollection)
        .where('orgId', isEqualTo: orgId);
    if (hubId != null) query = query.where('hubId', isEqualTo: hubId);
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => Team.fromJson({'id': d.id, ...d.data() as Map<String, dynamic>})).toList());
  }

  // Users
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

  // Chat Rooms
  Stream<List<ChatRoom>> chatRoomsStream(String orgId) {
    return _db
        .collection(AppConstants.chatRoomsCollection)
        .where('orgId', isEqualTo: orgId)
        .where('isArchived', isEqualTo: false)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatRoom.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  // Messages
  Stream<List<Message>> messagesStream(String chatRoomId) {
    return _db
        .collection(AppConstants.chatRoomsCollection)
        .doc(chatRoomId)
        .collection(AppConstants.messagesCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Message.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  Future<void> sendMessage(Message message) async {
    final batch = _db.batch();
    final msgRef = _db
        .collection(AppConstants.chatRoomsCollection)
        .doc(message.chatRoomId)
        .collection(AppConstants.messagesCollection)
        .doc();
    batch.set(msgRef, message.toJson());
    final roomRef = _db
        .collection(AppConstants.chatRoomsCollection)
        .doc(message.chatRoomId);
    batch.update(roomRef, {
      'lastMessage': message.text,
      'lastMessageAt': message.createdAt.toIso8601String(),
    });
    await batch.commit();
  }

  // Documents
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

  // Announcements
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
