import 'dart:math';

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
import '../models/invitation.dart';
import '../core/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // --- Helpers ---

  CollectionReference _chatRoomsRef(String orgId) => _db
      .collection(AppConstants.orgsCollection)
      .doc(orgId)
      .collection(AppConstants.chatRoomsCollection);

  CollectionReference _messagesRef(String orgId, String roomId) =>
      _chatRoomsRef(orgId).doc(roomId).collection(AppConstants.messagesCollection);

  CollectionReference _leaguesRef(String orgId) => _db
      .collection(AppConstants.orgsCollection)
      .doc(orgId)
      .collection('leagues');

  CollectionReference _hubsRef(String orgId, String leagueId) =>
      _leaguesRef(orgId).doc(leagueId).collection('hubs');

  CollectionReference _teamsRef(String orgId, String leagueId, String hubId) =>
      _hubsRef(orgId, leagueId).doc(hubId).collection('teams');

  /// Recursively converts Firestore Timestamp objects to ISO strings so models
  /// can parse them without importing cloud_firestore.
  dynamic _convertValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is Map<String, dynamic>) {
      return _convertTimestamps(value);
    }
    if (value is List) {
      return value.map(_convertValue).toList();
    }
    return value;
  }

  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _convertValue(value)));
  }

  // --- Organizations ---

  Future<Organization?> getOrganization(String orgId) async {
    final doc = await _db.collection(AppConstants.orgsCollection).doc(orgId).get();
    if (!doc.exists) return null;
    return Organization.fromJson(
        {'id': doc.id, ..._convertTimestamps(doc.data()!)});
  }

  Future<void> createOrganization(Organization org) =>
      _db.collection(AppConstants.orgsCollection).doc(org.id).set(org.toJson());

  Future<void> updateOrganization(String orgId, Map<String, dynamic> data) =>
      _db.collection(AppConstants.orgsCollection).doc(orgId).update(data);

  // --- Leagues (subcollection) ---

  Stream<List<League>> getLeagues(String orgId) => _leaguesRef(orgId)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => League.fromJson(
              {'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
          .toList());

  Future<void> createLeague(String orgId, League league) =>
      _leaguesRef(orgId).doc(league.id).set(league.toJson());

  Future<void> deleteLeague(String orgId, String leagueId) =>
      _leaguesRef(orgId).doc(leagueId).delete();

  // --- Hubs (subcollection) ---

  Stream<List<Hub>> getHubs(String orgId, String leagueId) =>
      _hubsRef(orgId, leagueId)
          .orderBy('createdAt')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Hub.fromJson({'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
              .toList());

  Future<void> createHub(String orgId, String leagueId, Hub hub) =>
      _hubsRef(orgId, leagueId).doc(hub.id).set(hub.toJson());

  Future<void> deleteHub(String orgId, String leagueId, String hubId) =>
      _hubsRef(orgId, leagueId).doc(hubId).delete();

  // --- Teams (subcollection) ---

  Stream<List<Team>> getTeams(String orgId, String leagueId, String hubId) =>
      _teamsRef(orgId, leagueId, hubId)
          .orderBy('createdAt')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Team.fromJson({'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
              .toList());

  Future<void> createTeam(
          String orgId, String leagueId, String hubId, Team team) =>
      _teamsRef(orgId, leagueId, hubId).doc(team.id).set(team.toJson());

  Future<void> deleteTeam(
          String orgId, String leagueId, String hubId, String teamId) =>
      _teamsRef(orgId, leagueId, hubId).doc(teamId).delete();

  // --- ID generators (for creating documents with known IDs) ---

  String newLeagueId(String orgId) => _leaguesRef(orgId).doc().id;
  String newHubId(String orgId, String leagueId) =>
      _hubsRef(orgId, leagueId).doc().id;
  String newTeamId(String orgId, String leagueId, String hubId) =>
      _teamsRef(orgId, leagueId, hubId).doc().id;

  // --- Counts ---

  Future<int> getAllHubsCount(String orgId) async {
    final leagueSnap = await _leaguesRef(orgId).get();
    int count = 0;
    for (final leagueDoc in leagueSnap.docs) {
      final hubSnap = await _hubsRef(orgId, leagueDoc.id).get();
      count += hubSnap.size;
    }
    return count;
  }

  Future<int> getAllTeamsCount(String orgId) async {
    final leagueSnap = await _leaguesRef(orgId).get();
    int count = 0;
    for (final leagueDoc in leagueSnap.docs) {
      final hubSnap = await _hubsRef(orgId, leagueDoc.id).get();
      for (final hubDoc in hubSnap.docs) {
        final teamSnap = await _teamsRef(orgId, leagueDoc.id, hubDoc.id).get();
        count += teamSnap.size;
      }
    }
    return count;
  }

  // --- Users ---

  Future<AppUser?> getUser(String userId) async {
    final doc =
        await _db.collection(AppConstants.usersCollection).doc(userId).get();
    if (!doc.exists) return null;
    return AppUser.fromJson(
        {'id': doc.id, ..._convertTimestamps(doc.data()!)});
  }

  Future<void> updateUser(AppUser user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.id)
        .set(user.toJson(), SetOptions(merge: true));
  }

  Stream<List<AppUser>> getOrgUsers(String orgId) {
    return _db
        .collection(AppConstants.usersCollection)
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppUser.fromJson(
                {'id': d.id, ..._convertTimestamps(d.data())}))
            .toList());
  }

  Future<AppUser?> getUserById(String uid) => getUser(uid);

  Future<void> updateUserFields(String uid, Map<String, dynamic> data) =>
      _db.collection(AppConstants.usersCollection).doc(uid).update(data);

  Future<void> deactivateUser(String uid) =>
      updateUserFields(uid, {'isActive': false});

  Future<void> reactivateUser(String uid) =>
      updateUserFields(uid, {'isActive': true});

  // --- Chat Rooms ---

  /// Creates a new chat room under organizations/{orgId}/chatRooms.
  Future<String> createChatRoom(
    String orgId,
    String name,
    ChatRoomType type, {
    String? leagueId,
    List<String> participants = const [],
  }) async {
    final ref = _chatRoomsRef(orgId).doc();
    await ref.set({
      'orgId': orgId,
      'name': name,
      'type': type.name,
      'leagueId': leagueId,
      'participants': participants,
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': null,
    });
    return ref.id;
  }

  /// Archives a chat room (soft delete).
  Future<void> archiveChatRoom(String orgId, String roomId) =>
      _chatRoomsRef(orgId).doc(roomId).update({'isArchived': true});

  /// Auto-creates a "General" chat room for each league that doesn't already have one.
  Future<void> createLeagueChatRooms(
      String orgId, List<Map<String, String>> leagues) async {
    for (final league in leagues) {
      final leagueId = league['id']!;
      final leagueName = league['name']!;
      // Check if a General room already exists for this league.
      final existing = await _chatRoomsRef(orgId)
          .where('type', isEqualTo: 'league')
          .where('leagueId', isEqualTo: leagueId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      final ref = _chatRoomsRef(orgId).doc();
      await ref.set({
        'orgId': orgId,
        'name': '$leagueName – General',
        'type': 'league',
        'leagueId': leagueId,
        'participants': [],
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': null,
      });
    }
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
  /// [name1] and [name2] are the display names of uid1 and uid2 respectively.
  Future<ChatRoom> getOrCreateDMRoom(
      String orgId, String uid1, String uid2, String name1, String name2) async {
    final participants = ([uid1, uid2]..sort());
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
    // Store both names so either participant can reconstruct the other's name.
    final roomName = '$name1 & $name2';
    await roomRef.set({
      'orgId': orgId,
      'name': roomName,
      'type': 'direct',
      'participants': participants,
      'participantNames': {uid1: name1, uid2: name2},
      'isArchived': false,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': null,
    });
    final roomDoc = await roomRef.get();
    return ChatRoom.fromJson(
        {'id': roomRef.id, ..._convertTimestamps(roomDoc.data() as Map<String, dynamic>)});
  }

  // --- Messages ---

  /// Stream of messages in a room, oldest first (capped at 100 most recent).
  Stream<List<Message>> getMessages(String orgId, String roomId) {
    return _messagesRef(orgId, roomId)
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
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
      'lastMessageBy': senderName,
    });

    await batch.commit();
  }

  // --- Documents ---

  CollectionReference _documentsRef(String orgId) => _db
      .collection(AppConstants.orgsCollection)
      .doc(orgId)
      .collection('documents');

  String newDocumentId(String orgId) => _documentsRef(orgId).doc().id;

  Document _docFromSnap(DocumentSnapshot d, String orgId) => Document.fromJson(
      {'id': d.id, 'orgId': orgId, ..._convertTimestamps(d.data() as Map<String, dynamic>)});

  /// Stream of all documents for an org, client-side filtered by leagueId/category.
  Stream<List<Document>> documentsStream(String orgId,
      {String? leagueId, String? category}) {
    return _documentsRef(orgId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) {
      var docs = snap.docs.map((d) => _docFromSnap(d, orgId)).toList();
      if (leagueId != null) {
        docs = docs.where((d) => d.leagueId == leagueId).toList();
      }
      if (category != null) {
        docs = docs.where((d) => d.category == category).toList();
      }
      return docs;
    });
  }

  Stream<List<Document>> getDocuments(String orgId) =>
      documentsStream(orgId);

  Stream<List<Document>> getDocumentsByLeague(String orgId, String leagueId) =>
      documentsStream(orgId, leagueId: leagueId);

  Stream<List<Document>> getDocumentsByCategory(
          String orgId, String category) =>
      documentsStream(orgId, category: category);

  Stream<Document?> getDocumentById(String orgId, String docId) {
    return _documentsRef(orgId).doc(docId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _docFromSnap(snap, orgId);
    });
  }

  Future<String> createDocument(String orgId, Map<String, dynamic> docData,
      {String? docId}) async {
    final ref = docId != null
        ? _documentsRef(orgId).doc(docId)
        : _documentsRef(orgId).doc();
    await ref.set({
      ...docData,
      'orgId': orgId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateDocument(
      String orgId, String docId, Map<String, dynamic> data) async {
    await _documentsRef(orgId).doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDocument(String orgId, String docId) async {
    await _documentsRef(orgId).doc(docId).delete();
  }

  Future<void> addDocumentVersion(
      String orgId, String docId, Map<String, dynamic> versionData) async {
    await _db.runTransaction((transaction) async {
      final docRef = _documentsRef(orgId).doc(docId);
      final snap = await transaction.get(docRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final currentVersions =
          List<Map<String, dynamic>>.from(data['versions'] as List? ?? []);
      final newVersion = {
        ...versionData,
        'version': currentVersions.length + 1,
      };
      transaction.update(docRef, {
        'versions': [...currentVersions, newVersion],
        'fileUrl': versionData['url'],
        'fileSize': versionData['fileSize'],
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // --- Announcements ---

  CollectionReference _announcementsRef(String orgId) => _db
      .collection(AppConstants.orgsCollection)
      .doc(orgId)
      .collection('announcements');

  /// Stream of all announcements for an org, pinned first then newest.
  Stream<List<Announcement>> getAnnouncements(String orgId) {
    return _announcementsRef(orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => Announcement.fromJson(
              {'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
          .toList();
      // Sort pinned first, then by date descending.
      list.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  /// Stream of announcements filtered to orgWide OR a specific league.
  Stream<List<Announcement>> getAnnouncementsByLeague(
      String orgId, String leagueId) {
    return getAnnouncements(orgId).map((list) => list
        .where((a) =>
            a.scope == AnnouncementScope.orgWide || a.leagueId == leagueId)
        .toList());
  }

  /// Creates a new announcement using serverTimestamp. Returns the new doc ID.
  Future<String> createAnnouncement(
      String orgId, Map<String, dynamic> data) async {
    final ref = _announcementsRef(orgId).doc();
    await ref.set({
      ...data,
      'orgId': orgId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // TODO(FCM): Trigger push notification to org members here via Cloud Function or FCM direct send.
    return ref.id;
  }

  Future<void> updateAnnouncement(
      String orgId, String announcementId, Map<String, dynamic> data) async {
    await _announcementsRef(orgId).doc(announcementId).update(data);
  }

  Future<void> deleteAnnouncement(
      String orgId, String announcementId) async {
    await _announcementsRef(orgId).doc(announcementId).delete();
  }

  Future<void> togglePin(
      String orgId, String announcementId, bool isPinned) async {
    await _announcementsRef(orgId)
        .doc(announcementId)
        .update({'isPinned': isPinned});
  }

  // --- Invitations ---

  CollectionReference _invitationsRef(String orgId) => _db
      .collection(AppConstants.orgsCollection)
      .doc(orgId)
      .collection('invitations');

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> createInvitation(String orgId, Invitation invitation) async {
    final ref = _invitationsRef(orgId).doc();
    final token = _generateToken();
    final data = invitation.toJson()
      ..['token'] = token
      ..['orgId'] = orgId;
    await ref.set(data);
    return token;
  }

  Stream<List<Invitation>> getInvitations(String orgId) {
    return _invitationsRef(orgId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Invitation.fromJson(
                {'id': d.id, ..._convertTimestamps(d.data() as Map<String, dynamic>)}))
            .toList());
  }

  Future<Invitation?> getInvitationByToken(String token) async {
    final snap = await _db
        .collectionGroup('invitations')
        .where('token', isEqualTo: token)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return Invitation.fromJson(
        {'id': doc.id, ..._convertTimestamps(doc.data())});
  }

  Future<void> acceptInvitation(String orgId, String inviteId) =>
      _invitationsRef(orgId)
          .doc(inviteId)
          .update({'status': InvitationStatus.accepted.name});

  // --- All Hubs Flat ---

  Future<List<Hub>> getAllHubsFlat(String orgId) async {
    final leagueSnap = await _leaguesRef(orgId).get();
    final hubs = <Hub>[];
    for (final leagueDoc in leagueSnap.docs) {
      final hubSnap = await _hubsRef(orgId, leagueDoc.id).get();
      for (final hubDoc in hubSnap.docs) {
        hubs.add(Hub.fromJson({
          'id': hubDoc.id,
          ..._convertTimestamps(hubDoc.data() as Map<String, dynamic>)
        }));
      }
    }
    return hubs;
  }

  Future<int> getActiveUserCount(String orgId) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .where('orgId', isEqualTo: orgId)
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
