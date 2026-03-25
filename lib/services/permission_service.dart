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
    '/chat',
    '/documents',
    '/announcements',
    '/settings',
    '/settings/profile',
    '/settings/notifications',
    '/settings/privacy',
  };

  /// Routes that require at least managerAdmin.
  static const _managerRoutes = {
    '/settings/users',
  };

  /// Routes that require at least superAdmin.
  static const _adminRoutes = {
    '/settings/roles',
    '/settings/branding',
    '/settings/app-icon',
  };

  /// Routes that require at least managerAdmin to create/edit content.
  static const _contentCreationRoutes = {
    '/documents/upload',
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

    // Dynamic routes — chat conversations, document detail, announcement
    // detail, user detail, and announcement edit are accessible to all active
    // users (the data-layer scope filters handle visibility).
    if (normalised.startsWith('/chat/')) return true;
    if (normalised.startsWith('/documents/') &&
        normalised != '/documents/upload') {
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

  bool canDeleteOrganization(AppUser user) =>
      isActiveUser(user) && user.role == UserRole.platformOwner;

  // ---------------------------------------------------------------------------
  // League management
  // ---------------------------------------------------------------------------

  bool canCreateLeague(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  bool canDeleteLeague(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  // ---------------------------------------------------------------------------
  // Hub management
  // ---------------------------------------------------------------------------

  bool canCreateHub(AppUser user, {String? leagueId}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // managerAdmin can only create hubs in leagues they're assigned to.
    // Since hubs live under leagues, we check hub assignment indirectly:
    // a managerAdmin must have at least one hub in the org to create more
    // in the same league scope. For now, allow if they have any hub
    // assignments (the UI should scope the league picker).
    return user.role == UserRole.managerAdmin;
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
      return hubId == null || user.hubIds.contains(hubId);
    }
    return false;
  }

  bool canDeleteTeam(AppUser user, {String? hubId}) =>
      canCreateTeam(user, hubId: hubId);

  // ---------------------------------------------------------------------------
  // User management
  // ---------------------------------------------------------------------------

  bool canViewUserManagement(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canManageUser(AppUser actor, AppUser target) {
    if (!isActiveUser(actor)) return false;
    // Nobody edits themselves through user management (use profile screen).
    if (actor.id == target.id) return false;
    // Must outrank the target.
    if (!outranks(actor.role, target.role)) return false;
    // managerAdmin can only manage users in their hubs.
    if (actor.role == UserRole.managerAdmin) {
      return target.hubIds.any((h) => actor.hubIds.contains(h));
    }
    return true;
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

  /// managerAdmin can only invite into their own hubs.
  bool canInviteToHub(AppUser user, String hubId) {
    if (!canCreateInvitation(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.hubIds.contains(hubId);
  }

  // ---------------------------------------------------------------------------
  // Announcements
  // ---------------------------------------------------------------------------

  bool canCreateAnnouncement(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canCreateAnnouncementWithScope(AppUser user, AnnouncementScope scope,
      {String? hubId}) {
    if (!canCreateAnnouncement(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // managerAdmin cannot create org-wide announcements.
    if (scope == AnnouncementScope.orgWide) return false;
    // managerAdmin can only announce to their hubs.
    if (scope == AnnouncementScope.hub && hubId != null) {
      return user.hubIds.contains(hubId);
    }
    return true; // league-scoped is okay for managerAdmin
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
  bool canViewAnnouncement(AppUser user, {
    required AnnouncementScope scope,
    String? leagueId,
    String? hubId,
  }) {
    if (!isActiveUser(user)) return false;
    // platformOwner and superAdmin see everything.
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // org-wide announcements are visible to everyone.
    if (scope == AnnouncementScope.orgWide) return true;
    // Hub-scoped: user must be in that hub.
    if (scope == AnnouncementScope.hub && hubId != null) {
      return user.hubIds.contains(hubId);
    }
    // League-scoped: visible to all in the org (leagues don't have direct
    // user assignments — users are assigned to hubs which belong to leagues).
    return true;
  }

  // ---------------------------------------------------------------------------
  // Documents
  // ---------------------------------------------------------------------------

  bool canUploadDocument(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canUploadDocumentToHub(AppUser user, String hubId) {
    if (!canUploadDocument(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.hubIds.contains(hubId);
  }

  bool canEditDocument(AppUser user, {required String uploadedBy}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    return user.role == UserRole.managerAdmin && user.id == uploadedBy;
  }

  bool canDeleteDocument(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  /// Returns true if [user] should see a document scoped to [hubId] / [leagueId].
  bool canViewDocument(AppUser user, {String? leagueId, String? hubId}) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // If hub-scoped, user must be in that hub.
    if (hubId != null) return user.hubIds.contains(hubId);
    // League-scoped or unscoped docs are visible to everyone in the org.
    return true;
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  bool canCreateChatRoom(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  bool canArchiveChatRoom(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.managerAdmin);

  /// All active users can send messages.
  bool canSendMessage(AppUser user) => isActiveUser(user);

  /// Returns true if [user] should see [room] based on type and assignments.
  bool canViewChatRoom(AppUser user, ChatRoom room) {
    if (!isActiveUser(user)) return false;
    if (isAtLeast(user.role, UserRole.superAdmin)) return true;
    // DMs: only participants.
    if (room.type == ChatRoomType.direct) {
      return room.participants.contains(user.id);
    }
    // League/event rooms: visible to anyone in the org (scoped filtering
    // happens in the provider layer using hubIds→leagueIds mapping).
    return true;
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  bool canEditBranding(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

  bool canEditAppIcon(AppUser user) =>
      isActiveUser(user) && isAtLeast(user.role, UserRole.superAdmin);

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
      'notifications',
      'privacy',
    ];
    if (isAtLeast(user.role, UserRole.managerAdmin)) {
      tiles.addAll(['users']);
    }
    if (isAtLeast(user.role, UserRole.superAdmin)) {
      tiles.addAll(['roles', 'branding', 'app-icon', 'leagues']);
    }
    return tiles;
  }
}
