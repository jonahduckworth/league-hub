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
    String? hubId,
    String? teamId,
    List<String> hubIds = const [],
    List<String> teamIds = const [],
  }) =>
      ChatRoom(
        id: id,
        orgId: 'org1',
        name: 'Room',
        type: type,
        leagueId: leagueId,
        hubId: hubId,
        teamId: teamId,
        hubIds: hubIds,
        teamIds: teamIds,
        participants: participants,
        createdAt: DateTime(2024),
        isArchived: false,
      );

  // Shorthand
  AppUser owner(
          {bool isActive = true,
          List<String> hubIds = const [],
          List<String> leagueIds = const []}) =>
      makeUser(
          id: 'owner',
          role: UserRole.platformOwner,
          isActive: isActive,
          hubIds: hubIds,
          leagueIds: leagueIds);
  AppUser superAdmin(
          {bool isActive = true,
          List<String> hubIds = const [],
          List<String> leagueIds = const []}) =>
      makeUser(
          id: 'sa',
          role: UserRole.superAdmin,
          isActive: isActive,
          hubIds: hubIds,
          leagueIds: leagueIds);
  AppUser manager(
          {bool isActive = true,
          List<String> hubIds = const [],
          List<String> leagueIds = const [],
          List<String> teamIds = const []}) =>
      makeUser(
          id: 'ma',
          role: UserRole.managerAdmin,
          isActive: isActive,
          hubIds: hubIds,
          leagueIds: leagueIds,
          teamIds: teamIds);
  AppUser staff(
          {bool isActive = true,
          List<String> hubIds = const [],
          List<String> leagueIds = const [],
          List<String> teamIds = const []}) =>
      makeUser(
          id: 'staff',
          role: UserRole.staff,
          isActive: isActive,
          hubIds: hubIds,
          leagueIds: leagueIds,
          teamIds: teamIds);

  // -------------------------------------------------------------------------
  // Hierarchy helpers
  // -------------------------------------------------------------------------

  group('isAtLeast', () {
    test('platformOwner is at least every role', () {
      expect(
          PermissionService.isAtLeast(
              UserRole.platformOwner, UserRole.platformOwner),
          isTrue);
      expect(
          PermissionService.isAtLeast(
              UserRole.platformOwner, UserRole.superAdmin),
          isTrue);
      expect(
          PermissionService.isAtLeast(
              UserRole.platformOwner, UserRole.managerAdmin),
          isTrue);
      expect(
          PermissionService.isAtLeast(UserRole.platformOwner, UserRole.staff),
          isTrue);
    });

    test('superAdmin is at least superAdmin, managerAdmin, staff', () {
      expect(
          PermissionService.isAtLeast(
              UserRole.superAdmin, UserRole.platformOwner),
          isFalse);
      expect(
          PermissionService.isAtLeast(UserRole.superAdmin, UserRole.superAdmin),
          isTrue);
      expect(
          PermissionService.isAtLeast(
              UserRole.superAdmin, UserRole.managerAdmin),
          isTrue);
      expect(PermissionService.isAtLeast(UserRole.superAdmin, UserRole.staff),
          isTrue);
    });

    test('managerAdmin is at least managerAdmin and staff', () {
      expect(
          PermissionService.isAtLeast(
              UserRole.managerAdmin, UserRole.platformOwner),
          isFalse);
      expect(
          PermissionService.isAtLeast(
              UserRole.managerAdmin, UserRole.superAdmin),
          isFalse);
      expect(
          PermissionService.isAtLeast(
              UserRole.managerAdmin, UserRole.managerAdmin),
          isTrue);
      expect(PermissionService.isAtLeast(UserRole.managerAdmin, UserRole.staff),
          isTrue);
    });

    test('staff is only at least staff', () {
      expect(
          PermissionService.isAtLeast(UserRole.staff, UserRole.platformOwner),
          isFalse);
      expect(PermissionService.isAtLeast(UserRole.staff, UserRole.superAdmin),
          isFalse);
      expect(PermissionService.isAtLeast(UserRole.staff, UserRole.managerAdmin),
          isFalse);
      expect(
          PermissionService.isAtLeast(UserRole.staff, UserRole.staff), isTrue);
    });
  });

  group('outranks', () {
    test('platformOwner outranks everyone except itself', () {
      expect(
          PermissionService.outranks(
              UserRole.platformOwner, UserRole.platformOwner),
          isFalse);
      expect(
          PermissionService.outranks(
              UserRole.platformOwner, UserRole.superAdmin),
          isTrue);
      expect(
          PermissionService.outranks(
              UserRole.platformOwner, UserRole.managerAdmin),
          isTrue);
      expect(PermissionService.outranks(UserRole.platformOwner, UserRole.staff),
          isTrue);
    });

    test('staff outranks nobody', () {
      expect(PermissionService.outranks(UserRole.staff, UserRole.platformOwner),
          isFalse);
      expect(PermissionService.outranks(UserRole.staff, UserRole.superAdmin),
          isFalse);
      expect(PermissionService.outranks(UserRole.staff, UserRole.managerAdmin),
          isFalse);
      expect(
          PermissionService.outranks(UserRole.staff, UserRole.staff), isFalse);
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
      expect(service.canUploadPolicy(inactive), isFalse);
      expect(service.canDeletePolicy(inactive), isFalse);
      expect(service.canCreateChatRoom(inactive), isFalse);
      expect(service.canArchiveChatRoom(inactive), isFalse);
      expect(service.canSendMessage(inactive), isFalse);
      expect(service.canCreateInvitation(inactive), isFalse);
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
      for (final route in [
        '/',
        '/chat',
        '/policy',
        '/announcements',
        '/settings',
        '/settings/profile',
        '/settings/app-icon',
        '/settings/notifications',
        '/settings/privacy'
      ]) {
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
        expect(service.canAccessRoute(manager(), '/settings/users/abc123'),
            isTrue);
      });

      test('/settings/users/:userId blocked for staff', () {
        expect(
            service.canAccessRoute(staff(), '/settings/users/abc123'), isFalse);
      });
    });

    group('admin routes', () {
      for (final route in ['/settings/roles']) {
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
      for (final route in ['/policy/upload', '/announcements/create']) {
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

      test('policy detail accessible to all active users', () {
        expect(service.canAccessRoute(staff(), '/policy/doc123'), isTrue);
      });

      test('announcement detail accessible to all active users', () {
        expect(
            service.canAccessRoute(staff(), '/announcements/ann123'), isTrue);
      });

      test('announcement edit requires managerAdmin+', () {
        expect(service.canAccessRoute(manager(), '/announcements/ann123/edit'),
            isTrue);
        expect(service.canAccessRoute(staff(), '/announcements/ann123/edit'),
            isFalse);
      });

      test('league structure mutations use operation-specific roles', () {
        expect(
            service.canAccessRoute(owner(), '/settings/leagues/new'), isTrue);
        expect(service.canAccessRoute(superAdmin(), '/settings/leagues/new'),
            isFalse);
        expect(
            service.canAccessRoute(
                manager(), '/settings/leagues/league-1/edit'),
            isFalse);
        expect(
            service.canAccessRoute(
                manager(), '/settings/leagues/league-1/hubs/new'),
            isFalse);
        expect(
            service.canAccessRoute(
                manager(), '/settings/leagues/league-1/hubs/hub-1/edit'),
            isTrue);
        expect(
            service.canAccessRoute(
                manager(), '/settings/leagues/league-1/hubs/hub-1/teams/new'),
            isTrue);
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

    test('platformOwner and superAdmin can update organization settings', () {
      expect(service.canUpdateOrganization(owner()), isTrue);
      expect(service.canUpdateOrganization(superAdmin()), isTrue);
      expect(service.canUpdateOrganization(manager()), isFalse);
      expect(service.canUpdateOrganization(staff()), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // League management
  // -------------------------------------------------------------------------

  group('league management', () {
    test('only platformOwner can create leagues', () {
      expect(service.canCreateLeague(owner()), isTrue);
      expect(service.canCreateLeague(superAdmin()), isFalse);
    });

    test('managerAdmin and staff cannot create leagues', () {
      expect(service.canCreateLeague(manager()), isFalse);
      expect(service.canCreateLeague(staff()), isFalse);
    });

    test('superAdmin+ can update existing leagues', () {
      expect(service.canUpdateLeague(owner()), isTrue);
      expect(service.canUpdateLeague(superAdmin()), isTrue);
      expect(service.canUpdateLeague(manager()), isFalse);
      expect(service.canUpdateLeague(staff()), isFalse);
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

    test('managerAdmin cannot create hubs', () {
      expect(service.canCreateHub(manager(hubIds: ['h1'])), isFalse);
    });

    test('managerAdmin can update only assigned hubs', () {
      final ma = manager(hubIds: ['h1']);
      expect(service.canUpdateHub(ma, hubId: 'h1'), isTrue);
      expect(service.canUpdateHub(ma, hubId: 'h2'), isFalse);
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

    test('managerAdmin requires an explicit assigned hub', () {
      expect(service.canCreateTeam(manager(hubIds: ['h1'])), isFalse);
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

    test('manager roster access requires both hub and team assignments', () {
      final ma = manager(hubIds: ['h1'], teamIds: ['t1']);
      expect(
          service.canManageTeamRoster(ma, hubId: 'h1', teamId: 't1'), isTrue);
      expect(
          service.canManageTeamRoster(ma, hubId: 'h1', teamId: 't2'), isFalse);
      expect(
          service.canManageTeamRoster(ma, hubId: 'h2', teamId: 't1'), isFalse);
      expect(
          service.canManageTeamRoster(
            superAdmin(),
            hubId: 'any-hub',
            teamId: 'any-team',
          ),
          isTrue);
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

      test('managerAdmin must own every hub assigned to the staff user', () {
        final ma = manager(hubIds: ['h1']);
        final s = makeUser(
          id: 'staff',
          role: UserRole.staff,
          hubIds: ['h1', 'h2'],
        );
        expect(service.canManageUser(ma, s), isFalse);
      });

      test('managerAdmin must own every team assigned to the staff user', () {
        final ma = manager(hubIds: ['h1'], teamIds: ['t1']);
        final s = makeUser(
          id: 'staff',
          role: UserRole.staff,
          hubIds: ['h1'],
          teamIds: ['t1', 't2'],
        );
        expect(service.canManageUser(ma, s), isFalse);
      });

      test('organization admins cannot manage users in another org', () {
        final otherOrgStaff = makeUser(
          id: 'other-staff',
          role: UserRole.staff,
          orgId: 'org2',
        );
        expect(service.canManageUser(superAdmin(), otherOrgStaff), isFalse);
        expect(service.canManageUser(owner(), otherOrgStaff), isTrue);
      });

      test('managerAdmin cannot manage another managerAdmin', () {
        final ma2 =
            makeUser(id: 'ma2', role: UserRole.managerAdmin, hubIds: ['h1']);
        expect(service.canManageUser(manager(hubIds: ['h1']), ma2), isFalse);
      });

      test('staff cannot manage anyone', () {
        expect(service.canManageUser(staff(), manager()), isFalse);
        expect(service.canManageUser(staff(), staff()), isFalse);
      });
    });

    group('canManageUserAssignments', () {
      test('allows a super admin to update same-org peer assignments only', () {
        final actor = superAdmin();
        final peer = makeUser(id: 'peer', role: UserRole.superAdmin);

        expect(service.canManageUser(actor, peer), isFalse);
        expect(service.canManageUserAssignments(actor, peer), isTrue);
      });

      test('rejects self, platform owner, and cross-org assignments', () {
        final actor = superAdmin();

        expect(service.canManageUserAssignments(actor, actor), isFalse);
        expect(service.canManageUserAssignments(actor, owner()), isFalse);
        expect(
          service.canManageUserAssignments(
            actor,
            makeUser(
              id: 'peer',
              role: UserRole.superAdmin,
              orgId: 'other-org',
            ),
          ),
          isFalse,
        );
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

    test('canInviteToTeam: managerAdmin only their teams', () {
      final ma = manager(teamIds: ['t1']);
      expect(service.canInviteToTeam(ma, 't1'), isTrue);
      expect(service.canInviteToTeam(ma, 't2'), isFalse);
      expect(service.canInviteToTeam(superAdmin(), 't_any'), isTrue);
      expect(service.canInviteToTeam(staff(), 't1'), isFalse);
    });

    test('invitable roles follow the canonical hierarchy', () {
      expect(service.invitableRoles(owner()), [
        UserRole.superAdmin,
        UserRole.managerAdmin,
        UserRole.staff,
      ]);
      expect(service.invitableRoles(superAdmin()), [
        UserRole.managerAdmin,
        UserRole.staff,
      ]);
      expect(service.invitableRoles(manager()), [UserRole.staff]);
      expect(service.invitableRoles(staff()), isEmpty);
      expect(service.invitableRoles(owner(isActive: false)), isEmpty);
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
      test('superAdmin+ can create league-scoped', () {
        expect(
            service.canCreateAnnouncementWithScope(
                superAdmin(), AnnouncementScope.league,
                leagueId: 'l1'),
            isTrue);
      });

      test('managerAdmin can create league-scoped', () {
        expect(
            service.canCreateAnnouncementWithScope(
              manager(leagueIds: ['l1']),
              AnnouncementScope.league,
              leagueId: 'l1',
            ),
            isTrue);
      });

      test('managerAdmin cannot create league-scoped outside assignment', () {
        expect(
            service.canCreateAnnouncementWithScope(
              manager(leagueIds: ['l1']),
              AnnouncementScope.league,
              leagueId: 'l2',
            ),
            isFalse);
      });

      test('managerAdmin can create hub-scoped for own hub', () {
        final ma = manager(hubIds: ['h1']);
        expect(
            service.canCreateAnnouncementWithScope(ma, AnnouncementScope.hub,
                leagueId: 'l1', hubId: 'h1'),
            isTrue);
      });

      test('managerAdmin cannot create hub-scoped for other hub', () {
        final ma = manager(hubIds: ['h1']);
        expect(
            service.canCreateAnnouncementWithScope(ma, AnnouncementScope.hub,
                leagueId: 'l1', hubId: 'h2'),
            isFalse);
      });

      test('managerAdmin can create team-scoped for own team', () {
        final ma = manager(hubIds: ['h1'], teamIds: ['t1']);
        expect(
            service.canCreateAnnouncementWithScope(
              ma,
              AnnouncementScope.team,
              leagueId: 'l1',
              hubId: 'h1',
              teamId: 't1',
            ),
            isTrue);
      });

      test('staff cannot create any scope', () {
        expect(
            service.canCreateAnnouncementWithScope(
                staff(), AnnouncementScope.hub),
            isFalse);
      });
    });

    group('canEditAnnouncement', () {
      test('superAdmin+ can edit any', () {
        expect(service.canEditAnnouncement(superAdmin(), authorId: 'anyone'),
            isTrue);
      });

      test('author can edit their own', () {
        final ma = manager();
        expect(service.canEditAnnouncement(ma, authorId: ma.id), isTrue);
      });

      test('non-author managerAdmin cannot edit', () {
        expect(
            service.canEditAnnouncement(manager(), authorId: 'other'), isFalse);
      });

      test('staff cannot edit', () {
        expect(
            service.canEditAnnouncement(staff(), authorId: 'staff'), isFalse);
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
        expect(
            service.canViewAnnouncement(superAdmin(),
                scope: AnnouncementScope.hub, hubId: 'h99'),
            isTrue);
      });

      test('incomplete scoped records are not broadly visible', () {
        expect(
            service.canViewAnnouncement(staff(),
                scope: AnnouncementScope.league),
            isFalse);
      });

      test('hub-scoped visible only if user is in that hub', () {
        final s = makeUser(role: UserRole.staff, hubIds: ['h1']);
        expect(
            service.canViewAnnouncement(s,
                scope: AnnouncementScope.hub, hubId: 'h1'),
            isTrue);
        expect(
            service.canViewAnnouncement(s,
                scope: AnnouncementScope.hub, hubId: 'h2'),
            isFalse);
      });

      test('league-scoped visible to user in that league', () {
        expect(
            service.canViewAnnouncement(staff(leagueIds: ['l1']),
                scope: AnnouncementScope.league, leagueId: 'l1'),
            isTrue);
      });

      test('league-scoped NOT visible to user outside that league', () {
        expect(
            service.canViewAnnouncement(staff(leagueIds: ['l2']),
                scope: AnnouncementScope.league, leagueId: 'l1'),
            isFalse);
      });

      test('team-scoped visible to team members and hub managers', () {
        expect(
            service.canViewAnnouncement(staff(teamIds: ['t1']),
                scope: AnnouncementScope.team, leagueId: 'l1', teamId: 't1'),
            isTrue);
        expect(
            service.canViewAnnouncement(manager(hubIds: ['h1']),
                scope: AnnouncementScope.team,
                leagueId: 'l1',
                hubId: 'h1',
                teamId: 't1'),
            isTrue);
        expect(
            service.canViewAnnouncement(staff(teamIds: ['t2']),
                scope: AnnouncementScope.team, leagueId: 'l1', teamId: 't1'),
            isFalse);
      });

      test('inactive user cannot view', () {
        expect(
            service.canViewAnnouncement(staff(isActive: false),
                scope: AnnouncementScope.league, leagueId: 'l1'),
            isFalse);
      });
    });
  });

  // -------------------------------------------------------------------------
  // Policy
  // -------------------------------------------------------------------------

  group('policies', () {
    test('canUploadPolicy requires managerAdmin+', () {
      expect(service.canUploadPolicy(owner()), isTrue);
      expect(service.canUploadPolicy(superAdmin()), isTrue);
      expect(service.canUploadPolicy(manager()), isTrue);
      expect(service.canUploadPolicy(staff()), isFalse);
    });

    test('canUploadPolicyToHub: managerAdmin only own hubs', () {
      final ma = manager(hubIds: ['h1']);
      expect(service.canUploadPolicyToHub(ma, 'h1'), isTrue);
      expect(service.canUploadPolicyToHub(ma, 'h2'), isFalse);
      expect(service.canUploadPolicyToHub(superAdmin(), 'h_any'), isTrue);
    });

    test('canUploadPolicyToScope standardizes organization, hub, and team', () {
      final ma = manager(leagueIds: ['l1'], hubIds: ['h1'], teamIds: ['t1']);
      expect(service.canUploadPolicyToScope(owner(), leagueId: null), isTrue);
      expect(service.canUploadPolicyToScope(ma, leagueId: null), isFalse);
      expect(
          service.canUploadPolicyToScope(superAdmin(), leagueId: null), isTrue);
      expect(service.canUploadPolicyToScope(staff(), leagueId: null), isFalse);
      expect(service.canUploadPolicyToScope(owner(), leagueId: 'l1'), isFalse);
      expect(service.canUploadPolicyToScope(ma, leagueId: 'l1'), isFalse);
      expect(service.canUploadPolicyToScope(superAdmin(), leagueId: 'l1'),
          isFalse);
      expect(service.canUploadPolicyToScope(ma, leagueId: 'l1', hubId: 'h1'),
          isTrue);
      expect(service.canUploadPolicyToScope(ma, leagueId: 'l1', hubId: 'h2'),
          isFalse);
      expect(
          service.canUploadPolicyToScope(ma,
              leagueId: 'l1', hubId: 'h1', teamId: 't1'),
          isTrue);
      expect(service.canUploadPolicyToScope(ma, leagueId: 'l1', teamId: 't1'),
          isFalse);
    });

    group('canEditPolicy', () {
      test('superAdmin+ can edit any', () {
        expect(service.canEditPolicy(superAdmin(), uploadedBy: 'x'), isTrue);
      });

      test('managerAdmin can edit own uploads', () {
        final ma = manager();
        expect(service.canEditPolicy(ma, uploadedBy: ma.id), isTrue);
      });

      test('managerAdmin cannot edit others uploads', () {
        expect(service.canEditPolicy(manager(), uploadedBy: 'other'), isFalse);
      });

      test('staff cannot edit', () {
        expect(service.canEditPolicy(staff(), uploadedBy: 'staff'), isFalse);
      });
    });

    test('canDeletePolicy requires superAdmin+', () {
      expect(service.canDeletePolicy(owner()), isTrue);
      expect(service.canDeletePolicy(superAdmin()), isTrue);
      expect(service.canDeletePolicy(manager()), isFalse);
      expect(service.canDeletePolicy(staff()), isFalse);
    });

    group('canViewPolicy', () {
      test('superAdmin sees all', () {
        expect(service.canViewPolicy(superAdmin(), hubId: 'h99'), isTrue);
      });

      test('hub-scoped policy visible if user is in hub', () {
        final s = makeUser(role: UserRole.staff, hubIds: ['h1']);
        expect(service.canViewPolicy(s, hubId: 'h1'), isTrue);
        expect(service.canViewPolicy(s, hubId: 'h2'), isFalse);
      });

      test('legacy league-only policy is treated as organization-wide', () {
        expect(service.canViewPolicy(staff(leagueIds: ['l1']), leagueId: 'l1'),
            isTrue);
        expect(service.canViewPolicy(staff(leagueIds: ['l2']), leagueId: 'l1'),
            isTrue);
      });

      test('unscoped policy visible to everyone', () {
        expect(service.canViewPolicy(staff()), isTrue);
      });

      test('team-scoped policy visible to team members and hub managers', () {
        expect(service.canViewPolicy(staff(teamIds: ['t1']), teamId: 't1'),
            isTrue);
        expect(
            service.canViewPolicy(manager(hubIds: ['h1']),
                hubId: 'h1', teamId: 't1'),
            isTrue);
        expect(service.canViewPolicy(staff(teamIds: ['t2']), teamId: 't1'),
            isFalse);
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

    test('all active roles can create direct messages', () {
      expect(service.canCreateDirectMessage(owner()), isTrue);
      expect(service.canCreateDirectMessage(superAdmin()), isTrue);
      expect(service.canCreateDirectMessage(manager()), isTrue);
      expect(service.canCreateDirectMessage(staff()), isTrue);
      expect(service.canCreateDirectMessage(staff(isActive: false)), isFalse);
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

    test('managed room changes require a non-DM room in assigned scope', () {
      final assignedManager = manager(
        leagueIds: ['league-1'],
        hubIds: ['hub-1'],
        teamIds: ['team-1'],
      );
      expect(
          service.canManageChatRoom(
            assignedManager,
            makeRoom(
              type: ChatRoomType.event,
              leagueId: 'league-1',
              hubId: 'hub-1',
              teamId: 'team-1',
            ),
          ),
          isTrue);
      expect(
          service.canManageChatRoom(
            assignedManager,
            makeRoom(
              type: ChatRoomType.event,
              leagueId: 'league-1',
              hubId: 'hub-2',
            ),
          ),
          isFalse);
      expect(
          service.canManageChatRoom(
            assignedManager,
            makeRoom(
              type: ChatRoomType.direct,
              participants: ['ma', 'staff'],
            ),
          ),
          isFalse);
    });

    test('multi-team Event Rooms honor every role and selected audience', () {
      final room = makeRoom(
        type: ChatRoomType.event,
        leagueId: 'league-1',
        hubId: 'hub-1',
        teamId: 'team-1',
        hubIds: const ['hub-1', 'hub-2'],
        teamIds: const ['team-1', 'team-2'],
      );

      expect(service.canViewChatRoom(owner(), room), isTrue);
      expect(service.canViewChatRoom(superAdmin(), room), isTrue);
      expect(
        service.canViewChatRoom(manager(hubIds: const ['hub-2']), room),
        isTrue,
      );
      expect(
        service.canViewChatRoom(staff(teamIds: const ['team-2']), room),
        isTrue,
      );
      expect(
        service.canViewChatRoom(staff(hubIds: const ['hub-2']), room),
        isFalse,
      );
      expect(
        service.canViewChatRoom(staff(leagueIds: const ['league-1']), room),
        isFalse,
      );
      expect(
        service.canManageChatRoom(
          manager(hubIds: const ['hub-1', 'hub-2']),
          room,
        ),
        isTrue,
      );
      expect(
        service.canManageChatRoom(manager(hubIds: const ['hub-1']), room),
        isFalse,
      );
      expect(service.canManageChatRoom(staff(teamIds: const ['team-1']), room),
          isFalse);
    });

    test('Structure-managed General rooms cannot be edited by any role', () {
      final structureRoom = makeRoom(
        type: ChatRoomType.league,
        leagueId: 'league-1',
        hubId: 'hub-1',
      );
      expect(service.canEditChatRoomDetails(owner(), structureRoom), isFalse);
      expect(
          service.canEditChatRoomDetails(superAdmin(), structureRoom), isFalse);
      expect(
        service.canEditChatRoomDetails(
          manager(leagueIds: ['league-1'], hubIds: ['hub-1']),
          structureRoom,
        ),
        isFalse,
      );
      expect(service.canEditChatRoomDetails(staff(), structureRoom), isFalse);

      final eventRoom = makeRoom(
        type: ChatRoomType.event,
        leagueId: 'league-1',
        hubId: 'hub-1',
      );
      expect(service.canEditChatRoomDetails(owner(), eventRoom), isTrue);
      expect(service.canEditChatRoomDetails(superAdmin(), eventRoom), isTrue);
      expect(
        service.canEditChatRoomDetails(
          manager(leagueIds: ['league-1'], hubIds: ['hub-1']),
          eventRoom,
        ),
        isTrue,
      );
      expect(service.canEditChatRoomDetails(staff(), eventRoom), isFalse);
    });

    test('canSendMessage any active user', () {
      expect(service.canSendMessage(staff()), isTrue);
      expect(service.canSendMessage(staff(isActive: false)), isFalse);
    });

    group('canViewChatRoom', () {
      test('superAdmin sees all rooms', () {
        final room = makeRoom(
            type: ChatRoomType.direct, participants: ['other1', 'other2']);
        expect(service.canViewChatRoom(superAdmin(), room), isTrue);
      });

      test('DM only visible to participants', () {
        final room = makeRoom(
            type: ChatRoomType.direct, participants: ['staff', 'other']);
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

      test('league-scoped event room visible only to league users', () {
        final room = makeRoom(
          type: ChatRoomType.event,
          leagueId: 'league-1',
        );
        expect(service.canViewChatRoom(staff(leagueIds: ['league-1']), room),
            isTrue);
        expect(service.canViewChatRoom(staff(leagueIds: ['league-2']), room),
            isFalse);
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
    test('canEditAppIcon is a personal device setting', () {
      expect(service.canEditAppIcon(superAdmin()), isTrue);
      expect(service.canEditAppIcon(manager()), isTrue);
      expect(service.canEditAppIcon(staff()), isTrue);
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

  group('schedule', () {
    test('elevated admins see the full organization schedule', () {
      expect(
        service.canViewScheduleEvent(
          superAdmin(),
          teamIds: const ['other-team'],
          hubIds: const ['other-hub'],
          leagueIds: const ['other-league'],
        ),
        isTrue,
      );
      expect(
        service.canViewScheduleEvent(
          owner(),
          teamIds: const [],
          hubIds: const [],
          leagueIds: const [],
        ),
        isTrue,
      );
    });

    test('staff see assigned team games but not unrelated games', () {
      final user = staff(teamIds: const ['team-1']);
      expect(
        service.canViewScheduleEvent(
          user,
          teamIds: const ['team-1'],
          hubIds: const ['hub-1'],
          leagueIds: const ['league-1'],
        ),
        isTrue,
      );
      expect(
        service.canViewScheduleEvent(
          user,
          teamIds: const ['team-2'],
          hubIds: const ['hub-2'],
          leagueIds: const ['league-1'],
        ),
        isFalse,
      );
    });

    test('hub managers see games for teams in their hubs', () {
      expect(
        service.canViewScheduleEvent(
          manager(hubIds: const ['hub-1']),
          teamIds: const ['team-2'],
          hubIds: const ['hub-1'],
          leagueIds: const ['league-1'],
        ),
        isTrue,
      );
    });

    test('inactive users cannot see schedule data', () {
      expect(
        service.canViewScheduleEvent(
          staff(isActive: false, teamIds: const ['team-1']),
          teamIds: const ['team-1'],
          hubIds: const [],
          leagueIds: const [],
        ),
        isFalse,
      );
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

    test('managerAdmin also sees users and assigned structure', () {
      final tiles = service.visibleSettingsTiles(manager());
      expect(
          tiles,
          containsAll(
              ['profile', 'notifications', 'privacy', 'users', 'leagues']));
      expect(tiles, isNot(contains('roles')));
      expect(tiles, isNot(contains('branding')));
    });

    test('superAdmin sees everything except org management', () {
      final tiles = service.visibleSettingsTiles(superAdmin());
      expect(
          tiles,
          containsAll([
            'profile',
            'notifications',
            'privacy',
            'users',
            'roles',
            'app-icon',
            'leagues',
          ]));
      expect(tiles, isNot(contains('branding')));
    });

    test('platformOwner sees everything', () {
      final tiles = service.visibleSettingsTiles(owner());
      expect(
          tiles,
          containsAll([
            'profile',
            'notifications',
            'privacy',
            'users',
            'roles',
            'app-icon',
            'leagues',
          ]));
      expect(tiles, isNot(contains('branding')));
    });
  });
}
