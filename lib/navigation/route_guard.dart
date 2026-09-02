import '../models/app_user.dart';
import '../services/permission_service.dart';

const _permissionService = PermissionService();

String? routeRedirectForAuthState({
  required bool isLoggedIn,
  required String location,
  required AppUser? user,
  String? requestedAfterLogin,
}) {
  final appLocation = canonicalAppLinkLocation(location);
  if (appLocation != location) return appLocation;

  final isOnLogin = location == '/login';
  final isOnCreateLeague =
      location == '/create-league' || location == '/create-org';
  final isOnAcceptInvite = location == '/accept-invite';
  final isOnAuthRoute = isOnLogin || isOnAcceptInvite;

  // League onboarding is intentionally managed by League Hub. Keep the
  // retired self-service URLs closed even when reached from an old link.
  if (isOnCreateLeague) return isLoggedIn ? '/' : '/login';

  if (!isLoggedIn && !isOnAuthRoute) {
    return Uri(
      path: '/login',
      queryParameters: {'redirect': location},
    ).toString();
  }
  if (isLoggedIn && isOnLogin) {
    if (user == null) return null;
    return safePostLoginLocation(requestedAfterLogin) ?? '/';
  }
  if (isOnAuthRoute) return null;

  if (user == null) {
    return location == '/' ? null : '/';
  }

  if (!_permissionService.canAccessRoute(user, location)) {
    return '/unauthorized';
  }

  return null;
}

String canonicalAppLinkLocation(String location) {
  const prefix = '/app/announcements/';
  if (!location.startsWith(prefix)) return location;
  final announcementId = location.substring(prefix.length);
  if (announcementId.isEmpty || announcementId.contains('/')) return location;
  return '/announcements/$announcementId';
}

String? safePostLoginLocation(String? value) {
  if (value == null || !value.startsWith('/') || value.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path == '/login') return null;
  return value;
}
