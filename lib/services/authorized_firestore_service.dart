import '../models/app_user.dart';
import '../models/announcement.dart';
import '../models/chat_room.dart';
import '../models/invitation.dart';
import 'firestore_service.dart';
import 'permission_service.dart';

/// Exception thrown when a user lacks permission for an operation.
class PermissionDeniedException implements Exception {
  final String action;
  final String userId;
  final UserRole role;

  PermissionDeniedException({
    required this.action,
    required this.userId,
    required this.role,
  });

  @override
  String toString() =>
      'PermissionDenied: user $userId (${role.name}) cannot $action';
}

/// Wraps [FirestoreService] with [PermissionService] checks on every
/// mutation. Read operations are left un-guarded here because the
/// provider layer handles scope filtering (tasks 61-63).
///
/// Screens and providers should use this instead of raw [FirestoreService]
/// for all write operations.
class AuthorizedFirestoreService {
  final FirestoreService _fs;
  final PermissionService _ps;

  AuthorizedFirestoreService(this._fs, this._ps);

  // -------------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------------

  Never _deny(String action, AppUser actor) =>
      throw PermissionDeniedException(
        action: action,
        userId: actor.id,
        role: actor.role,
      );

  // -------------------------------------------------------------------------
  // Organizations
  // -------------------------------------------------------------------------

  Future<void> updateOrganization(
      AppUser actor, String orgId, Map<String, dynamic> data) {
    if (!_ps.canEditBranding(actor)) _deny('updateOrganization', actor);
    return _fs.updateOrganization(orgId, data);
  }

  // -------------------------------------------------------------------------
  // Leagues
  // -------------------------------------------------------------------------

  Future<void> createLeague(AppUser actor, String orgId, league) {
    if (!_ps.canCreateLeague(actor)) _deny('createLeague', actor);
    return _fs.createLeague(orgId, league);
  }

  Future<void> deleteLeague(AppUser actor, String orgId, String leagueId) {
    if (!_ps.canDeleteLeague(actor)) _deny('deleteLeague', actor);
    return _fs.deleteLeague(orgId, leagueId);
  }

  /// Cascade-delete a league and all its children (hubs, teams).
  Future<void> deleteLeagueCascade(
      AppUser actor, String orgId, String leagueId) async {
    if (!_ps.canDeleteLeague(actor)) _deny('deleteLeagueCascade', actor);
    // Delete all teams in all hubs first.
    final hubs = await _fs.getHubs(orgId, leagueId).first;
    for (final hub in hubs) {
      final teams = await _fs.getTeams(orgId, leagueId, hub.id).first;
      for (final team in teams) {
        await _fs.deleteTeam(orgId, leagueId, hub.id, team.id);
      }
      await _fs.deleteHub(orgId, leagueId, hub.id);
    }
    await _fs.deleteLeague(orgId, leagueId);
  }

  // -------------------------------------------------------------------------
  // Hubs
  // -------------------------------------------------------------------------

  Future<void> createHub(AppUser actor, String orgId, String leagueId, hub) {
    if (!_ps.canCreateHub(actor, leagueId: leagueId)) {
      _deny('createHub', actor);
    }
    return _fs.createHub(orgId, leagueId, hub);
  }

  Future<void> deleteHub(
      AppUser actor, String orgId, String leagueId, String hubId) {
    if (!_ps.canDeleteHub(actor)) _deny('deleteHub', actor);
    return _fs.deleteHub(orgId, leagueId, hubId);
  }

  /// Cascade-delete a hub and all its teams.
  Future<void> deleteHubCascade(
      AppUser actor, String orgId, String leagueId, String hubId) async {
    if (!_ps.canDeleteHub(actor)) _deny('deleteHubCascade', actor);
    final teams = await _fs.getTeams(orgId, leagueId, hubId).first;
    for (final team in teams) {
      await _fs.deleteTeam(orgId, leagueId, hubId, team.id);
    }
    await _fs.deleteHub(orgId, leagueId, hubId);
  }

  // -------------------------------------------------------------------------
  // Teams
  // -------------------------------------------------------------------------

  Future<void> createTeam(
      AppUser actor, String orgId, String leagueId, String hubId, team) {
    if (!_ps.canCreateTeam(actor, hubId: hubId)) {
      _deny('createTeam', actor);
    }
    return _fs.createTeam(orgId, leagueId, hubId, team);
  }

