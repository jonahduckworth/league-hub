import '../models/app_user.dart';
import '../services/permission_service.dart';

const _permissionService = PermissionService();

String? routeRedirectForAuthState({
  required bool isLoggedIn,
  required String location,
  required AppUser? user,
}) {
  final isOnLogin = location == '/login';
  final isOnCreateLeague =
      location == '/create-league' || location == '/create-org';
  final isOnAcceptInvite = location == '/accept-invite';
  final isOnAuthRoute = isOnLogin || isOnCreateLeague || isOnAcceptInvite;

  if (!isLoggedIn && !isOnAuthRoute) return '/login';
  if (isLoggedIn && isOnLogin) return '/';
  if (isOnAuthRoute) return null;

  if (user == null) {
    return location == '/' ? null : '/';
  }

  if (!_permissionService.canAccessRoute(user, location)) {
    return '/unauthorized';
  }

  return null;
}
