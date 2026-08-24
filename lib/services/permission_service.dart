import '../models/app_user.dart';
import '../models/announcement.dart';
import '../models/chat_room.dart';

/// Centralised permission logic for all role × action × scope checks.
///
/// Every method is a pure function — no Firebase dependency — so it's
/// trivially testable. Screens, providers, and route guards should all
/// delegate to this service instead of scattering role checks inline.
class PermissionService {
  const PermissionService();

  // ---------------------------------------------------------------------------
  // Role hierarchy helpers
  // ---------------------------------------------------------------------------

  /// Ordered list from most to least privileged.
  static const _hierarchy = [
    UserRole.platformOwner,
    UserRole.superAdmin,
    UserRole.managerAdmin,
    UserRole.staff,
  ];

  /// Returns true if [role] is at least as privileged as [minimum].
  static bool isAtLeast(UserRole role, UserRole minimum) {
    return _hierarchy.indexOf(role) <= _hierarchy.indexOf(minimum);
  }

  /// Returns true if [actor] outranks [target] in the hierarchy.
  static bool outranks(UserRole actor, UserRole target) {
    return _hierarchy.indexOf(actor) < _hierarchy.indexOf(target);
  }

  // ---------------------------------------------------------------------------
  // Gate: is the user active?
  // ---------------------------------------------------------------------------

  /// An inactive user can do nothing.
  bool isActiveUser(AppUser user) => user.isActive;

  // ---------------------------------------------------------------------------
  // Navigation / Route access
  // ---------------------------------------------------------------------------

  /// Routes that any authenticated + active user can access.
  static const _publicRoutes = {
    '/',
    '/contacts',
    '/chat',
    '/policy',
    '/announcements',
    '/schedule',
    '/profile',
    '/profile/edit',
    '/settings',
    '/settings/profile',
    '/settings/notifications',
    '/settings/privacy',
    '/settings/app-icon',
  };

  /// Routes that require at least managerAdmin.
  static const _managerRoutes = {
    '/settings/users',
    '/settings/leagues',
  };

  /// Routes that require at least superAdmin.
  static const _adminRoutes = {
    '/settings/roles',
  };

  /// Routes that require at least managerAdmin to create/edit content.
  static const _contentCreationRoutes = {
    '/policy/upload',
    '/announcements/create',
  };

  /// Returns true if [user] may navigate to [path].
  ///
  /// Dynamic segments (e.g. `/chat/:roomId`) should be passed as their
  /// matched pattern (e.g. `/chat/abc123`). This method normalises common
  /// patterns for you.
  bool canAccessRoute(AppUser user, String path) {
    if (!isActiveUser(user)) return false;

    // Normalise: strip trailing slash, handle dynamic segments.
    final normalised = _normaliseRoute(path);

    if (_publicRoutes.contains(normalised)) return true;
    if (_managerRoutes.contains(normalised)) {
      return isAtLeast(user.role, UserRole.managerAdmin);
    }
    if (_adminRoutes.contains(normalised)) {
      return isAtLeast(user.role, UserRole.superAdmin);
    }
    if (_contentCreationRoutes.contains(normalised)) {
      return isAtLeast(user.role, UserRole.managerAdmin);
    }

    // Dynamic routes — chat conversations, policy detail, announcement
    // detail, user detail, and announcement edit are accessible to all active
    // users (the data-layer scope filters handle visibility).
    if (normalised.startsWith('/contacts/')) return true;
    if (normalised.startsWith('/chat/')) return true;
    if (normalised.startsWith('/policy/') && normalised != '/policy/upload') {
      return true;
    }
    if (normalised.startsWith('/announcements/') &&
        normalised != '/announcements/create') {
      // Edit route requires managerAdmin+
      if (normalised.endsWith('/edit')) {
        return isAtLeast(user.role, UserRole.managerAdmin);
      }
      return true; // detail view
    }
    if (normalised.startsWith('/settings/users/')) {
      return isAtLeast(user.role, UserRole.managerAdmin);
    }
    if (normalised.startsWith('/settings/leagues/')) {
      if (normalised == '/settings/leagues/new') {
        return canCreateLeague(user);
      }
      if (normalised.endsWith('/hubs/new')) {
        return isAtLeast(user.role, UserRole.superAdmin);
      }
      final segments = normalised
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      if (normalised.endsWith('/edit') && segments.length == 4) {
        return canUpdateLeague(user);
      }
      return isAtLeast(user.role, UserRole.managerAdmin);
    }
    // Team detail — accessible to all active users.
    if (normalised.startsWith('/teams/')) return true;

    return false;
  }

