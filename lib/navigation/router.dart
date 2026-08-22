import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/app_user.dart';
import '../models/hub.dart';
import '../models/league.dart';
import 'announcement_navigation_source.dart';
import 'chat_navigation_source.dart';
import 'route_guard.dart';
import 'route_motion.dart';
import 'shell_navigation.dart';
import '../core/constants.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/contact_profile_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/new_chat_screen.dart';
import '../screens/policy_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/accept_invitation_screen.dart';
import '../screens/admin/user_management_screen.dart';
import '../screens/admin/user_detail_screen.dart';
import '../screens/create_announcement_screen.dart';
import '../screens/announcement_detail_screen.dart';
import '../screens/upload_policy_screen.dart';
import '../screens/policy_detail_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/roles_permissions_screen.dart';
import '../screens/settings/app_icon_screen.dart';
import '../screens/settings/notifications_screen.dart';
import '../screens/settings/privacy_security_screen.dart';
import '../screens/settings/chat_room_info_screen.dart';
import '../screens/admin/manage_leagues_screen.dart';
import '../screens/admin/team_detail_screen.dart';
import '../screens/unauthorized_screen.dart';
import '../widgets/app_shell_scaffold.dart';
import '../widgets/app_icon_prompt_coordinator.dart';
import '../widgets/glass_bottom_nav.dart';
import '../core/design_system.dart';