  Future<void> deleteTeam(AppUser actor, String orgId, String leagueId,
      String hubId, String teamId) {
    if (!_ps.canDeleteTeam(actor, hubId: hubId)) {
      _deny('deleteTeam', actor);
    }
    return _fs.deleteTeam(orgId, leagueId, hubId, teamId);
  }

  Future<void> updateTeamFields(AppUser actor, String orgId, String leagueId,
      String hubId, String teamId, Map<String, dynamic> data) {
    if (!_ps.canCreateTeam(actor, hubId: hubId)) {
      _deny('updateTeamFields', actor);
    }
    return _fs.updateTeamFields(orgId, leagueId, hubId, teamId, data);
  }

  // -------------------------------------------------------------------------
  // Users
  // -------------------------------------------------------------------------

  Future<void> deactivateUser(AppUser actor, AppUser target) {
    if (!_ps.canDeactivateUser(actor, target)) {
      _deny('deactivateUser', actor);
    }
    return _fs.deactivateUser(target.id);
  }

  Future<void> reactivateUser(AppUser actor, AppUser target) {
    if (!_ps.canReactivateUser(actor, target)) {
      _deny('reactivateUser', actor);
    }
    return _fs.reactivateUser(target.id);
  }

  Future<void> updateUserFields(
      AppUser actor, AppUser target, Map<String, dynamic> data) {
    if (!_ps.canManageUser(actor, target)) {
      _deny('updateUserFields', actor);
    }
    return _fs.updateUserFields(target.id, data);
  }

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  Future<String> createChatRoom(
    AppUser actor,
    String orgId,
    String name,
    ChatRoomType type, {
    String? leagueId,
    List<String> participants = const [],
  }) {
    if (!_ps.canCreateChatRoom(actor)) _deny('createChatRoom', actor);
    return _fs.createChatRoom(orgId, name, type,
        leagueId: leagueId, participants: participants);
  }

  Future<void> archiveChatRoom(
      AppUser actor, String orgId, String roomId) {
    if (!_ps.canArchiveChatRoom(actor)) _deny('archiveChatRoom', actor);
    return _fs.archiveChatRoom(orgId, roomId);
  }

  /// Sends a message, enforcing that senderId matches actor.id.
  Future<void> sendMessage(
    AppUser actor,
    String orgId,
    String roomId, {
    required String text,
  }) {
    if (!_ps.canSendMessage(actor)) _deny('sendMessage', actor);
    return _fs.sendMessage(
      orgId,
      roomId,
      senderId: actor.id,
      senderName: actor.displayName,
      text: text,
    );
  }

  /// Marks messages as read — requires active user.
  Future<void> markMessagesAsRead(
      AppUser actor, String orgId, String roomId) {
    if (!_ps.canSendMessage(actor)) _deny('markMessagesAsRead', actor);
    return _fs.markMessagesAsRead(orgId, roomId, actor.id);
  }

  /// Sets the typing indicator — requires active user.
  Future<void> setTyping(AppUser actor, String orgId, String roomId) {
    if (!_ps.canSendMessage(actor)) _deny('setTyping', actor);
    return _fs.setTyping(orgId, roomId, actor.id, actor.displayName);
  }

  /// Clears the typing indicator.
  Future<void> clearTyping(AppUser actor, String orgId, String roomId) {
    return _fs.clearTyping(orgId, roomId, actor.id);
  }