  String _normaliseRoute(String path) {
    if (path.endsWith('/') && path.length > 1) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  // ---------------------------------------------------------------------------
  // Organization management
  // ---------------------------------------------------------------------------

  bool canManageOrganizations(AppUser user) =>
      isActiveUser(user) && user.role == UserRole.platformOwner;

  bool canUpdateOrganization(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  bool canDeleteOrganization(AppUser user) =>
      isActiveUser(user) && user.role == UserRole.platformOwner;

  // ---------------------------------------------------------------------------
  // League management
  // ---------------------------------------------------------------------------

  bool canCreateLeague(AppUser user) =>
      isActiveUser(user) && user.role == UserRole.platformOwner;

  bool canUpdateLeague(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  bool canDeleteLeague(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  // ---------------------------------------------------------------------------
  // Hub management
  // ---------------------------------------------------------------------------

  bool canCreateHub(AppUser user, {String? leagueId}) {
    return isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);
  }

  bool canUpdateHub(AppUser user, {required String hubId}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.role == UserRole.managerAdmin && user.hubIds.contains(hubId);
  }

  bool canDeleteHub(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  // ---------------------------------------------------------------------------
  // Team management
  // ---------------------------------------------------------------------------

  bool canCreateTeam(AppUser user, {String? hubId}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    if (user.role == UserRole.managerAdmin) {
      // Must own the hub to add teams to it.
      return hubId != null && user.hubIds.contains(hubId);
    }
    return false;
  }

  bool canDeleteTeam(AppUser user, {String? hubId}) =>
      canCreateTeam(user, hubId: hubId);

  bool canManageTeamRoster(
    AppUser user, {
    required String hubId,
    required String teamId,
  }) {
    if (!canCreateTeam(user, hubId: hubId)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.teamIds.contains(teamId);
  }

  // ---------------------------------------------------------------------------
  // User management
  // ---------------------------------------------------------------------------

  bool canViewUserManagement(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canManageUser(AppUser actor, AppUser target) {
    if (!isActiveUser(actor)) return false;
    // Nobody edits themselves through user management (use profile screen).
    if (actor.id == target.id) return false;
    if (actor.role != UserRole.platformOwner && actor.orgId != target.orgId) {
      return false;
    }
    // Must outrank the target.
    if (!outranks(actor.role, target.role)) return false;
    // managerAdmin can only manage users in their hubs.
    if (actor.role == UserRole.managerAdmin) {
      return target.role == UserRole.staff &&
          target.hubIds.isNotEmpty &&
          target.hubIds.every(actor.hubIds.contains) &&
          target.teamIds.every(actor.teamIds.contains);
    }
    return true;
  }

  bool canManageUserAssignments(AppUser actor, AppUser target) {
    if (!isActiveUser(actor)) return false;
    if (actor.id == target.id || target.role == UserRole.platformOwner) {
      return false;
    }
    if (actor.role == UserRole.platformOwner) return true;
    if (actor.role == UserRole.superAdmin) {
      return actor.orgId != null && actor.orgId == target.orgId;
    }
    return canManageUser(actor, target);
  }

  bool canDeactivateUser(AppUser actor, AppUser target) =>
      canManageUser(actor, target);

  bool canReactivateUser(AppUser actor, AppUser target) =>
      canManageUser(actor, target);

  bool canChangeUserRole(AppUser actor, AppUser target) {
    if (!canManageUser(actor, target)) return false;
    // Only platformOwner+ can promote to/from superAdmin.
    return isAtLeast(actor.role, UserRole.superAdmin);
  }

  /// Returns the set of roles that [actor] is allowed to assign.
  List<UserRole> assignableRoles(AppUser actor) {
    if (actor.role == UserRole.platformOwner) {
      return [UserRole.superAdmin, UserRole.managerAdmin, UserRole.staff];
    }
    if (actor.role == UserRole.superAdmin) {
      return [UserRole.managerAdmin, UserRole.staff];
    }
    return [];
  }

  // ---------------------------------------------------------------------------
  // Invitations
  // ---------------------------------------------------------------------------

  bool canCreateInvitation(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  List<UserRole> invitableRoles(AppUser actor) {
    if (!isActiveUser(actor)) return const [];
    if (actor.role == UserRole.platformOwner) {
      return const [
        UserRole.superAdmin,
        UserRole.managerAdmin,
        UserRole.staff,
      ];
    }
    if (actor.role == UserRole.superAdmin) {
      return const [UserRole.managerAdmin, UserRole.staff];
    }
    if (actor.role == UserRole.managerAdmin) {
      return const [UserRole.staff];
    }
    return const [];
  }

  /// managerAdmin can only invite into their own hubs.
  bool canInviteToHub(AppUser user, String hubId) {
    if (!canCreateInvitation(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.hubIds.contains(hubId);
  }

  bool canInviteToLeague(AppUser user, String leagueId) {
    if (!canCreateInvitation(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.leagueIds.contains(leagueId);
  }

  bool canInviteToTeam(AppUser user, String teamId) {
    if (!canCreateInvitation(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.teamIds.contains(teamId);
  }

  // ---------------------------------------------------------------------------
  // Announcements
  // ---------------------------------------------------------------------------

  bool canCreateAnnouncement(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canCreateAnnouncementWithScope(
    AppUser user,
    AnnouncementScope scope, {
    String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!canCreateAnnouncement(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    if (scope == AnnouncementScope.league) {
      return leagueId != null && user.leagueIds.contains(leagueId);
    }
    return canManageContentScope(
      user,
      leagueId: leagueId,
      hubId: scope == AnnouncementScope.hub || scope == AnnouncementScope.team
          ? hubId
          : null,
      teamId: scope == AnnouncementScope.team ? teamId : null,
    );
  }

  bool canEditAnnouncement(AppUser user, {required String authorId}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // Only managerAdmin can edit their own announcement.
    return isAtLeast(user.role, UserRole.managerAdmin) && user.id == authorId;
  }

  bool canDeleteAnnouncement(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  bool canTogglePin(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  /// Returns true if [user] should see [announcement] based on scope + assignments.
  bool canViewAnnouncement(
    AppUser user, {
    required AnnouncementScope scope,
    String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!isActiveUser(user)) return false;
    // platformOwner and superAdmin see everything.
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // Team-scoped: team members and managers of that hub can see it.
    if (scope == AnnouncementScope.team && teamId != null) {
      return user.teamIds.contains(teamId) ||
          (hubId != null && user.hubIds.contains(hubId));
    }
    // Hub-scoped: user must be in that hub.
    if (scope == AnnouncementScope.hub && hubId != null) {
      return user.hubIds.contains(hubId);
    }
    // League-scoped: user must belong to a hub within that league.
    if (scope == AnnouncementScope.league && leagueId != null) {
      return user.leagueIds.contains(leagueId);
    }
    // Invalid or incomplete scoped records are not broadly visible.
    return false;
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  bool canViewScheduleEvent(
    AppUser user, {
    required List<String> teamIds,
    required List<String> hubIds,
    required List<String> leagueIds,
  }) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    if (teamIds.any(user.teamIds.contains)) return true;
    if (hubIds.any(user.hubIds.contains)) return true;
    // Some older user records have league assignments without team/hub IDs.
    if (user.teamIds.isEmpty && user.hubIds.isEmpty) {
      return leagueIds.any(user.leagueIds.contains);
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Policy
  // ---------------------------------------------------------------------------

  bool canUploadPolicy(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canUploadPolicyToHub(AppUser user, String hubId) {
    if (!canUploadPolicy(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.hubIds.contains(hubId);
  }

  bool canUploadPolicyToScope(
    AppUser user, {
    required String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!canUploadPolicy(user)) return false;
    final isOrganizationWide =
        leagueId == null && hubId == null && teamId == null;
    if (isOrganizationWide) {
      return isAtLeast(user.role, UserRole.superAdmin);
    }
    if (leagueId == null || hubId == null) return false;
    if (teamId != null && hubId.isEmpty) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return canManageContentScope(
      user,
      leagueId: leagueId,
      hubId: hubId,
      teamId: teamId,
    );
  }

  bool canEditPolicy(AppUser user, {required String uploadedBy}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.role == UserRole.managerAdmin && user.id == uploadedBy;
  }

  bool canDeletePolicy(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  /// Returns true if [user] should see an organization, hub, or team policy.
  bool canViewPolicy(
    AppUser user, {
    String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // If team-scoped, the user must be on that team or manage that hub.
    if (teamId != null) {
      return user.teamIds.contains(teamId) ||
          (hubId != null && user.hubIds.contains(hubId));
    }
    // If hub-scoped, user must be in that hub.
    if (hubId != null) return user.hubIds.contains(hubId);
    // Organization-wide policies are visible to everyone in the org. During
    // the migration, legacy league-only records are treated the same way.
    return true;
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  bool canCreateChatRoom(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canCreateDirectMessage(AppUser user) => isActiveUser(user);

  bool canCreateChatRoomInScope(
    AppUser user, {
    required String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!canCreateChatRoom(user)) return false;
    if (leagueId == null) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return canManageContentScope(
      user,
      leagueId: leagueId,
      hubId: hubId,
      teamId: teamId,
    );
  }

  bool canArchiveChatRoom(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canUpdateChatRoom(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canManageChatRoom(AppUser user, ChatRoom room) {
    if (!canUpdateChatRoom(user) || room.type == ChatRoomType.direct) {
      return false;
    }
    return canManageContentScope(
      user,
      leagueId: room.leagueId,
      hubId: room.hubId,
      teamId: room.teamId,
    );
  }

  bool canEditChatRoomDetails(AppUser user, ChatRoom room) =>
      canManageChatRoom(user, room) && !room.isStructureManagedGeneral;

  /// All active users can send messages.
  bool canSendMessage(AppUser user) => isActiveUser(user);

  /// A user can edit their own messages.
  bool canUpdateMessage(AppUser user, {required String senderId}) =>
      isActiveUser(user) && user.id == senderId;

  /// A user can delete their own messages, or superAdmin+ can delete any.
  bool canDeleteMessage(AppUser user, {required String senderId}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.id == senderId;
  }

  /// Returns true if [user] should see [room] based on type and assignments.
  bool canViewChatRoom(AppUser user, ChatRoom room) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // DMs: only participants.
    if (room.type == ChatRoomType.direct) {
      return room.participants.contains(user.id);
    }
    // League rooms: visible to users in hubs belonging to that league.
    if (room.type == ChatRoomType.league && room.leagueId != null) {
      if (room.teamId != null) {
        return user.teamIds.contains(room.teamId) ||
            (room.hubId != null && user.hubIds.contains(room.hubId));
      }
      if (room.hubId != null) return user.hubIds.contains(room.hubId);
      return user.leagueIds.contains(room.leagueId);
    }
    // League-attached event rooms are scoped to that league.
    if (room.type == ChatRoomType.event && room.leagueId != null) {
      if (room.teamId != null) {
        return user.teamIds.contains(room.teamId) ||
            (room.hubId != null && user.hubIds.contains(room.hubId));
      }
      if (room.hubId != null) return user.hubIds.contains(room.hubId);
      return user.leagueIds.contains(room.leagueId);
    }
    // Unscoped event rooms: visible to anyone in the org.
    return true;
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  bool canEditAppIcon(AppUser user) => isActiveUser(user);

  bool canManageContentScope(
    AppUser user, {
    required String? leagueId,
    String? hubId,
    String? teamId,
  }) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    if (user.role != UserRole.managerAdmin) return false;
    if (teamId != null) {
      return user.teamIds.contains(teamId) ||
          (hubId != null && user.hubIds.contains(hubId));
    }
    if (hubId != null) return user.hubIds.contains(hubId);
    if (leagueId == null) return false;
    return user.leagueIds.contains(leagueId);
  }

  bool canViewRolesPermissions(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// Users can edit their own profile.
  bool canEditProfile(AppUser user, String targetUserId) =>
      isActiveUser(user) && user.id == targetUserId;

  // ---------------------------------------------------------------------------
  // Settings tile visibility
  // ---------------------------------------------------------------------------

  /// Returns a list of settings tile keys visible to [user].
  List<String> visibleSettingsTiles(AppUser user) {
    final tiles = <String>[
      'profile',
      'app-icon',
      'notifications',
      'privacy',
    ];
    if (isAtLeast(user.role, UserRole.managerAdmin)) {
      tiles.addAll(['users', 'leagues']);
    }
    if (isAtLeast(user.role, UserRole.superAdmin)) {
      tiles.addAll(['roles']);
    }
    return tiles;
  }
}
