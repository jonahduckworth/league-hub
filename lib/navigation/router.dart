import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../services/permission_service.dart';
import '../core/constants.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/org_creation_screen.dart';
import '../screens/accept_invitation_screen.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/create_announcement_screen.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/upload_document_screen.dart';
import '../screens/document_detail_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/roles_permissions_screen.dart';
import '../screens/settings/branding_screen.dart';
import '../screens/settings/app_icon_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/privacy_security_screen.dart';
import '../screens/settings/chat_room_info_screen.dart';
import '../screens/unauthorized_screen.dart';
import '../widgets/bottom_nav_bar.dart';

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
}

final _authNotifier = _AuthNotifier();

/// Cache of the current AppUser for route-level permission checks.
/// Updated on each redirect. This avoids an async Firestore lookup in the
/// synchronous redirect callback by using a fire-and-forget pattern: the
/// first load redirects to '/' which triggers a refresh.
AppUser? _cachedAppUser;

const _permissionService = PermissionService();

/// Call this from the app's auth state listener (or splash screen) to prime
/// the user cache before navigation begins.
Future<void> primeRouterUser() async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    _cachedAppUser = null;
    return;
  }
  final doc = await FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(firebaseUser.uid)
      .get();
  if (doc.exists) {
    _cachedAppUser = AppUser.fromJson({'id': doc.id, ...doc.data()!});
  }
}

/// Clears the cached user on sign-out.
void clearRouterUser() {
  _cachedAppUser = null;
}

final router = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final location = state.matchedLocation;
    final isOnLogin = location == '/login';
    final isOnCreateOrg = location == '/create-org';
    final isOnAcceptInvite = location == '/accept-invite';

    // --- Authentication gate ---
    if (!isLoggedIn && !isOnLogin && !isOnCreateOrg && !isOnAcceptInvite) {
      return '/login';
    }
    if (isLoggedIn && isOnLogin) return '/';

    // --- Role-based gate ---
    // Skip permission check for auth / onboarding routes.
    if (isOnLogin || isOnCreateOrg || isOnAcceptInvite) return null;

    final user = _cachedAppUser;
    if (user == null) {
      // User doc hasn't loaded yet — let them through to '/' which will
      // trigger a provider load and re-evaluate on the next navigation.
      return null;
    }

    if (!_permissionService.canAccessRoute(user, location)) {
      return '/unauthorized';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/create-org',
      builder: (context, state) => const OrgCreationScreen(),
    ),
    GoRoute(
      path: '/accept-invite',
      builder: (context, state) => const AcceptInvitationScreen(),
    ),
    GoRoute(
      path: '/unauthorized',
      builder: (context, state) => const UnauthorizedScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          _MainScaffold(location: state.uri.toString(), child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/documents',
          builder: (context, state) => const DocumentsScreen(),
        ),
        GoRoute(
          path: '/announcements',
          builder: (context, state) => const AnnouncementsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/settings/users',
          builder: (context, state) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/settings/users/:userId',
          builder: (context, state) => UserDetailScreen(
            userId: state.pathParameters['userId']!,
          ),
        ),
        GoRoute(
          path: '/settings/profile',
          builder: (context, state) => const EditProfileScreen(),
        ),
        GoRoute(
          path: '/settings/roles',
          builder: (context, state) => const RolesPermissionsScreen(),
        ),
        GoRoute(
          path: '/settings/branding',
          builder: (context, state) => const BrandingScreen(),
        ),
        GoRoute(
          path: '/settings/app-icon',
          builder: (context, state) => const AppIconScreen(),
        ),
        GoRoute(
          path: '/settings/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/settings/privacy',
          builder: (context, state) => const PrivacySecurityScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/chat/:roomId',
      builder: (context, state) => ChatConversationScreen(
        roomId: state.pathParameters['roomId']!,
      ),
    ),
    GoRoute(
      path: '/chat/:roomId/info',
      builder: (context, state) => ChatRoomInfoScreen(
        roomId: state.pathParameters['roomId']!,
      ),
    ),
    // Document routes — outside ShellRoute (no bottom nav)
    GoRoute(
      path: '/documents/upload',
      builder: (context, state) => const UploadDocumentScreen(),
    ),
    GoRoute(
      path: '/documents/:id',
      builder: (context, state) => DocumentDetailScreen(
        docId: state.pathParameters['id']!,
      ),
    ),
    // Announcement routes — outside ShellRoute (no bottom nav)
    GoRoute(
      path: '/announcements/create',
      builder: (context, state) => const CreateAnnouncementScreen(),
    ),
    GoRoute(
      path: '/announcements/:id/edit',
      builder: (context, state) => CreateAnnouncementScreen(
        announcementId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/announcements/:id',
      builder: (context, state) => AnnouncementDetailScreen(
        announcementId: state.pathParameters['id']!,
      ),
    ),
  ],
);

class _MainScaffold extends StatelessWidget {
  final Widget child;
  final String location;

  const _MainScaffold({required this.child, required this.location});

  int get _currentIndex {
    if (location.startsWith('/chat')) return 1;
    if (location.startsWith('/documents')) return 2;
    if (location.startsWith('/announcements')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/chat');
            case 2:
              context.go('/documents');
            case 3:
              context.go('/announcements');
            case 4:
              context.go('/settings');
          }
        },
      ),
    );
  }
}
