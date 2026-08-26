import '../models/app_user.dart';
import '../models/announcement.dart';
import '../models/chat_room.dart';
import '../models/invitation.dart';
import '../models/message.dart';
import '../models/team.dart';
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

  Never _deny(String action, AppUser actor) => throw PermissionDeniedException(
        action: action,
        userId: actor.id,
        role: actor.role,
      );

  // -------------------------------------------------------------------------
  // Organizations
  // -------------------------------------------------------------------------

  Future<void> updateOrganization(
      AppUser actor, String orgId, Map<String, dynamic> data) {
    if (!_ps.canUpdateOrganization(actor)) _deny('updateOrganization', actor);
    const allowedFields = {
      'name',
      'logoUrl',
      'primaryColor',
      'secondaryColor',
      'accentColor',
    };
    if (data.keys.any((key) => !allowedFields.contains(key))) {
      _deny('updateOrganization immutable fields', actor);
    }
    return _fs.updateOrganization(orgId, data);
  }

  // -------------------------------------------------------------------------
  // Leagues
  // -------------------------------------------------------------------------

  Future<void> createLeague(AppUser actor, String orgId, league) {
    if (!_ps.canCreateLeague(actor)) _deny('createLeague', actor);
    return _fs.createLeague(orgId, league);
  }

  Future<void> updateLeagueFields(
      AppUser actor, String orgId, String leagueId, Map<String, dynamic> data) {
    if (!_ps.canUpdateLeague(actor)) _deny('updateLeagueFields', actor);
    return _fs.updateLeagueFields(orgId, leagueId, data);
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

  Future<void> updateHubFields(AppUser actor, String orgId, String leagueId,
      String hubId, Map<String, dynamic> data) {
    if (!_ps.canUpdateHub(actor, hubId: hubId)) {
      _deny('updateHubFields', actor);
    }
    return _fs.updateHubFields(orgId, leagueId, hubId, data);
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
      AppUser actor, String orgId, String leagueId, String hubId, Team team) {
    if (!_ps.canCreateTeam(actor, hubId: hubId)) {
      _deny('createTeam', actor);
    }
    if (actor.role == UserRole.managerAdmin && team.memberIds.isNotEmpty) {
      _deny('createTeam roster', actor);
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
    _assertCanUpdateTeamFields(actor, hubId, teamId, data);
    return _fs.updateTeamFields(orgId, leagueId, hubId, teamId, data);
  }

  void _assertCanUpdateTeamFields(
      AppUser actor, String hubId, String teamId, Map<String, dynamic> data) {
    if (!_ps.canCreateTeam(actor, hubId: hubId)) {
      _deny('updateTeamFields', actor);
    }
    if (data.containsKey('memberIds') &&
        !_ps.canManageTeamRoster(actor, hubId: hubId, teamId: teamId)) {
      _deny('updateTeamFields roster', actor);
    }
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
      AppUser actor, AppUser target, Map<String, dynamic> data) async {
    await _assertCanUpdateUserFields(actor, target, data);
    return _fs.updateUserFields(target.id, data);
  }

  Future<void> updateOwnSafetySettings(
    AppUser actor,
    Map<String, dynamic> data,
  ) {
    const allowedFields = {
      'blockedUserIds',
      'hasAcceptedCommunityGuidelines',
    };
    if (!actor.isActive ||
        data.keys.any((key) => !allowedFields.contains(key))) {
      _deny('updateOwnSafetySettings', actor);
    }
    final blockedIds = data['blockedUserIds'];
    if (blockedIds != null &&
        (blockedIds is! List ||
            blockedIds.whereType<String>().length != blockedIds.length ||
            blockedIds.length > 1000 ||
            blockedIds.contains(actor.id))) {
      _deny('updateOwnSafetySettings invalid blocked users', actor);
    }
    final accepted = data['hasAcceptedCommunityGuidelines'];
    if (accepted != null && (accepted is! bool || accepted != true)) {
      _deny('updateOwnSafetySettings invalid guideline acceptance', actor);
    }
    return _fs.updateOwnSafetySettings(actor.id, data);
  }

  Future<void> _assertCanUpdateUserFields(
      AppUser actor, AppUser target, Map<String, dynamic> data) async {
    final canManageFully = _ps.canManageUser(actor, target);
    final canManageAssignments = _ps.canManageUserAssignments(actor, target);
    if (!canManageFully && !canManageAssignments) {
      _deny('updateUserFields', actor);
    }
    const allowedFields = {
      'role',
      'hubIds',
      'leagueIds',
      'teamIds',
      'title',
      'phone',
      'address',
      'isActive',
    };
    if (data.keys.any((key) => !allowedFields.contains(key))) {
      _deny('updateUserFields immutable fields', actor);
    }
    const assignmentFields = {'hubIds', 'leagueIds', 'teamIds'};
    if (!canManageFully &&
        data.keys.any((key) => !assignmentFields.contains(key))) {
      _deny('updateUserFields peer admin non-assignment fields', actor);
    }
    if (actor.role == UserRole.managerAdmin) {
      if (data.containsKey('role') && data['role'] != target.role.name) {
        _deny('updateUserFields outside manager scope', actor);
      }
      final hubIds = data['hubIds'];
      if (hubIds is! List ||
          hubIds.isEmpty ||
          hubIds.whereType<String>().length != hubIds.length ||
          hubIds.any((hubId) => !actor.hubIds.contains(hubId))) {
        _deny('updateUserFields outside assigned hubs', actor);
      }
      final leagueIds = data['leagueIds'];
      if (leagueIds is! List ||
          leagueIds.whereType<String>().length != leagueIds.length ||
          leagueIds.any((leagueId) => !actor.leagueIds.contains(leagueId))) {
        _deny('updateUserFields outside assigned leagues', actor);
      }
      final teamIds = data['teamIds'];
      if (teamIds is! List ||
          teamIds.whereType<String>().length != teamIds.length ||
          teamIds.any((teamId) => !actor.teamIds.contains(teamId))) {
        _deny('updateUserFields outside assigned teams', actor);
      }
      final selectedHubIds = hubIds.whereType<String>().toSet();
      final selectedTeamIds = teamIds.whereType<String>().toSet();
      if (selectedTeamIds.isNotEmpty) {
        final teams =
            await _fs.getAllTeamsFlat(target.orgId ?? actor.orgId ?? '');
        final validTeamIds = teams
            .where((team) => selectedHubIds.contains(team.hubId))
            .map((team) => team.id)
            .toSet();
        if (selectedTeamIds.difference(validTeamIds).isNotEmpty) {
          _deny('updateUserFields team outside selected hubs', actor);
        }
      }
    }
  }

  /// Atomically updates both sides of a roster assignment after applying the
  /// same role and nested-scope checks as the individual write methods.
  Future<void> updateTeamRosterAssignment(
    AppUser actor,
    AppUser target,
    String orgId,
    String leagueId,
    String hubId,
    String teamId,
    List<String> memberIds,
    Map<String, dynamic> userFields,
  ) async {
    if (target.orgId != orgId) {
      _deny('updateTeamRosterAssignment cross-organization target', actor);
    }
    final teamFields = <String, dynamic>{'memberIds': memberIds};
    _assertCanUpdateTeamFields(actor, hubId, teamId, teamFields);
    await _assertCanUpdateUserFields(actor, target, userFields);
    return _fs.updateTeamRosterAssignment(
      orgId,
      leagueId,
      hubId,
      teamId,
      memberIds,
      target.id,
      userFields,
    );
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
    String? hubId,
    String? teamId,
    List<String> participants = const [],
    ChatRoomPurpose? roomPurpose,
    String? roomIconName,
    String? roomImageUrl,
  }) {
    if (type == ChatRoomType.direct) {
      if (!_ps.canCreateDirectMessage(actor) ||
          participants.length != 2 ||
          !participants.contains(actor.id)) {
        _deny('createChatRoom', actor);
      }
    } else if ((type == ChatRoomType.league && hubId?.isNotEmpty == true) ||
        !_ps.canCreateChatRoomInScope(
          actor,
          leagueId: leagueId,
          hubId: hubId,
          teamId: teamId,
        )) {
      _deny('createChatRoom', actor);
    }
    return _fs.createChatRoom(orgId, name, type,
        leagueId: leagueId,
        hubId: hubId,
        teamId: teamId,
        participants: participants,
        roomPurpose: roomPurpose,
        roomIconName: roomIconName,
        roomImageUrl: roomImageUrl);
  }

  Future<ChatRoom> getOrCreateDirectMessage(
    AppUser actor,
    AppUser otherUser,
    String orgId,
  ) {
    if (!_ps.canCreateDirectMessage(actor) ||
        !otherUser.isActive ||
        actor.id == otherUser.id ||
        actor.orgId != otherUser.orgId ||
        actor.orgId != orgId) {
      _deny('createDirectMessage', actor);
    }
    return _fs.getOrCreateDMRoom(
      orgId,
      actor.id,
      otherUser.id,
      actor.displayName,
      otherUser.displayName,
    );
  }

  Future<void> archiveChatRoom(
      AppUser actor, String orgId, String roomId) async {
    if (!_ps.canArchiveChatRoom(actor)) _deny('archiveChatRoom', actor);
    final room = await _fs.getChatRoom(orgId, roomId).first;
    if (room == null || !_ps.canManageChatRoom(actor, room)) {
      _deny('archiveChatRoom scope', actor);
    }
    return _fs.archiveChatRoom(orgId, roomId);
  }

  Future<void> updateChatRoomFields(
    AppUser actor,
    String orgId,
    String roomId,
    Map<String, dynamic> data,
  ) async {
    if (!_ps.canUpdateChatRoom(actor)) _deny('updateChatRoomFields', actor);
    final room = await _fs.getChatRoom(orgId, roomId).first;
    if (room == null || !_ps.canEditChatRoomDetails(actor, room)) {
      _deny('updateChatRoomFields scope', actor);
    }
    return _fs.updateChatRoomFields(orgId, roomId, data);
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
  Future<void> markMessagesAsRead(AppUser actor, String orgId, String roomId) {
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

  Future<void> reportMessage(
    AppUser actor,
    String orgId,
    String roomId,
    Message message, {
    required String reason,
    String? details,
  }) {
    const allowedReasons = {
      'Harassment or bullying',
      'Hateful or abusive content',
      'Sexual or inappropriate content',
      'Spam or misleading content',
      'Safety concern',
      'Other',
    };
    if (!actor.isActive ||
        actor.orgId != orgId ||
        actor.id == message.senderId ||
        !allowedReasons.contains(reason) ||
        (details?.length ?? 0) > 500) {
      _deny('reportMessage', actor);
    }
    return _fs.reportMessage(
      orgId,
      roomId,
      message,
      actor,
      reason: reason,
      details: details,
    );
  }

  // -------------------------------------------------------------------------
  // Policy
  // -------------------------------------------------------------------------

  Future<String> createPolicy(
      AppUser actor, String orgId, Map<String, dynamic> policyData,
      {String? policyId}) {
    if (!_ps.canUploadPolicyToScope(
      actor,
      leagueId: policyData['leagueId'] as String?,
      hubId: policyData['hubId'] as String?,
      teamId: policyData['teamId'] as String?,
    )) {
      _deny('createPolicy', actor);
    }
    return _fs.createPolicy(orgId, policyData, policyId: policyId);
  }

  Future<void> updatePolicy(
      AppUser actor, String orgId, String policyId, Map<String, dynamic> data,
      {required String uploadedBy}) {
    if (!_ps.canEditPolicy(actor, uploadedBy: uploadedBy)) {
      _deny('updatePolicy', actor);
    }
    return _fs.updatePolicy(orgId, policyId, data);
  }

  Future<void> deletePolicy(AppUser actor, String orgId, String policyId) {
    if (!_ps.canDeletePolicy(actor)) _deny('deletePolicy', actor);
    return _fs.deletePolicy(orgId, policyId);
  }

  Future<void> addPolicyVersion(
    AppUser actor,
    String orgId,
    String policyId,
    Map<String, dynamic> data, {
    required String uploadedBy,
    required String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!_ps.canEditPolicy(actor, uploadedBy: uploadedBy) ||
        !_ps.canUploadPolicyToScope(
          actor,
          leagueId: leagueId,
          hubId: hubId,
          teamId: teamId,
        )) {
      _deny('addPolicyVersion', actor);
    }
    return _fs.addPolicyVersion(orgId, policyId, data);
  }

  // -------------------------------------------------------------------------
  // Announcements
  // -------------------------------------------------------------------------

  Future<String> createAnnouncement(
    AppUser actor,
    String orgId,
    Map<String, dynamic> data, {
    required AnnouncementScope scope,
    String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!_ps.canCreateAnnouncementWithScope(
      actor,
      scope,
      leagueId: leagueId,
      hubId: hubId,
      teamId: teamId,
    )) {
      _deny('createAnnouncement', actor);
    }
    if (data['isPinned'] == true && !_ps.canTogglePin(actor)) {
      _deny('createAnnouncement pin', actor);
    }
    return _fs.createAnnouncement(orgId, data);
  }

  Future<void> updateAnnouncement(AppUser actor, String orgId,
      String announcementId, Map<String, dynamic> data,
      {required String authorId,
      required AnnouncementScope scope,
      String? leagueId,
      String? hubId,
      String? teamId}) {
    if (!_ps.canEditAnnouncement(actor, authorId: authorId) ||
        !_ps.canCreateAnnouncementWithScope(
          actor,
          scope,
          leagueId: leagueId,
          hubId: hubId,
          teamId: teamId,
        )) {
      _deny('updateAnnouncement', actor);
    }
    final safeData = Map<String, dynamic>.from(data);
    if (safeData.containsKey('isPinned') && !_ps.canTogglePin(actor)) {
      safeData.remove('isPinned');
    }
    return _fs.updateAnnouncement(orgId, announcementId, safeData);
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
      AppUser actor, String orgId, Invitation invitation) async {
    if (!_ps.canCreateInvitation(actor)) {
      _deny('createInvitation', actor);
    }
    UserRole? invitedRole;
    for (final role in UserRole.values) {
      if (role.name == invitation.role) {
        invitedRole = role;
        break;
      }
    }
    if (invitedRole == null ||
        !_ps.invitableRoles(actor).contains(invitedRole)) {
      _deny('createInvitation (${invitation.role})', actor);
    }
    if (actor.role == UserRole.managerAdmin && invitation.hubIds.isEmpty) {
      _deny('createInvitation (assigned hub required)', actor);
    }
    // Verify hub-level scope for managerAdmin.
    for (final hubId in invitation.hubIds) {
      if (!_ps.canInviteToHub(actor, hubId)) {
        _deny('createInvitation (hub $hubId)', actor);
      }
    }
    for (final leagueId in invitation.leagueIds) {
      if (!_ps.canInviteToLeague(actor, leagueId)) {
        _deny('createInvitation (league $leagueId)', actor);
      }
    }
    for (final teamId in invitation.teamIds) {
      if (!_ps.canInviteToTeam(actor, teamId)) {
        _deny('createInvitation (team $teamId)', actor);
      }
    }
    if (actor.role == UserRole.managerAdmin && invitation.teamIds.isNotEmpty) {
      final selectedHubIds = invitation.hubIds.toSet();
      final teams = await _fs.getAllTeamsFlat(orgId);
      final validTeamIds = teams
          .where((team) => selectedHubIds.contains(team.hubId))
          .map((team) => team.id)
          .toSet();
      if (invitation.teamIds.any((teamId) => !validTeamIds.contains(teamId))) {
        _deny('createInvitation team outside selected hubs', actor);
      }
    }
    return _fs.createInvitation(orgId, invitation);
  }

  /// Validates and accepts an invitation, checking expiry.
  Future<void> acceptInvitation(String orgId, String inviteId,
      {required DateTime invitedAt, DateTime? expiresAt, int expiryDays = 7}) {
    final expiry = expiresAt ?? invitedAt.add(Duration(days: expiryDays));
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
