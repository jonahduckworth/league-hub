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
import '../screens/admin/manage_leagues_screen.dart';
import '../screens/admin/team_detail_screen.dart';
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
    StatefulShellRoute(
      builder: (context, state, navigationShell) =>
          _MainScaffold(navigationShell: navigationShell),
      navigatorContainerBuilder: (context, navigationShell, children) =>
          _AnimatedBranchContainer(
        currentIndex: navigationShell.currentIndex,
        children: children,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ChatListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              builder: (context, state) => const AnnouncementsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'users',
                  builder: (context, state) => const UserManagementScreen(),
                ),
                GoRoute(
                  path: 'users/:userId',
                  builder: (context, state) => UserDetailScreen(
                    userId: state.pathParameters['userId']!,
                  ),
                ),
                GoRoute(
                  path: 'profile',
                  builder: (context, state) => const EditProfileScreen(),
                ),
                GoRoute(
                  path: 'roles',
                  builder: (context, state) => const RolesPermissionsScreen(),
                ),
                GoRoute(
                  path: 'branding',
                  builder: (context, state) => const BrandingScreen(),
                ),
                GoRoute(
                  path: 'app-icon',
                  builder: (context, state) => const AppIconScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationsScreen(),
                ),
                GoRoute(
                  path: 'privacy',
                  builder: (context, state) => const PrivacySecurityScreen(),
                ),
                GoRoute(
                  path: 'leagues',
                  builder: (context, state) => const ManageLeaguesScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/teams/:teamId',
      builder: (context, state) => TeamDetailScreen(
        teamId: state.pathParameters['teamId']!,
        leagueId: state.uri.queryParameters['leagueId'] ?? '',
        hubId: state.uri.queryParameters['hubId'] ?? '',
      ),
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
  final StatefulNavigationShell navigationShell;

  const _MainScaffold({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: BottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class _AnimatedBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const _AnimatedBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  @override
  State<_AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<_AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant _AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        final direction = _branchDirection;
        final isAnimating = _controller.value < 1 && _previousIndex != null;

        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (index) {
            final isCurrent = index == widget.currentIndex;
            final isPrevious = index == _previousIndex;
            final shouldShow = isCurrent || (isAnimating && isPrevious);

            if (!shouldShow) {
              return _BranchStage(
                isInteractive: false,
                isVisible: false,
                child: widget.children[index],
              );
            }

            final opacity = isCurrent ? progress : 1 - progress;
            final offsetFactor = isCurrent ? 1 - progress : -progress;
            final offset = Offset(
              direction *
                  offsetFactor *
                  MediaQuery.sizeOf(context).width *
                  0.035,
              0,
            );

            return _BranchStage(
              isInteractive: isCurrent,
              isVisible: true,
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.translate(
                  offset: offset,
                  child: widget.children[index],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double get _branchDirection {
    if (_previousIndex == null) return 1;
    return widget.currentIndex >= _previousIndex! ? 1 : -1;
  }
}

class _BranchStage extends StatelessWidget {
  final bool isInteractive;
  final bool isVisible;
  final Widget child;

  const _BranchStage({
    required this.isInteractive,
    required this.isVisible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !isInteractive,
      child: TickerMode(
        enabled: isVisible,
        child: Offstage(
          offstage: !isVisible,
          child: child,
        ),
      ),
    );
  }
}
