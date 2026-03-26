import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/services/permission_service.dart';

void main() {
  const ps = PermissionService();

  // -------------------------------------------------------------------------
  // Helper factories for test users
  // -------------------------------------------------------------------------

  AppUser makeUser({
    String id = 'user1',
    UserRole role = UserRole.staff,
    String? orgId = 'org1',
    List<String> hubIds = const [],
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
        teamIds: teamIds,
        createdAt: DateTime(2024),
        isActive: isActive,
      );

  // Shorthand factories for each role
  AppUser platformOwner(
      {bool isActive = true, List<String> hubIds = const []}) =>
      makeUser(
        id: 'owner',
        role: UserRole.platformOwner,
        isActive: isActive,
        hubIds: hubIds,
      );

  AppUser superAdmin(
      {bool isActive = true, List<String> hubIds = const []}) =>
      makeUser(
        id: 'superadmin',
        role: UserRole.superAdmin,
        isActive: isActive,
        hubIds: hubIds,
      );

  AppUser managerAdmin(
      {bool isActive = true, List<String> hubIds = const []}) =>
      makeUser(
        id: 'manager',
        role: UserRole.managerAdmin,
        isActive: isActive,
        hubIds: hubIds,
      );

  AppUser staff({bool isActive = true, List<String> hubIds = const []}) =>
      makeUser(
        id: 'staff',
        role: UserRole.staff,
        isActive: isActive,
        hubIds: hubIds,
      );

  AppUser inactiveUser({UserRole role = UserRole.staff}) =>
      makeUser(
        id: 'inactive',
        role: role,
        isActive: false,
      );

  // =========================================================================
  // PUBLIC ROUTES
  // =========================================================================

  group('Public routes', () {
    const publicRoutes = [
      '/',
      '/chat',
      '/documents',
      '/announcements',
      '/settings',
      '/settings/profile',
      '/settings/notifications',
      '/settings/privacy',
    ];

    group('all roles can access', () {
      for (final route in publicRoutes) {
        test('$route - platformOwner', () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });

        test('$route - superAdmin', () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });

        test('$route - managerAdmin', () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });

        test('$route - staff', () {
          expect(ps.canAccessRoute(staff(), route), isTrue);
        });
      }
    });

    group('trailing slash normalisation', () {
      test('/ does not normalise to empty string', () {
        expect(ps.canAccessRoute(staff(), '/'), isTrue);
      });

      test('/chat/ is equivalent to /chat', () {
        expect(ps.canAccessRoute(staff(), '/chat/'), isTrue);
      });

      test('/settings/ is equivalent to /settings', () {
        expect(ps.canAccessRoute(staff(), '/settings/'), isTrue);
      });

      test('/settings/profile/ is equivalent to /settings/profile', () {
        expect(ps.canAccessRoute(staff(), '/settings/profile/'), isTrue);
      });
    });
  });

  // =========================================================================
  // MANAGER ROUTES
  // =========================================================================

  group('Manager routes (/settings/users)', () {
    const managerRoutes = ['/settings/users'];

    group('platformOwner can access', () {
      for (final route in managerRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });
      }
    });

    group('superAdmin can access', () {
      for (final route in managerRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });
      }
    });

    group('managerAdmin can access', () {
      for (final route in managerRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });
      }
    });

    group('staff cannot access', () {
      for (final route in managerRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(staff(), route), isFalse);
        });
      }
    });
  });

  // =========================================================================
  // ADMIN ROUTES
  // =========================================================================

  group('Admin routes', () {
    const adminRoutes = [
      '/settings/roles',
      '/settings/branding',
      '/settings/app-icon',
      '/settings/leagues',
    ];

    group('platformOwner can access', () {
      for (final route in adminRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });
      }
    });

    group('superAdmin can access', () {
      for (final route in adminRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });
      }
    });

    group('managerAdmin cannot access', () {
      for (final route in adminRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(managerAdmin(), route), isFalse);
        });
      }
    });

    group('staff cannot access', () {
      for (final route in adminRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(staff(), route), isFalse);
        });
      }
    });
  });

  // =========================================================================
  // CONTENT CREATION ROUTES
  // =========================================================================

  group('Content creation routes', () {
    const contentRoutes = [
      '/documents/upload',
      '/announcements/create',
    ];

    group('platformOwner can access', () {
      for (final route in contentRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });
      }
    });

    group('superAdmin can access', () {
      for (final route in contentRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });
      }
    });

    group('managerAdmin can access', () {
      for (final route in contentRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });
      }
    });

    group('staff cannot access', () {
      for (final route in contentRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(staff(), route), isFalse);
        });
      }
    });
  });

  // =========================================================================
  // DYNAMIC CHAT ROUTES
  // =========================================================================

  group('Dynamic chat routes', () {
    const chatDetailRoutes = [
      '/chat/room123',
      '/chat/abc-def-456',
      '/chat/xyzroom',
    ];

    group('all roles can access detail views', () {
      for (final route in chatDetailRoutes) {
        test('$route - platformOwner', () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });

        test('$route - superAdmin', () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });

        test('$route - managerAdmin', () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });

        test('$route - staff', () {
          expect(ps.canAccessRoute(staff(), route), isTrue);
        });
      }
    });

    group('chat room info routes accessible to all active users', () {
      const roomInfoRoutes = [
        '/chat/room123/info',
        '/chat/abc-def-456/info',
      ];

      for (final route in roomInfoRoutes) {
        test('$route - platformOwner', () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });

        test('$route - superAdmin', () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });

        test('$route - managerAdmin', () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });

        test('$route - staff', () {
          expect(ps.canAccessRoute(staff(), route), isTrue);
        });
      }
    });
  });

  // =========================================================================
  // DYNAMIC DOCUMENT ROUTES
  // =========================================================================

  group('Dynamic document routes', () {
    const documentDetailRoutes = [
      '/documents/doc123',
      '/documents/abc-def-789',
      '/documents/mydoc',
    ];

    group('all roles can access detail views', () {
      for (final route in documentDetailRoutes) {
        test('$route - platformOwner', () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });

        test('$route - superAdmin', () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });

        test('$route - managerAdmin', () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });

        test('$route - staff', () {
          expect(ps.canAccessRoute(staff(), route), isTrue);
        });
      }
    });

    test('upload route does not match /documents/upload for detail access', () {
      // /documents/upload is a static route, not a detail route
      // It should be handled by the content creation routes
      expect(ps.canAccessRoute(staff(), '/documents/upload'), isFalse);
    });
  });

  // =========================================================================
  // DYNAMIC ANNOUNCEMENT ROUTES
  // =========================================================================

  group('Dynamic announcement routes', () {
    const announcementDetailRoutes = [
      '/announcements/ann123',
      '/announcements/abc-def-xyz',
      '/announcements/myannouncement',
    ];

    group('all roles can access detail views', () {
      for (final route in announcementDetailRoutes) {
        test('$route - platformOwner', () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });

        test('$route - superAdmin', () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });

        test('$route - managerAdmin', () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });

        test('$route - staff', () {
          expect(ps.canAccessRoute(staff(), route), isTrue);
        });
      }
    });

    group('announcement edit routes require managerAdmin+', () {
      const editRoutes = [
        '/announcements/ann123/edit',
        '/announcements/abc-def-xyz/edit',
      ];

      group('platformOwner can edit', () {
        for (final route in editRoutes) {
          test(route, () {
            expect(ps.canAccessRoute(platformOwner(), route), isTrue);
          });
        }
      });

      group('superAdmin can edit', () {
        for (final route in editRoutes) {
          test(route, () {
            expect(ps.canAccessRoute(superAdmin(), route), isTrue);
          });
        }
      });

      group('managerAdmin can edit', () {
        for (final route in editRoutes) {
          test(route, () {
            expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
          });
        }
      });

      group('staff cannot edit', () {
        for (final route in editRoutes) {
          test(route, () {
            expect(ps.canAccessRoute(staff(), route), isFalse);
          });
        }
      });
    });

    test('create route does not match /announcements/create for detail access', () {
      // /announcements/create is a static route, not a detail route
      expect(ps.canAccessRoute(staff(), '/announcements/create'), isFalse);
    });
  });

  // =========================================================================
  // DYNAMIC USER DETAIL ROUTES
  // =========================================================================

  group('Dynamic user detail routes', () {
    const userDetailRoutes = [
      '/settings/users/user123',
      '/settings/users/abc-def-xyz',
      '/settings/users/john',
    ];

    group('platformOwner can access', () {
      for (final route in userDetailRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(platformOwner(), route), isTrue);
        });
      }
    });

    group('superAdmin can access', () {
      for (final route in userDetailRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(superAdmin(), route), isTrue);
        });
      }
    });

    group('managerAdmin can access', () {
      for (final route in userDetailRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(managerAdmin(), route), isTrue);
        });
      }
    });

    group('staff cannot access', () {
      for (final route in userDetailRoutes) {
        test(route, () {
          expect(ps.canAccessRoute(staff(), route), isFalse);
        });
      }
    });
  });

  // =========================================================================
  // INACTIVE USER
  // =========================================================================

  group('Inactive users', () {
    final routes = [
      '/',
      '/chat',
      '/documents',
      '/announcements',
      '/settings',
      '/settings/profile',
      '/settings/notifications',
      '/settings/privacy',
      '/settings/users',
      '/settings/roles',
      '/settings/branding',
      '/settings/app-icon',
      '/settings/leagues',
      '/documents/upload',
      '/announcements/create',
      '/chat/room123',
      '/documents/doc123',
      '/announcements/ann123',
      '/announcements/ann123/edit',
      '/settings/users/user123',
    ];

    for (final route in routes) {
      test('inactive staff cannot access $route', () {
        expect(ps.canAccessRoute(inactiveUser(role: UserRole.staff), route),
            isFalse);
      });

      test('inactive managerAdmin cannot access $route', () {
        expect(
            ps.canAccessRoute(inactiveUser(role: UserRole.managerAdmin), route),
            isFalse);
      });

      test('inactive superAdmin cannot access $route', () {
        expect(ps.canAccessRoute(inactiveUser(role: UserRole.superAdmin), route),
            isFalse);
      });

      test('inactive platformOwner cannot access $route', () {
        expect(ps.canAccessRoute(inactiveUser(role: UserRole.platformOwner), route),
            isFalse);
      });
    }
  });

  // =========================================================================
  // UNKNOWN ROUTES
  // =========================================================================

  group('Unknown routes', () {
    // Note: /chat/room123/unknown and /documents/doc123/unknown are NOT
    // included here because canAccessRoute uses startsWith('/chat/') and
    // startsWith('/documents/') which match these paths by design — the
    // router itself handles 404s for invalid sub-paths.
    const unknownRoutes = [
      '/admin',
      '/foobar',
      '/unknown',
      '/settings/unknown',
      '/random-path',
      '/admin/users',
      '/api/something',
    ];

    group('all roles denied access to unknown routes', () {
      for (final route in unknownRoutes) {
        test('$route - platformOwner', () {
          expect(ps.canAccessRoute(platformOwner(), route), isFalse);
        });

        test('$route - superAdmin', () {
          expect(ps.canAccessRoute(superAdmin(), route), isFalse);
        });

        test('$route - managerAdmin', () {
          expect(ps.canAccessRoute(managerAdmin(), route), isFalse);
        });

        test('$route - staff', () {
          expect(ps.canAccessRoute(staff(), route), isFalse);
        });
      }
    });
  });

  // =========================================================================
  // EDGE CASES
  // =========================================================================

  group('Edge cases', () {
    test('empty path returns false', () {
      expect(ps.canAccessRoute(staff(), ''), isFalse);
    });

    test('double slashes still match via startsWith', () {
      // /chat//room123 matches startsWith('/chat/') — GoRouter normalises
      // paths before they reach canAccessRoute in practice.
      expect(ps.canAccessRoute(staff(), '/chat//room123'), isTrue);
    });

    test('path with query params still matches via startsWith', () {
      // GoRouter strips query params before passing to redirect, so
      // canAccessRoute doesn't need to handle them.
      expect(ps.canAccessRoute(staff(), '/chat/room123?foo=bar'), isTrue);
    });

    test('path with fragment still matches via startsWith', () {
      // Same — GoRouter strips fragments.
      expect(ps.canAccessRoute(staff(), '/chat/room123#section'), isTrue);
    });

    test('case sensitivity - /Chat is not equivalent to /chat', () {
      expect(ps.canAccessRoute(staff(), '/Chat'), isFalse);
    });

    test('paths must be exact prefix matches for dynamic routes', () {
      // /chatroom123 should not match /chat/:roomId
      expect(ps.canAccessRoute(staff(), '/chatroom123'), isFalse);
    });

    test('/ route is distinct from empty string', () {
      expect(ps.canAccessRoute(staff(), '/'), isTrue);
      expect(ps.canAccessRoute(staff(), ''), isFalse);
    });
  });

  // =========================================================================
  // ROLE HIERARCHY VERIFICATION
  // =========================================================================

  group('Role hierarchy across all routes', () {
    // Verify that every route accessible to a lower role is also
    // accessible to all higher roles.

    const allRoutes = [
      '/',
      '/chat',
      '/documents',
      '/announcements',
      '/settings',
      '/settings/profile',
      '/settings/notifications',
      '/settings/privacy',
      '/settings/users',
      '/settings/roles',
      '/settings/branding',
      '/settings/app-icon',
      '/settings/leagues',
      '/documents/upload',
      '/announcements/create',
      '/chat/room123',
      '/documents/doc123',
      '/announcements/ann123',
      '/announcements/ann123/edit',
      '/settings/users/user123',
    ];

    for (final route in allRoutes) {
      test('$route - hierarchy is respected', () {
        final staffAccess = ps.canAccessRoute(staff(), route);
        final managerAccess = ps.canAccessRoute(managerAdmin(), route);
        final adminAccess = ps.canAccessRoute(superAdmin(), route);
        final ownerAccess = ps.canAccessRoute(platformOwner(), route);

        // If staff can access, manager should too
        if (staffAccess) {
          expect(managerAccess, isTrue,
              reason: 'managerAdmin should have at least staff access to $route');
        }

        // If manager can access, admin should too
        if (managerAccess) {
          expect(adminAccess, isTrue,
              reason: 'superAdmin should have at least managerAdmin access to $route');
        }

        // If admin can access, owner should too
        if (adminAccess) {
          expect(ownerAccess, isTrue,
              reason: 'platformOwner should have at least superAdmin access to $route');
        }
      });
    }
  });

  // =========================================================================
  // COMPREHENSIVE ROUTE MATRIX
  // =========================================================================

  group('Comprehensive route access matrix', () {
    test('staff can access exactly these routes', () {
      final staffAccessible = [
        '/',
        '/chat',
        '/documents',
        '/announcements',
        '/settings',
        '/settings/profile',
        '/settings/notifications',
        '/settings/privacy',
        '/chat/room123',
        '/documents/doc123',
        '/announcements/ann123',
      ];

      final staffDenied = [
        '/settings/users',
        '/settings/roles',
        '/settings/branding',
        '/settings/app-icon',
        '/settings/leagues',
        '/documents/upload',
        '/announcements/create',
        '/announcements/ann123/edit',
        '/settings/users/user123',
      ];

      for (final route in staffAccessible) {
        expect(ps.canAccessRoute(staff(), route), isTrue,
            reason: 'staff should access $route');
      }

      for (final route in staffDenied) {
        expect(ps.canAccessRoute(staff(), route), isFalse,
            reason: 'staff should NOT access $route');
      }
    });

    test('managerAdmin can access exactly these routes', () {
      final managerAccessible = [
        '/',
        '/chat',
        '/documents',
        '/announcements',
        '/settings',
        '/settings/profile',
        '/settings/notifications',
        '/settings/privacy',
        '/settings/users',
        '/documents/upload',
        '/announcements/create',
        '/chat/room123',
        '/documents/doc123',
        '/announcements/ann123',
        '/announcements/ann123/edit',
        '/settings/users/user123',
      ];

      final managerDenied = [
        '/settings/roles',
        '/settings/branding',
        '/settings/app-icon',
        '/settings/leagues',
      ];

      for (final route in managerAccessible) {
        expect(ps.canAccessRoute(managerAdmin(), route), isTrue,
            reason: 'managerAdmin should access $route');
      }

      for (final route in managerDenied) {
        expect(ps.canAccessRoute(managerAdmin(), route), isFalse,
            reason: 'managerAdmin should NOT access $route');
      }
    });

    test('superAdmin can access all defined routes except login/org creation', () {
      final adminAccessible = [
        '/',
        '/chat',
        '/documents',
        '/announcements',
        '/settings',
        '/settings/profile',
        '/settings/notifications',
        '/settings/privacy',
        '/settings/users',
        '/settings/roles',
        '/settings/branding',
        '/settings/app-icon',
        '/settings/leagues',
        '/documents/upload',
        '/announcements/create',
        '/chat/room123',
        '/documents/doc123',
        '/announcements/ann123',
        '/announcements/ann123/edit',
        '/settings/users/user123',
      ];

      for (final route in adminAccessible) {
        expect(ps.canAccessRoute(superAdmin(), route), isTrue,
            reason: 'superAdmin should access $route');
      }
    });

    test('platformOwner can access all defined routes except login/org creation', () {
      final ownerAccessible = [
        '/',
        '/chat',
        '/documents',
        '/announcements',
        '/settings',
        '/settings/profile',
        '/settings/notifications',
        '/settings/privacy',
        '/settings/users',
        '/settings/roles',
        '/settings/branding',
        '/settings/app-icon',
        '/settings/leagues',
        '/documents/upload',
        '/announcements/create',
        '/chat/room123',
        '/documents/doc123',
        '/announcements/ann123',
        '/announcements/ann123/edit',
        '/settings/users/user123',
      ];

      for (final route in ownerAccessible) {
        expect(ps.canAccessRoute(platformOwner(), route), isTrue,
            reason: 'platformOwner should access $route');
      }
    });
  });
}