class _AuthNotifier extends ChangeNotifier {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  _AuthNotifier() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen(_handleAuthChange);
  }

  void _handleAuthChange(User? firebaseUser) {
    _userSubscription?.cancel();
    _userSubscription = null;
    _cachedAppUser = null;
    notifyListeners();

    if (firebaseUser == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((doc) {
      _cachedAppUser =
          doc.exists ? AppUser.fromJson({'id': doc.id, ...doc.data()!}) : null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthNotifier();

/// Cache of the current AppUser for route-level permission checks.
/// Kept in sync by [_AuthNotifier] because GoRouter redirects are synchronous.
AppUser? _cachedAppUser;

const _shellTransitionDuration = AppMotion.route;
const _shellMoveCurve = AppMotion.enter;
const _shellFadeCurve = AppMotion.screenFadeCurve;
const _shellTransitionSlideFactor = 0.012;
const _shellRouteIncomingSlideFactor = 0.012;
const _shellRouteOutgoingSlideFactor = 0.004;
const _shellIncomingFadeStart = 0.0;
const _shellOutgoingFadeEnd = 1.0;
const _shellOutgoingPresenceEnd = 1.0;

const _shellUsesSharedAxis = true;

enum _ShellPageMotion {
  sharedAxisForward,
  sharedAxisBackward,
  scaleFade,
}

double _shellMoveProgress(double value) {
  return _shellMoveCurve.transform(value);
}

double _shellFadeProgress(double value) {
  return _shellFadeCurve.transform(value);
}

double _shellOutgoingFadeProgress(double progress) {
  return (progress / _shellOutgoingFadeEnd).clamp(0.0, 1.0).toDouble();
}

double _shellIncomingFadeProgress(double progress) {
  return ((progress - _shellIncomingFadeStart) / (1 - _shellIncomingFadeStart))
      .clamp(0.0, 1.0)
      .toDouble();
}

double _shellFadeOpacity({
  required double progress,
  required bool isCurrent,
}) {
  final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
  if (isCurrent) {
    return _shellIncomingFadeProgress(clampedProgress);
  }

  return ui.lerpDouble(1, 0, _shellOutgoingFadeProgress(clampedProgress))!;
}

double _shellRouteFadeOpacity({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required bool animatePrimary,
}) {
  if (secondaryAnimation.status == AnimationStatus.reverse) {
    return _shellIncomingFadeProgress(_shellFadeProgress(
      1 - secondaryAnimation.value,
    ));
  }

  if (secondaryAnimation.status == AnimationStatus.forward ||
      secondaryAnimation.status == AnimationStatus.completed) {
    return ui.lerpDouble(
      1,
      0,
      _shellOutgoingFadeProgress(_shellFadeProgress(
        secondaryAnimation.value,
      )),
    )!;
  }

  if (animatePrimary &&
      (animation.status == AnimationStatus.forward ||
          animation.status == AnimationStatus.dismissed)) {
    if (animation.status == AnimationStatus.dismissed) return 0;
    return _shellIncomingFadeProgress(_shellFadeProgress(
      animation.value,
    ));
  }

  if (animatePrimary && animation.status == AnimationStatus.reverse) {
    return ui.lerpDouble(
      1,
      0,
      _shellOutgoingFadeProgress(_shellFadeProgress(
        1 - animation.value,
      )),
    )!;
  }

  return 1;
}

bool _shellRouteIsOutgoing({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required bool animatePrimary,
}) {
  return secondaryAnimation.status == AnimationStatus.forward ||
      secondaryAnimation.status == AnimationStatus.completed ||
      (animatePrimary &&
          (animation.status == AnimationStatus.reverse ||
              animation.status == AnimationStatus.dismissed));
}

bool _shellRouteContentIsVisible({
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required bool animatePrimary,
}) {
  if (_shellRouteIsOutgoing(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    animatePrimary: animatePrimary,
  )) {
    return false;
  }
  if (animatePrimary && animation.status == AnimationStatus.dismissed) {
    return false;
  }
  return _shellRouteFadeOpacity(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        animatePrimary: animatePrimary,
      ) >
      0;
}

({double opacity, double offsetFactor, double scale}) _shellTransitionFrame({
  required double fadeProgress,
  required double moveProgress,
  required bool isCurrent,
}) {
  final clampedFade = fadeProgress.clamp(0.0, 1.0).toDouble();
  final clampedMove = moveProgress.clamp(0.0, 1.0).toDouble();
  final outgoingFade = _shellOutgoingFadeProgress(clampedFade);
  return (
    opacity: isCurrent ? clampedFade : ui.lerpDouble(1, 0, outgoingFade)!,
    offsetFactor: isCurrent ? 1 - clampedMove : -clampedMove,
    scale: 1,
  );
}

Widget _shellTransitionMotion({
  required BuildContext context,
  required Widget child,
  required double fadeProgress,
  required double moveProgress,
  required double direction,
  required bool isCurrent,
}) {
  final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  if (reduceMotion) {
    return Opacity(
      opacity: isCurrent ? 1 : 0,
      child: child,
    );
  }

  if (!_shellUsesSharedAxis) {
    return Opacity(
      opacity: _shellFadeOpacity(
        progress: fadeProgress,
        isCurrent: isCurrent,
      ),
      child: child,
    );
  }

  final frame = _shellTransitionFrame(
    fadeProgress: fadeProgress,
    moveProgress: moveProgress,
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
      child: Transform.scale(
        scale: frame.scale,
        child: child,
      ),
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
    return routeRedirectForAuthState(
      isLoggedIn: isLoggedIn,
      location: location,
      user: _cachedAppUser,
    );
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _shellTransitionPage(
        state,
        const LoginScreen(),
        motion: _ShellPageMotion.scaleFade,
      ),
    ),
    GoRoute(
      path: '/create-league',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/create-org',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/accept-invite',
      pageBuilder: (context, state) => _shellTransitionPage(
        state,
        const AcceptInvitationScreen(),
        motion: _ShellPageMotion.sharedAxisForward,
      ),
    ),
    GoRoute(
      path: '/unauthorized',
      pageBuilder: (context, state) => _shellTransitionPage(
        state,
        const UnauthorizedScreen(),
        motion: _ShellPageMotion.scaleFade,
      ),
    ),
    StatefulShellRoute(
      builder: (context, state, navigationShell) => _MainScaffold(
        navigationShell: navigationShell,
        location: state.uri.path,
      ),
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
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const ChatListScreen(includePinnedAnnouncements: true),
                animatePrimary: false,
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const NewChatScreen(),
                  ),
                ),
                GoRoute(
                  path: ':roomId',
                  pageBuilder: (context, state) {
                    final source = state.extra;
                    final isDashboardCard =
                        source == ChatNavigationSource.dashboardCard;
                    return _shellTransitionPage(
                      state,
                      ChatConversationScreen(
                        roomId: state.pathParameters['roomId']!,
                      ),
                      animatePrimary: !isDashboardCard,
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'info',
                      pageBuilder: (context, state) => _shellTransitionPage(
                        state,
                        ChatRoomInfoScreen(
                          roomId: state.pathParameters['roomId']!,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/policy',
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const PolicyScreen(),
                animatePrimary: false,
              ),
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
                AnnouncementsScreen(
                  returnToCommunication: state.extra ==
                      AnnouncementNavigationSource.communicationHub,
                ),
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
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const SettingsScreen(),
                animatePrimary: false,
              ),
              routes: [
                GoRoute(
                  path: 'users',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const UserManagementScreen(),
                  ),
                ),
                GoRoute(
                  path: 'users/invite',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const InviteUserScreen(),
                  ),
                ),
                GoRoute(
                  path: 'users/invitations',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const PendingInvitationsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'users/:userId',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    UserDetailScreen(
                      userId: state.pathParameters['userId']!,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'profile',
                  redirect: (context, state) => '/profile/edit',
                ),
                GoRoute(
                  path: 'roles',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const RolesPermissionsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'app-icon',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const AppIconScreen(),
                  ),
                ),
                GoRoute(
                  path: 'notifications',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const NotificationsScreen(),
                  ),
                ),
                GoRoute(
                  path: 'privacy',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const PrivacySecurityScreen(),
                  ),
                ),
                GoRoute(
                  path: 'leagues',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const ManageLeaguesScreen(),
                  ),
                ),
                GoRoute(
                  path: 'leagues/new',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const AddLeagueScreen(),
                  ),
                ),
                GoRoute(
                  path: 'leagues/:leagueId',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    LeagueDetailScreen(
                      leagueId: state.pathParameters['leagueId']!,
                      initialLeague:
                          state.extra is League ? state.extra! as League : null,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'leagues/:leagueId/edit',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    EditLeagueScreen(
                      leagueId: state.pathParameters['leagueId']!,
                      initialLeague:
                          state.extra is League ? state.extra! as League : null,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/new',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    AddHubScreen(
                      leagueId: state.pathParameters['leagueId']!,
                      initialLeague:
                          state.extra is League ? state.extra! as League : null,
                    ),
                  ),
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/:hubId/edit',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    final league = extra is ({League league, Hub hub})
                        ? extra.league
                        : null;
                    final hub =
                        extra is ({League league, Hub hub}) ? extra.hub : null;
                    return _shellTransitionPage(
                      state,
                      EditHubScreen(
                        leagueId: state.pathParameters['leagueId']!,
                        hubId: state.pathParameters['hubId']!,
                        initialLeague: league,
                        initialHub: hub,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/:hubId',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    final league = extra is ({League league, Hub hub})
                        ? extra.league
                        : null;
                    final hub =
                        extra is ({League league, Hub hub}) ? extra.hub : null;
                    return _shellTransitionPage(
                      state,
                      HubDetailScreen(
                        leagueId: state.pathParameters['leagueId']!,
                        hubId: state.pathParameters['hubId']!,
                        initialLeague: league,
                        initialHub: hub,
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'leagues/:leagueId/hubs/:hubId/teams/new',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    final league = extra is ({League league, Hub hub})
                        ? extra.league
                        : null;
                    final hub =
                        extra is ({League league, Hub hub}) ? extra.hub : null;
                    return _shellTransitionPage(
                      state,
                      AddTeamScreen(
                        leagueId: state.pathParameters['leagueId']!,
                        hubId: state.pathParameters['hubId']!,
                        initialLeague: league,
                        initialHub: hub,
                      ),
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
              path: '/profile',
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const ProfileScreen(),
                animatePrimary: false,
              ),
              routes: [
                GoRoute(
                  path: 'edit',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    const EditProfileScreen(),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/contacts',
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const ContactsScreen(),
                animatePrimary: false,
              ),
              routes: [
                GoRoute(
                  path: ':userId',
                  pageBuilder: (context, state) => _shellTransitionPage(
                    state,
                    ContactProfileScreen(
                      userId: state.pathParameters['userId']!,
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
              path: '/schedule',
              pageBuilder: (context, state) => _shellTransitionPage(
                state,
                const ScheduleScreen(),
                animatePrimary: false,
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/teams/:teamId',
      pageBuilder: (context, state) => _shellTransitionPage(
        state,
        TeamDetailScreen(
          teamId: state.pathParameters['teamId']!,
          leagueId: state.uri.queryParameters['leagueId'] ?? '',
          hubId: state.uri.queryParameters['hubId'] ?? '',
        ),
      ),
      routes: [
        GoRoute(
          path: 'edit',
          pageBuilder: (context, state) => _shellTransitionPage(
            state,
            EditTeamScreen(
              teamId: state.pathParameters['teamId']!,
              leagueId: state.uri.queryParameters['leagueId'] ?? '',
              hubId: state.uri.queryParameters['hubId'] ?? '',
            ),
          ),
        ),
      ],
    ),
  ],
);

Page<void> _shellTransitionPage(
  GoRouterState state,
  Widget child, {
  bool animatePrimary = true,
  _ShellPageMotion motion = _ShellPageMotion.sharedAxisForward,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _shellTransitionDuration,
    reverseTransitionDuration: AppMotion.routeReverse,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;

      if (!_shellUsesSharedAxis) {
        return _ShellRouteFadeTransition(
          transitionKey: state.pageKey,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          animatePrimary: animatePrimary,
          child: child,
        );
      }

      if (reduceMotion) {
        return _ShellRouteFadeTransition(
          transitionKey: state.pageKey,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          animatePrimary: animatePrimary,
          child: child,
        );
      }

      final incomingOffset = switch (motion) {
        _ShellPageMotion.sharedAxisForward => const Offset(
            _shellRouteIncomingSlideFactor,
            0,
          ),
        _ShellPageMotion.sharedAxisBackward => const Offset(
            -_shellRouteIncomingSlideFactor,
            0,
          ),
        _ShellPageMotion.scaleFade => Offset.zero,
      };
      final outgoingOffset = switch (motion) {
        _ShellPageMotion.sharedAxisForward => const Offset(
            -_shellRouteOutgoingSlideFactor,
            0,
          ),
        _ShellPageMotion.sharedAxisBackward => const Offset(
            _shellRouteOutgoingSlideFactor,
            0,
          ),
        _ShellPageMotion.scaleFade => Offset.zero,
      };

      return AnimatedBuilder(
        animation: Listenable.merge([animation, secondaryAnimation]),
        builder: (context, animatedChild) {
          final popLayer = appPopTransitionLayer(
            primaryStatus: animation.status,
            secondaryStatus: secondaryAnimation.status,
          );
          final isPopping = popLayer != AppPopTransitionLayer.none;
          final primaryFadeProgress =
              animatePrimary ? _shellFadeProgress(animation.value) : 1.0;
          final primaryMoveProgress =
              animatePrimary ? _shellMoveProgress(animation.value) : 1.0;
          final secondaryFadeProgress =
              _shellFadeProgress(secondaryAnimation.value);
          final secondaryMoveProgress =
              _shellMoveProgress(secondaryAnimation.value);
          final outgoingFadeProgress =
              _shellOutgoingFadeProgress(secondaryFadeProgress);
          final incomingDx =
              ui.lerpDouble(incomingOffset.dx, 0, primaryMoveProgress)!;
          final outgoingDx =
              ui.lerpDouble(0, outgoingOffset.dx, secondaryMoveProgress)!;
          final incomingOpacity = primaryFadeProgress;
          final outgoingOpacity = ui.lerpDouble(1, 0, outgoingFadeProgress)!;
          final transitionOpacity = isPopping
              ? appPopPageOpacity(
                  layer: popLayer,
                  primaryValue: animation.value,
                  disableAnimations: false,
                )
              : (incomingOpacity * outgoingOpacity).clamp(0, 1).toDouble();

          return AppShellRouteTransitionFrame(
            pageOpacity: transitionOpacity,
            contentOpacity: 1,
            showHeader: true,
            transitionKey: state.pageKey,
            translation:
                isPopping ? Offset.zero : Offset(incomingDx + outgoingDx, 0),
            scale: 1,
            child: animatedChild!,
          );
        },
        child: child,
      );
    },
  );
}

class _ShellRouteFadeTransition extends StatefulWidget {
  final Object transitionKey;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final bool animatePrimary;
  final Widget child;

  const _ShellRouteFadeTransition({
    required this.transitionKey,
    required this.animation,
    required this.secondaryAnimation,
    required this.animatePrimary,
    required this.child,
  });

  @override
  State<_ShellRouteFadeTransition> createState() =>
      _ShellRouteFadeTransitionState();
}

class _ShellRouteFadeTransitionState extends State<_ShellRouteFadeTransition> {
  int _contentTransitionSerial = 0;
  late bool _wasContentVisible;

  @override
  void initState() {
    super.initState();
    _wasContentVisible = _contentIsVisible;
    _addStatusListeners();
  }

  @override
  void didUpdateWidget(covariant _ShellRouteFadeTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.secondaryAnimation != widget.secondaryAnimation ||
        oldWidget.animatePrimary != widget.animatePrimary) {
      _removeStatusListeners(oldWidget);
      _wasContentVisible = _contentIsVisible;
      _addStatusListeners();
    }
  }

  @override
  void dispose() {
    _removeStatusListeners(widget);
    super.dispose();
  }

  bool get _contentIsVisible => _shellRouteContentIsVisible(
        animation: widget.animation,
        secondaryAnimation: widget.secondaryAnimation,
        animatePrimary: widget.animatePrimary,
      );

  void _addStatusListeners() {
    widget.animation.addStatusListener(_handleStatusChange);
    widget.secondaryAnimation.addStatusListener(_handleStatusChange);
    widget.animation.addListener(_handleAnimationTick);
    widget.secondaryAnimation.addListener(_handleAnimationTick);
  }

  void _removeStatusListeners(_ShellRouteFadeTransition source) {
    source.animation.removeStatusListener(_handleStatusChange);
    source.secondaryAnimation.removeStatusListener(_handleStatusChange);
    source.animation.removeListener(_handleAnimationTick);
    source.secondaryAnimation.removeListener(_handleAnimationTick);
  }

  void _handleStatusChange(AnimationStatus _) {
    _handleContentVisibilityChange();
  }

  void _handleAnimationTick() {
    _handleContentVisibilityChange();
  }

  void _handleContentVisibilityChange() {
    final isContentVisible = _contentIsVisible;
    if (isContentVisible && !_wasContentVisible && mounted) {
      setState(() {
        _contentTransitionSerial += 1;
      });
    }
    _wasContentVisible = isContentVisible;
  }

  @override
  Widget build(BuildContext context) {
    final parentTransitionKey =
        AppShellContentFadeScope.maybeTransitionKeyOf(context);

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.animation,
        widget.secondaryAnimation,
      ]),
      builder: (context, animatedChild) {
        final reduceMotion =
            MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        final outgoing = _shellRouteIsOutgoing(
          animation: widget.animation,
          secondaryAnimation: widget.secondaryAnimation,
          animatePrimary: widget.animatePrimary,
        );
        final opacity = reduceMotion
            ? (outgoing ? 0.0 : 1.0)
            : _shellRouteFadeOpacity(
                animation: widget.animation,
                secondaryAnimation: widget.secondaryAnimation,
                animatePrimary: widget.animatePrimary,
              );
        final isRemoved = opacity == 0;

        return IgnorePointer(
          ignoring: outgoing,
          child: Offstage(
            offstage: outgoing && isRemoved,
            child: AppShellRouteVisualScope(
              contentOpacity: opacity,
              showHeader: !outgoing,
              child: AppShellContentFadeScope(
                transitionKey: Object.hash(
                  parentTransitionKey,
                  widget.transitionKey,
                  _contentTransitionSerial,
                ),
                child: animatedChild!,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  final String location;

  const _MainScaffold({
    required this.navigationShell,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final showBottomNavigation = shouldShowShellBottomNavigation(location);
    final quickDestinationConfig =
        shellQuickDestinationConfigForLocation(location);
    final returnHomeOnBack = quickDestinationConfig != null &&
        location == quickDestinationConfig.route;

    return AppIconPromptCoordinator(
      child: AppShellNavigationScope(
        bottomPadding: showBottomNavigation
            ? leagueHubGlassBottomNavBarHeight + appShellBottomNavSpacing
            : 0,
        child: PopScope(
          canPop: !returnHomeOnBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && returnHomeOnBack) {
              context.go('/');
            }
          },
          child: Scaffold(
            extendBody: true,
            body: navigationShell,
            bottomNavigationBar: showBottomNavigation
                ? LeagueHubGlassBottomNav(
                    currentIndex: _bottomNavIndex,
                    onTap: (index) => _handleBottomNavTap(context, index),
                    overrideLastItem: quickDestinationConfig == null
                        ? null
                        : GlassNavBarItem(
                            icon: quickDestinationConfig.icon,
                            activeIcon: quickDestinationConfig.activeIcon,
                            label: quickDestinationConfig.label,
                            iconSize: quickDestinationConfig.iconSize,
                          ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  int get _bottomNavIndex {
    return shellBottomNavIndexFor(
      branchIndex: navigationShell.currentIndex,
      location: location,
    );
  }

  void _handleBottomNavTap(BuildContext context, int index) {
    final quickDestinationConfig =
        shellQuickDestinationConfigForLocation(location);
    if (index == 3 && quickDestinationConfig != null) {
      if (location == quickDestinationConfig.route) return;
      context.go(quickDestinationConfig.route);
      return;
    }

    final branchIndex = switch (index) {
      0 => 0,
      1 => 7,
      2 => 6,
      3 => 5,
      _ => 0,
    };
    navigationShell.goBranch(
      branchIndex,
      initialLocation: navigationShell.currentIndex == branchIndex,
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
  int _contentTransitionSerial = 0;

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
      _contentTransitionSerial += 1;
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
        final fadeProgress = _shellFadeProgress(_controller.value);
        final moveProgress = _shellMoveProgress(_controller.value);
        final direction = _branchDirection;
        final isAnimating = _controller.value < 1 && _previousIndex != null;
        final outgoingPresenceEnd = _shellUsesSharedAxis
            ? _shellOutgoingPresenceEnd
            : _shellOutgoingFadeEnd;
        final showPrevious = isAnimating && fadeProgress < outgoingPresenceEnd;

        Widget buildStage(int index) {
          final isCurrent = index == widget.currentIndex;
          final child = isCurrent
              ? AppShellContentFadeScope(
                  transitionKey: Object.hash(index, _contentTransitionSerial),
                  child: widget.children[index],
                )
              : widget.children[index];
          final stageChild = _shellUsesSharedAxis
              ? _shellTransitionMotion(
                  context: context,
                  child: child,
                  fadeProgress: fadeProgress,
                  moveProgress: moveProgress,
                  direction: direction,
                  isCurrent: isCurrent,
                )
              : AppShellRouteVisualScope(
                  contentOpacity: _shellFadeOpacity(
                    progress: fadeProgress,
                    isCurrent: isCurrent,
                  ),
                  showHeader: isCurrent,
                  child: child,
                );

          return _BranchStage(
            isInteractive: isCurrent,
            isVisible: true,
            child: stageChild,
          );
        }

        final hiddenStages = <Widget>[
          for (var index = 0; index < widget.children.length; index++)
            if (index != widget.currentIndex &&
                !(showPrevious && index == _previousIndex))
              _BranchStage(
                isInteractive: false,
                isVisible: false,
                child: widget.children[index],
              ),
        ];

        return Stack(
          fit: StackFit.expand,
          children: [
            ...hiddenStages,
            if (showPrevious && _previousIndex != widget.currentIndex)
              buildStage(_previousIndex!),
            buildStage(widget.currentIndex),
          ],
        );
      },
    );
  }

  double get _branchDirection {
    if (_previousIndex == null) return 1;
    final slotDelta = shellBranchNavSlot(widget.currentIndex) -
        shellBranchNavSlot(_previousIndex!);
    if (slotDelta > 0) return 1;
    if (slotDelta < 0) return -1;
    return 0;
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
