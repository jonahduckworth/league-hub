import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/services/permission_service.dart';

void main() {
  const service = PermissionService();

  // -------------------------------------------------------------------------
  // Helper factories
  // -------------------------------------------------------------------------

  AppUser makeUser({
    String id = 'u1',
    UserRole role = UserRole.staff,
    String? orgId = 'org1',
    List<String> hubIds = const [],
    List<String> leagueIds = const [],
    List<String> teamIds = const [],
    bool isActive = true,
  }) =>
      AppUser(
        id: id,
        email: '$id@test.com',
        displayName: 'User $id',
        role: role,
        orgId: orgId,
        hubIds: hubIds,
        leagueIds: leagueIds,
        teamIds: teamIds,
        createdAt: DateTime(2024),
        isActive: isActive,
      );

  ChatRoom makeRoom({
    String id = 'room1',
    ChatRoomType type = ChatRoomType.league,
    List<String> participants = const [],
    String? leagueId,
  }) =>
      ChatRoom(
        id: id,
        orgId: 'org1',
        name: 'Room',
        type: type,
        leagueId: leagueId,
        participants: participants,
        createdAt: DateTime(2024),
        isArchived: false,
      );

  // Shorthand
  AppUser owner({bool isActive = true, List<String> hubIds = const [], List<String> leagueIds = const []}) =>
      makeUser(id: 'owner', role: UserRole.platformOwner, isActive: isActive, hubIds: hubIds, leagueIds: leagueIds);
  AppUser superAdmin({bool isActive = true, List<String> hubIds = const [], List<String> leagueIds = const []}) =>
      makeUser(id: 'sa', role: UserRole.superAdmin, isActive: isActive, hubIds: hubIds, leagueIds: leagueIds);
  AppUser manager({bool isActive = true, List<String> hubIds = const [], List<String> leagueIds = const []}) =>
      makeUser(id: 'ma', role: UserRole.managerAdmin, isActive: isActive, hubIds: hubIds, leagueIds: leagueIds);
  AppUser staff({bool isActive = true, List<String> hubIds = const [], List<String> leagueIds = const []}) =>
      makeUser(id: 'staff', role: UserRole.staff, isActive: isActive, hubIds: hubIds, leagueIds: leagueIds);

  // -------------------------------------------------------------------------
  // Hierarchy helpers
  // -------------------------------------------------------------------------

  group('isAtLeast', () {
    test('platformOwner is at least every role', () {
      expect(PermissionService.isAtLeast(UserRole.platformOwner, UserRole.platformOwner), isTrue);
      expect(PermissionService.isAtLeast(UserRole.platformOwner, UserRole.superAdmin), isTrue);
      expect(PermissionService.isAtLeast(UserRole.platformOwner, UserRole.managerAdmin), isTrue);
      expect(PermissionService.isAtLeast(UserRole.platformOwner, UserRole.staff), isTrue);
    });

    test('superAdmin is at least superAdmin, managerAdmin, staff', () {
      expect(PermissionService.isAtLeast(UserRole.superAdmin, UserRole.platformOwner), isFalse);
      expect(PermissionService.isAtLeast(UserRole.superAdmin, UserRole.superAdmin), isTrue);
      expect(PermissionService.isAtLeast(UserRole.superAdmin, UserRole.managerAdmin), isTrue);
      expect(PermissionService.isAtLeast(UserRole.superAdmin, UserRole.staff), isTrue);
    });

    test('managerAdmin is at least managerAdmin and staff', () {
      expect(PermissionService.isAtLeast(UserRole.managerAdmin, UserRole.platformOwner), isFalse);
      expect(PermissionService.isAtLeast(UserRole.managerAdmin, UserRole.superAdmin), isFalse);
      expect(PermissionService.isAtLeast(UserRole.managerAdmin, UserRole.managerAdmin), isTrue);
      expect(PermissionService.isAtLeast(UserRole.managerAdmin, UserRole.staff), isTrue);
    });

    test('staff is only at least staff', () {
      expect(PermissionService.isAtLeast(UserRole.staff, UserRole.platformOwner), isFalse);
      expect(PermissionService.isAtLeast(UserRole.staff, UserRole.superAdmin), isFalse);
      expect(PermissionService.isAtLeast(UserRole.staff, UserRole.managerAdmin), isFalse);
      expect(PermissionService.isAtLeast(UserRole.staff, UserRole.staff), isTrue);
    });
  });

  group('outranks', () {
    test('platformOwner outranks everyone except itself', () {
      expect(PermissionService.outranks(UserRole.platformOwner, UserRole.platformOwner), isFalse);
      expect(PermissionService.outranks(UserRole.platformOwner, UserRole.superAdmin), isTrue);
      expect(PermissionService.outranks(UserRole.platformOwner, UserRole.managerAdmin), isTrue);
      expect(PermissionService.outranks(UserRole.platformOwner, UserRole.staff), isTrue);
    });

    test('staff outranks nobody', () {
      expect(PermissionService.outranks(UserRole.staff, UserRole.platformOwner), isFalse);
      expect(PermissionService.outranks(UserRole.staff, UserRole.superAdmin), isFalse);
      expect(PermissionService.outranks(UserRole.staff, UserRole.managerAdmin), isFalse);
      expect(PermissionService.outranks(UserRole.staff, UserRole.staff), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Inactive user gate
  // -------------------------------------------------------------------------

  group('inactive user', () {
    test('inactive user is blocked from all actions', () {
      final inactive = owner(isActive: false);

      expect(service.canCreateLeague(inactive), isFalse);
      expect(service.canDeleteLeague(inactive), isFalse);
      expect(service.canCreateHub(inactive), isFalse);
      expect(service.canDeleteHub(inactive), isFalse);
      expect(service.canCreateTeam(inactive), isFalse);
      expect(service.canDeleteTeam(inactive), isFalse);
      expect(service.canCreateAnnouncement(inactive), isFalse);
      expect(service.canDeleteAnnouncement(inactive), isFalse);
      expect(service.canUploadDocument(inactive), isFalse);
      expect(service.canDeleteDocument(inactive), isFalse);
      expect(service.canCreateChatRoom(inactive), isFalse);
      expect(service.canArchiveChatRoom(inactive), isFalse);
      expect(service.canSendMessage(inactive), isFalse);
      expect(service.canCreateInvitation(inactive), isFalse);
      expect(service.canEditBranding(inactive), isFalse);
      expect(service.canEditAppIcon(inactive), isFalse);
      expect(service.canViewRolesPermissions(inactive), isFalse);
      expect(service.canManageOrganizations(inactive), isFalse);
      expect(service.canViewUserManagement(inactive), isFalse);
    });

    test('inactive user cannot access any route', () {
      final inactive = owner(isActive: false);
      expect(service.canAccessRoute(inactive, '/'), isFalse);
      expect(service.canAccessRoute(inactive, '/settings/users'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Route access
  // -------------------------------------------------------------------------

  group('canAccessRoute', () {
    group('public routes', () {
      for (final route in ['/', '/chat', '/documents', '/announcements',
          '/settings', '/settings/profile', '/settings/notifications',
          '/settings/privacy']) {
        test('$route accessible to staff', () {
          expect(service.canAccessRoute(staff(), route), isTrue);
        });
      }
    });

    group('manager routes', () {
      test('/settings/users accessible to managerAdmin', () {
        expect(service.canAccessRoute(manager(), '/settings/users'), isTrue);
      });

      test('/settings/users blocked for staff', () {
        expect(service.canAccessRoute(staff(), '/settings/users'), isFalse);
      });

      test('/settings/users/:userId accessible to managerAdmin', () {
        expect(service.canAccessRoute(manager(), '/settings/users/abc123'), isTrue);
      });

      test('/settings/users/:userId blocked for staff', () {
        expect(service.canAccessRoute(staff(), '/settings/users/abc123'), isFalse);
      });
    });

    group('admin routes', () {
      for (final route in ['/settings/roles', '/settings/branding', '/settings/app-icon']) {
        test('$route accessible to superAdmin', () {
          expect(service.canAccessRoute(superAdmin(), route), isTrue);
        });

        test('$route accessible to platformOwner', () {
          expect(service.canAccessRoute(owner(), route), isTrue);
        });

        test('$route blocked for managerAdmin', () {
          expect(service.canAccessRoute(manager(), route), isFalse);
        });

        test('$route blocked for staff', () {
          expect(service.canAccessRoute(staff(), route), isFalse);
        });
      }
    });

    group('content creation routes', () {
      for (final route in ['/documents/upload', '/announcements/create']) {
        test('$route accessible to managerAdmin', () {
          expect(service.canAccessRoute(manager(), route), isTrue);
        });

        test('$route blocked for staff', () {
          expect(service.canAccessRoute(staff(), route), isFalse);
        });
      }
    });

    group('dynamic routes', () {
      test('chat conversation accessible to all active users', () {
        expect(service.canAccessRoute(staff(), '/chat/room123'), isTrue);
      });

      test('document detail accessible to all active users', () {
        expect(service.canAccessRoute(staff(), '/documents/doc123'), isTrue);
      });

      test('announcement detail accessible to all active users', () {
        expect(service.canAccessRoute(staff(), '/announcements/ann123'), isTrue);
      });

      test('announcement edit requires managerAdmin+', () {
        expect(service.canAccessRoute(manager(), '/announcements/ann123/edit'), isTrue);
        expect(service.canAccessRoute(staff(), '/announcements/ann123/edit'), isFalse);
      });
    });

    test('trailing slash is normalised', () {
      expect(service.canAccessRoute(staff(), '/chat/'), isTrue);
    });

    test('unknown route returns false', () {
      expect(service.canAccessRoute(owner(), '/nonexistent'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Organization management
  // -------------------------------------------------------------------------

  group('organization management', () {
    test('only platformOwner can manage orgs', () {
      expect(service.canManageOrganizations(owner()), isTrue);
      expect(service.canManageOrganizations(superAdmin()), isFalse);
      expect(service.canManageOrganizations(manager()), isFalse);
      expect(service.canManageOrganizations(staff()), isFalse);
    });

    test('only platformOwner can delete orgs', () {
      expect(service.canDeleteOrganization(owner()), isTrue);
      expect(service.canDeleteOrganization(superAdmin()), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // League management
  // -------------------------------------------------------------------------

  group('league management', () {
    test('platformOwner and superAdmin can create leagues', () {
      expect(service.canCreateLeague(owner()), isTrue);
      expect(service.canCreateLeague(superAdmin()), isTrue);
    });

    test('managerAdmin and staff cannot create leagues', () {
      expect(service.canCreateLeague(manager()), isFalse);
      expect(service.canCreateLeague(staff()), isFalse);
    });

    test('platformOwner and superAdmin can delete leagues', () {
      expect(service.canDeleteLeague(owner()), isTrue);
      expect(service.canDeleteLeague(superAdmin()), isTrue);
    });

    test('managerAdmin and staff cannot delete leagues', () {
      expect(service.canDeleteLeague(manager()), isFalse);
      expect(service.canDeleteLeague(staff()), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Hub management
  // -------------------------------------------------------------------------

  group('hub management', () {
    test('platformOwner and superAdmin can create hubs', () {
      expect(service.canCreateHub(owner()), isTrue);
      expect(service.canCreateHub(superAdmin()), isTrue);
    });

    test('managerAdmin can create hubs', () {
      expect(service.canCreateHub(manager(hubIds: ['h1'])), isTrue);
    });

    test('staff cannot create hubs', () {
      expect(service.canCreateHub(staff()), isFalse);
    });

    test('only superAdmin+ can delete hubs', () {
      expect(service.canDeleteHub(owner()), isTrue);
      expect(service.canDeleteHub(superAdmin()), isTrue);
      expect(service.canDeleteHub(manager()), isFalse);
      expect(service.canDeleteHub(staff()), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Team management
  // -------------------------------------------------------------------------

  group('team management', () {
    test('superAdmin+ can create teams for any hub', () {
      expect(service.canCreateTeam(owner(), hubId: 'h1'), isTrue);
      expect(service.canCreateTeam(superAdmin(), hubId: 'h1'), isTrue);
    });

    test('managerAdmin can create teams only in owned hubs', () {
      final ma = manager(hubIds: ['h1', 'h2']);
      expect(service.canCreateTeam(ma, hubId: 'h1'), isTrue);
      expect(service.canCreateTeam(ma, hubId: 'h2'), isTrue);
      expect(service.canCreateTeam(ma, hubId: 'h3'), isFalse);
    });

    test('managerAdmin can create teams when hubId is null', () {
      expect(service.canCreateTeam(manager(hubIds: ['h1'])), isTrue);
    });

    test('staff cannot create teams', () {
      expect(service.canCreateTeam(staff()), isFalse);
    });

    test('canDeleteTeam mirrors canCreateTeam', () {
      final ma = manager(hubIds: ['h1']);
      expect(service.canDeleteTeam(ma, hubId: 'h1'), isTrue);
      expect(service.canDeleteTeam(ma, hubId: 'h99'), isFalse);
      expect(service.canDeleteTeam(staff()), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // User management
  // -------------------------------------------------------------------------

  group('user management', () {
    test('canViewUserManagement requires managerAdmin+', () {
      expect(service.canViewUserManagement(owner()), isTrue);
      expect(service.canViewUserManagement(superAdmin()), isTrue);
      expect(service.canViewUserManagement(manager()), isTrue);
      expect(service.canViewUserManagement(staff()), isFalse);
    });

    group('canManageUser', () {
      test('cannot manage self', () {
        final sa = makeUser(id: 'sa', role: UserRole.superAdmin);
        expect(service.canManageUser(sa, sa), isFalse);
      });

      test('platformOwner can manage superAdmin', () {
        expect(service.canManageUser(owner(), superAdmin()), isTrue);
      });

      test('superAdmin can manage managerAdmin and staff', () {
        expect(service.canManageUser(superAdmin(), manager()), isTrue);
        expect(service.canManageUser(superAdmin(), staff()), isTrue);
      });

      test('superAdmin cannot manage another superAdmin', () {
        final sa2 = makeUser(id: 'sa2', role: UserRole.superAdmin);
        expect(service.canManageUser(superAdmin(), sa2), isFalse);
      });

      test('superAdmin cannot manage platformOwner', () {
        expect(service.canManageUser(superAdmin(), owner()), isFalse);
      });

      test('managerAdmin can manage staff in their hubs', () {
        final ma = manager(hubIds: ['h1']);
        final s = makeUser(id: 'staff', role: UserRole.staff, hubIds: ['h1']);
        expect(service.canManageUser(ma, s), isTrue);
      });

      test('managerAdmin cannot manage staff outside their hubs', () {
        final ma = manager(hubIds: ['h1']);
        final s = makeUser(id: 'staff', role: UserRole.staff, hubIds: ['h2']);
        expect(service.canManageUser(ma, s), isFalse);
      });

      test('managerAdmin cannot manage another managerAdmin', () {
        final ma2 = makeUser(id: 'ma2', role: UserRole.managerAdmin, hubIds: ['h1']);
        expect(service.canManageUser(manager(hubIds: ['h1']), ma2), isFalse);
      });

      test('staff cannot manage anyone', () {
        expect(service.canManageUser(staff(), manager()), isFalse);
        expect(service.canManageUser(staff(), staff()), isFalse);
      });
    });

    group('canChangeUserRole', () {
      test('superAdmin+ can change roles of lower-ranked users', () {
        expect(service.canChangeUserRole(superAdmin(), manager()), isTrue);
        expect(service.canChangeUserRole(superAdmin(), staff()), isTrue);
        expect(service.canChangeUserRole(owner(), superAdmin()), isTrue);
      });

      test('managerAdmin cannot change roles', () {
        final ma = manager(hubIds: ['h1']);
        final s = makeUser(id: 'staff', role: UserRole.staff, hubIds: ['h1']);
        expect(service.canChangeUserRole(ma, s), isFalse);
      });
    });

    group('assignableRoles', () {
      test('platformOwner can assign superAdmin, managerAdmin, staff', () {
        expect(service.assignableRoles(owner()),
            [UserRole.superAdmin, UserRole.managerAdmin, UserRole.staff]);
      });

      test('superAdmin can assign managerAdmin, staff', () {
        expect(service.assignableRoles(superAdmin()),
            [UserRole.managerAdmin, UserRole.staff]);
      });

      test('managerAdmin has no assignable roles', () {
        expect(service.assignableRoles(manager()), isEmpty);
      });

      test('staff has no assignable roles', () {
        expect(service.assignableRoles(staff()), isEmpty);
      });
    });

    group('deactivate/reactivate', () {
      test('delegates to canManageUser', () {
        final target = staff();
        expect(service.canDeactivateUser(superAdmin(), target), isTrue);
        expect(service.canReactivateUser(superAdmin(), target), isTrue);
        expect(service.canDeactivateUser(staff(), target), isFalse);
      });
    });
  });

  // -------------------------------------------------------------------------
  // Invitations
  // -------------------------------------------------------------------------

  group('invitations', () {
    test('canCreateInvitation requires managerAdmin+', () {
      expect(service.canCreateInvitation(owner()), isTrue);
      expect(service.canCreateInvitation(superAdmin()), isTrue);
      expect(service.canCreateInvitation(manager()), isTrue);
      expect(service.canCreateInvitation(staff()), isFalse);
    });

    test('canInviteToHub: superAdmin+ can invite to any hub', () {
      expect(service.canInviteToHub(superAdmin(), 'h_any'), isTrue);
    });

    test('canInviteToHub: managerAdmin only their hubs', () {
      final ma = manager(hubIds: ['h1']);
      expect(service.canInviteToHub(ma, 'h1'), isTrue);
      expect(service.canInviteToHub(ma, 'h2'), isFalse);
    });

    test('canInviteToHub: staff always false', () {
      expect(service.canInviteToHub(staff(), 'h1'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Announcements
  // -------------------------------------------------------------------------

  group('announcements', () {
    group('canCreateAnnouncement', () {
      test('requires managerAdmin+', () {
        expect(service.canCreateAnnouncement(owner()), isTrue);
        expect(service.canCreateAnnouncement(superAdmin()), isTrue);
        expect(service.canCreateAnnouncement(manager()), isTrue);
        expect(service.canCreateAnnouncement(staff()), isFalse);
      });
    });

    group('canCreateAnnouncementWithScope', () {
      test('superAdmin+ can create org-wide', () {
        expect(service.canCreateAnnouncementWithScope(superAdmin(), AnnouncementScope.orgWide), isTrue);
      });

      test('managerAdmin cannot create org-wide', () {
        expect(service.canCreateAnnouncementWithScope(manager(), AnnouncementScope.orgWide), isFalse);
      });

      test('managerAdmin can create league-scoped', () {
        expect(service.canCreateAnnouncementWithScope(manager(), AnnouncementScope.league), isTrue);
      });

      test('managerAdmin can create hub-scoped for own hub', () {
        final ma = manager(hubIds: ['h1']);
        expect(service.canCreateAnnouncementWithScope(ma, AnnouncementScope.hub, hubId: 'h1'), isTrue);
      });

      test('managerAdmin cannot create hub-scoped for other hub', () {
        final ma = manager(hubIds: ['h1']);
        expect(service.canCreateAnnouncementWithScope(ma, AnnouncementScope.hub, hubId: 'h2'), isFalse);
      });

      test('staff cannot create any scope', () {
        expect(service.canCreateAnnouncementWithScope(staff(), AnnouncementScope.hub), isFalse);
      });
    });

    group('canEditAnnouncement', () {
      test('superAdmin+ can edit any', () {
        expect(service.canEditAnnouncement(superAdmin(), authorId: 'anyone'), isTrue);
      });

      test('author can edit their own', () {
        final ma = manager();
        expect(service.canEditAnnouncement(ma, authorId: ma.id), isTrue);
      });

      test('non-author managerAdmin cannot edit', () {
        expect(service.canEditAnnouncement(manager(), authorId: 'other'), isFalse);
      });

      test('staff cannot edit', () {
        expect(service.canEditAnnouncement(staff(), authorId: 'staff'), isFalse);
      });
    });

    group('canDeleteAnnouncement', () {
      test('requires superAdmin+', () {
        expect(service.canDeleteAnnouncement(owner()), isTrue);
        expect(service.canDeleteAnnouncement(superAdmin()), isTrue);
        expect(service.canDeleteAnnouncement(manager()), isFalse);
        expect(service.canDeleteAnnouncement(staff()), isFalse);
      });
    });

    group('canTogglePin', () {
      test('requires superAdmin+', () {
        expect(service.canTogglePin(owner()), isTrue);
        expect(service.canTogglePin(superAdmin()), isTrue);
        expect(service.canTogglePin(manager()), isFalse);
        expect(service.canTogglePin(staff()), isFalse);
      });
    });

    group('canViewAnnouncement', () {
      test('superAdmin sees all scopes', () {
        expect(service.canViewAnnouncement(superAdmin(),
            scope: AnnouncementScope.hub, hubId: 'h99'), isTrue);
      });

      test('org-wide visible to everyone', () {
        expect(service.canViewAnnouncement(staff(),
            scope: AnnouncementScope.orgWide), isTrue);
      });

      test('hub-scoped visible only if user is in that hub', () {
        final s = makeUser(role: UserRole.staff, hubIds: ['h1']);
        expect(service.canViewAnnouncement(s,
            scope: AnnouncementScope.hub, hubId: 'h1'), isTrue);
        expect(service.canViewAnnouncement(s,
            scope: AnnouncementScope.hub, hubId: 'h2'), isFalse);
      });

      test('league-scoped visible to user in that league', () {
        expect(service.canViewAnnouncement(staff(leagueIds: ['l1']),
            scope: AnnouncementScope.league, leagueId: 'l1'), isTrue);
      });

      test('league-scoped NOT visible to user outside that league', () {
        expect(service.canViewAnnouncement(staff(leagueIds: ['l2']),
            scope: AnnouncementScope.league, leagueId: 'l1'), isFalse);
      });

      test('inactive user cannot view', () {
        expect(service.canViewAnnouncement(staff(isActive: false),
            scope: AnnouncementScope.orgWide), isFalse);
      });
    });
  });

  // -------------------------------------------------------------------------
  // Documents
  // -------------------------------------------------------------------------

  group('documents', () {
    test('canUploadDocument requires managerAdmin+', () {
      expect(service.canUploadDocument(owner()), isTrue);
      expect(service.canUploadDocument(superAdmin()), isTrue);
      expect(service.canUploadDocument(manager()), isTrue);
      expect(service.canUploadDocument(staff()), isFalse);
    });

    test('canUploadDocumentToHub: managerAdmin only own hubs', () {
      final ma = manager(hubIds: ['h1']);
      expect(service.canUploadDocumentToHub(ma, 'h1'), isTrue);
      expect(service.canUploadDocumentToHub(ma, 'h2'), isFalse);
      expect(service.canUploadDocumentToHub(superAdmin(), 'h_any'), isTrue);
    });

    group('canEditDocument', () {
      test('superAdmin+ can edit any', () {
        expect(service.canEditDocument(superAdmin(), uploadedBy: 'x'), isTrue);
      });

      test('managerAdmin can edit own uploads', () {
        final ma = manager();
        expect(service.canEditDocument(ma, uploadedBy: ma.id), isTrue);
      });

      test('managerAdmin cannot edit others uploads', () {
        expect(service.canEditDocument(manager(), uploadedBy: 'other'), isFalse);
      });

      test('staff cannot edit', () {
        expect(service.canEditDocument(staff(), uploadedBy: 'staff'), isFalse);
      });
    });

    test('canDeleteDocument requires superAdmin+', () {
      expect(service.canDeleteDocument(owner()), isTrue);
      expect(service.canDeleteDocument(superAdmin()), isTrue);
      expect(service.canDeleteDocument(manager()), isFalse);
      expect(service.canDeleteDocument(staff()), isFalse);
    });

    group('canViewDocument', () {
      test('superAdmin sees all', () {
        expect(service.canViewDocument(superAdmin(), hubId: 'h99'), isTrue);
      });

      test('hub-scoped doc visible if user is in hub', () {
        final s = makeUser(role: UserRole.staff, hubIds: ['h1']);
        expect(service.canViewDocument(s, hubId: 'h1'), isTrue);
        expect(service.canViewDocument(s, hubId: 'h2'), isFalse);
      });

      test('league-scoped doc visible to user in that league', () {
        expect(service.canViewDocument(staff(leagueIds: ['l1']), leagueId: 'l1'), isTrue);
      });

      test('league-scoped doc NOT visible to user outside that league', () {
        expect(service.canViewDocument(staff(leagueIds: ['l2']), leagueId: 'l1'), isFalse);
      });

      test('unscoped doc visible to everyone', () {
        expect(service.canViewDocument(staff()), isTrue);
      });
    });
  });

  // -------------------------------------------------------------------------
  // Chat
  // -------------------------------------------------------------------------

  group('chat', () {
    test('canCreateChatRoom requires managerAdmin+', () {
      expect(service.canCreateChatRoom(owner()), isTrue);
      expect(service.canCreateChatRoom(superAdmin()), isTrue);
      expect(service.canCreateChatRoom(manager()), isTrue);
      expect(service.canCreateChatRoom(staff()), isFalse);
    });

    test('canArchiveChatRoom requires managerAdmin+', () {
      expect(service.canArchiveChatRoom(owner()), isTrue);
      expect(service.canArchiveChatRoom(manager()), isTrue);
      expect(service.canArchiveChatRoom(staff()), isFalse);
    });

    test('canUpdateChatRoom requires managerAdmin+', () {
      expect(service.canUpdateChatRoom(owner()), isTrue);
      expect(service.canUpdateChatRoom(superAdmin()), isTrue);
      expect(service.canUpdateChatRoom(manager()), isTrue);
      expect(service.canUpdateChatRoom(staff()), isFalse);
    });

    test('canSendMessage any active user', () {
      expect(service.canSendMessage(staff()), isTrue);
      expect(service.canSendMessage(staff(isActive: false)), isFalse);
    });

    group('canViewChatRoom', () {
      test('superAdmin sees all rooms', () {
        final room = makeRoom(type: ChatRoomType.direct, participants: ['other1', 'other2']);
        expect(service.canViewChatRoom(superAdmin(), room), isTrue);
      });

      test('DM only visible to participants', () {
        final room = makeRoom(type: ChatRoomType.direct, participants: ['staff', 'other']);
        expect(service.canViewChatRoom(staff(), room), isTrue);

        final outsider = makeUser(id: 'outsider', role: UserRole.staff);
        expect(service.canViewChatRoom(outsider, room), isFalse);
      });

      test('league room visible to all active users', () {
        final room = makeRoom(type: ChatRoomType.league);
        expect(service.canViewChatRoom(staff(), room), isTrue);
      });

      test('event room visible to all active users', () {
        final room = makeRoom(type: ChatRoomType.event);
        expect(service.canViewChatRoom(staff(), room), isTrue);
      });

      test('inactive user cannot view', () {
        final room = makeRoom(type: ChatRoomType.league);
        expect(service.canViewChatRoom(staff(isActive: false), room), isFalse);
      });
    });
  });

  // -------------------------------------------------------------------------
  // Settings
  // -------------------------------------------------------------------------

  group('settings', () {
    test('canEditBranding requires superAdmin+', () {
      expect(service.canEditBranding(superAdmin()), isTrue);
      expect(service.canEditBranding(manager()), isFalse);
      expect(service.canEditBranding(staff()), isFalse);
    });

    test('canEditAppIcon requires superAdmin+', () {
      expect(service.canEditAppIcon(superAdmin()), isTrue);
      expect(service.canEditAppIcon(manager()), isFalse);
    });

    test('canViewRolesPermissions requires superAdmin+', () {
      expect(service.canViewRolesPermissions(superAdmin()), isTrue);
      expect(service.canViewRolesPermissions(manager()), isFalse);
    });

    test('canEditProfile only own profile', () {
      final user = staff();
      expect(service.canEditProfile(user, user.id), isTrue);
      expect(service.canEditProfile(user, 'other'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Settings tiles visibility
  // -------------------------------------------------------------------------

  group('visibleSettingsTiles', () {
    test('staff sees profile, notifications, privacy only', () {
      final tiles = service.visibleSettingsTiles(staff());
      expect(tiles, containsAll(['profile', 'notifications', 'privacy']));
      expect(tiles, isNot(contains('users')));
      expect(tiles, isNot(contains('roles')));
      expect(tiles, isNot(contains('branding')));
      expect(tiles, isNot(contains('leagues')));
    });

    test('managerAdmin also sees users', () {
      final tiles = service.visibleSettingsTiles(manager());
      expect(tiles, containsAll(['profile', 'notifications', 'privacy', 'users']));
      expect(tiles, isNot(contains('roles')));
      expect(tiles, isNot(contains('branding')));
    });

    test('superAdmin sees everything except org management', () {
      final tiles = service.visibleSettingsTiles(superAdmin());
      expect(tiles, containsAll([
        'profile', 'notifications', 'privacy', 'users',
        'roles', 'branding', 'app-icon', 'leagues',
      ]));
    });

    test('platformOwner sees everything', () {
      final tiles = service.visibleSettingsTiles(owner());
      expect(tiles, containsAll([
        'profile', 'notifications', 'privacy', 'users',
        'roles', 'branding', 'app-icon', 'leagues',
      ]));
    });
  });
}
