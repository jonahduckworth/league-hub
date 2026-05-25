import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/hub.dart';
import '../models/league.dart';
import 'announcement_navigation_source.dart';
import '../services/permission_service.dart';
import '../core/constants.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/new_chat_screen.dart';
import '../screens/policy_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/org_creation_screen.dart';
import '../screens/accept_invitation_screen.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/create_announcement_screen.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/upload_policy_screen.dart';
import '../screens/policy_detail_screen.dart';
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
const _shellTransitionDuration = Duration(milliseconds: 220);
const _shellTransitionSlideFactor = 0.035;

double _shellTransitionProgress(double value) {
  return Curves.easeOutCubic.transform(value);
}

({double opacity, double offsetFactor}) _shellTransitionFrame({
  required double progress,
  required bool isCurrent,
}) {
  final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
  return (
    opacity: isCurrent ? clampedProgress : 1 - clampedProgress,
    offsetFactor: isCurrent ? 1 - clampedProgress : -clampedProgress,
  );
}

Widget _shellTransitionMotion({
  required BuildContext context,
  required Widget child,
  required double progress,
  required double direction,
  required bool isCurrent,
}) {
  final frame = _shellTransitionFrame(
    progress: progress,
    isCurrent: isCurrent,
  );
  return Opacity(
    opacity: frame.opacity,
    child: Transform.translate(
      offset: Offset(
        direction *
            frame.offsetFactor *
            MediaQuery.sizeOf(context).width *
            _shellTransitionSlideFactor,
        0,
      ),
      child: child,
    ),
  );
}

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
              path: '/policy',
              builder: (context, state) => const PolicyScreen(),
              routes: [
                GoRoute(
                  path: 'upload',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const UploadPolicyScreen(),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    PolicyDetailScreen(
                      policyId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/announcements',
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const AnnouncementsScreen(),
                animatePrimary: false,
              ),
              routes: [
                GoRoute(
                  path: 'create',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const CreateAnnouncementScreen(),
                  ),
                ),
                GoRoute(
                  path: ':id/edit',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    CreateAnnouncementScreen(
                      announcementId: state.pathParameters['id']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) {
                    final source = state.extra;
                    final isDashboardCard =
                        source == AnnouncementNavigationSource.dashboardCard;
                    return _shellTransitionPage(
                      state,
                      AnnouncementDetailScreen(
                        announcementId: state.pathParameters['id']!,
                        returnToDashboard: isDashboardCard,
                      ),
                      animatePrimary: !isDashboardCard,
                    );
                  },
                ),
              ],
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
                GoRoute(
                  path: 'leagues/new',
                  builder: (context, state) => const AddLeagueScreen(),
                ),
                GoRoute(
                  path: 'leagues/:leagueId/edit',
                  builder: (context, state) => EditLeagueScreen(
                    leagueId: state.pathParameters['leagueId']!,
                    initialLeague:
                        state.extra is League ? state.extra! as League : null,
                  ),
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/new',
                  builder: (context, state) => AddHubScreen(
                    leagueId: state.pathParameters['leagueId']!,
                    initialLeague:
                        state.extra is League ? state.extra! as League : null,
                  ),
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/:hubId/edit',
                  builder: (context, state) {
                    final extra = state.extra;
                    final league = extra is ({League league, Hub hub})
                        ? extra.league
                        : null;
                    final hub =
                        extra is ({League league, Hub hub}) ? extra.hub : null;
                    return EditHubScreen(
                      leagueId: state.pathParameters['leagueId']!,
                      hubId: state.pathParameters['hubId']!,
                      initialLeague: league,
                      initialHub: hub,
                    );
                  },
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/:hubId/teams/new',
                  builder: (context, state) {
                    final extra = state.extra;
                    final league = extra is ({League league, Hub hub})
                        ? extra.league
                        : null;
                    final hub =
                        extra is ({League league, Hub hub}) ? extra.hub : null;
                    return AddTeamScreen(
                      leagueId: state.pathParameters['leagueId']!,
                      hubId: state.pathParameters['hubId']!,
                      initialLeague: league,
                      initialHub: hub,
                    );
                  },
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
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) => EditTeamScreen(
            teamId: state.pathParameters['teamId']!,
            leagueId: state.uri.queryParameters['leagueId'] ?? '',
            hubId: state.uri.queryParameters['hubId'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/chat/new',
      builder: (context, state) => const NewChatScreen(),
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
  ],
);

Page<void> _shellTransitionPage(
  GoRouterState state,
  Widget child, {
  bool animatePrimary = true,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _shellTransitionDuration,
    reverseTransitionDuration: _shellTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, _) {
          final width = MediaQuery.sizeOf(context).width;
          var opacity = 1.0;
          var dx = 0.0;

          void applyMotion({
            required double progress,
            required double direction,
            required bool isCurrent,
          }) {
            final frame = _shellTransitionFrame(
              progress: progress,
              isCurrent: isCurrent,
            );
            opacity *= frame.opacity;
            dx += direction *
                frame.offsetFactor *
                width *
                _shellTransitionSlideFactor;
          }

          if (animatePrimary) {
            if (animation.status == AnimationStatus.forward ||
                animation.status == AnimationStatus.dismissed) {
              applyMotion(
                progress: _shellTransitionProgress(animation.value),
                direction: 1,
                isCurrent: true,
              );
            } else if (animation.status == AnimationStatus.reverse) {
              applyMotion(
                progress: _shellTransitionProgress(1 - animation.value),
                direction: -1,
                isCurrent: false,
              );
            }
          }

          if (secondaryAnimation.status == AnimationStatus.forward ||
              secondaryAnimation.status == AnimationStatus.completed) {
            applyMotion(
              progress: _shellTransitionProgress(secondaryAnimation.value),
              direction: 1,
              isCurrent: false,
            );
          } else if (secondaryAnimation.status == AnimationStatus.reverse) {
            applyMotion(
              progress: _shellTransitionProgress(1 - secondaryAnimation.value),
              direction: -1,
              isCurrent: true,
            );
          }

          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            ),
          );
        },
        child: child,
      );
    },
  );
}

class _MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const _MainScaffold({required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
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
      duration: _shellTransitionDuration,
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
        final progress = _shellTransitionProgress(_controller.value);
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

            return _BranchStage(
              isInteractive: isCurrent,
              isVisible: true,
              child: _shellTransitionMotion(
                context: context,
                child: widget.children[index],
                progress: progress,
                direction: direction,
                isCurrent: isCurrent,
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