  /// Sends a media message, enforcing that senderId matches actor.id.
  Future<void> sendMediaMessage(
    AppUser actor,
    String orgId,
    String roomId, {
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) {
    if (!_ps.canSendMessage(actor)) _deny('sendMediaMessage', actor);
    return _fs.sendMediaMessage(orgId, roomId,
        senderId: actor.id,
        senderName: actor.displayName,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        caption: caption);
  }

  /// Updates a message — only the original sender may edit.
  Future<void> updateMessage(
    AppUser actor,
    String orgId,
    String roomId,
    String messageId,
    String newText, {
    required String senderId,
  }) {
    if (!_ps.canUpdateMessage(actor, senderId: senderId)) {
      _deny('updateMessage', actor);
    }
    return _fs.updateMessage(orgId, roomId, messageId, newText);
  }

  /// Deletes a message — sender or superAdmin+ may delete.
  Future<void> deleteMessage(
    AppUser actor,
    String orgId,
    String roomId,
    String messageId, {
    required String senderId,
  }) {
    if (!_ps.canDeleteMessage(actor, senderId: senderId)) {
      _deny('deleteMessage', actor);
    }
    return _fs.deleteMessage(orgId, roomId, messageId);
  }

  // -------------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------------

  Future<String> createDocument(
      AppUser actor, String orgId, Map<String, dynamic> docData,
      {String? docId}) {
    if (!_ps.canUploadDocument(actor)) _deny('createDocument', actor);
    return _fs.createDocument(orgId, docData, docId: docId);
  }

  Future<void> updateDocument(AppUser actor, String orgId, String docId,
      Map<String, dynamic> data,
      {required String uploadedBy}) {
    if (!_ps.canEditDocument(actor, uploadedBy: uploadedBy)) {
      _deny('updateDocument', actor);
    }
    return _fs.updateDocument(orgId, docId, data);
  }

  Future<void> deleteDocument(AppUser actor, String orgId, String docId) {
    if (!_ps.canDeleteDocument(actor)) _deny('deleteDocument', actor);
    return _fs.deleteDocument(orgId, docId);
  }

  Future<void> addDocumentVersion(
      AppUser actor, String orgId, String docId, Map<String, dynamic> data) {
    if (!_ps.canUploadDocument(actor)) _deny('addDocumentVersion', actor);
    return _fs.addDocumentVersion(orgId, docId, data);
  }

  // -------------------------------------------------------------------------
  // Announcements
  // -------------------------------------------------------------------------

  Future<String> createAnnouncement(
    AppUser actor,
    String orgId,
    Map<String, dynamic> data, {
    required AnnouncementScope scope,
    String? hubId,
  }) {
    if (!_ps.canCreateAnnouncementWithScope(actor, scope, hubId: hubId)) {
      _deny('createAnnouncement', actor);
    }
    return _fs.createAnnouncement(orgId, data);
  }

  Future<void> updateAnnouncement(AppUser actor, String orgId,
      String announcementId, Map<String, dynamic> data,
      {required String authorId}) {
    if (!_ps.canEditAnnouncement(actor, authorId: authorId)) {
      _deny('updateAnnouncement', actor);
    }
    return _fs.updateAnnouncement(orgId, announcementId, data);
  }

  Future<void> deleteAnnouncement(
      AppUser actor, String orgId, String announcementId) {
    if (!_ps.canDeleteAnnouncement(actor)) {
      _deny('deleteAnnouncement', actor);
    }
    return _fs.deleteAnnouncement(orgId, announcementId);
  }

  Future<void> togglePin(
      AppUser actor, String orgId, String announcementId, bool isPinned) {
    if (!_ps.canTogglePin(actor)) _deny('togglePin', actor);
    return _fs.togglePin(orgId, announcementId, isPinned);
  }

  // -------------------------------------------------------------------------
  // Invitations
  // -------------------------------------------------------------------------

  Future<String> createInvitation(
      AppUser actor, String orgId, Invitation invitation) {
    if (!_ps.canCreateInvitation(actor)) {
      _deny('createInvitation', actor);
    }
    // Verify hub-level scope for managerAdmin.
    for (final hubId in invitation.hubIds) {
      if (!_ps.canInviteToHub(actor, hubId)) {
        _deny('createInvitation (hub $hubId)', actor);
      }
    }
    return _fs.createInvitation(orgId, invitation);
  }

  /// Validates and accepts an invitation, checking expiry.
  Future<void> acceptInvitation(String orgId, String inviteId,
      {required DateTime invitedAt, int expiryDays = 7}) {
    final expiry = invitedAt.add(Duration(days: expiryDays));
    if (DateTime.now().isAfter(expiry)) {
      throw StateError('Invitation has expired');
    }
    return _fs.acceptInvitation(orgId, inviteId);
  }

  // -------------------------------------------------------------------------
  // Delegation — read operations pass through to raw service
  // -------------------------------------------------------------------------

  FirestoreService get raw => _fs;
}
