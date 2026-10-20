import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/navigation/route_guard.dart';

void main() {
  for (final role in UserRole.values) {
    AppUser member(bool active) => AppUser(
          id: 'member',
          email: 'member@example.com',
          displayName: 'Member',
          role: role,
          orgId: 'org',
          hubIds: ['hub'],
          teamIds: ['team'],
          createdAt: DateTime(2026),
          isActive: active,
        );

    test('active $role can navigate to Info Centre', () {
      expect(
        routeRedirectForAuthState(
          isLoggedIn: true,
          location: '/info',
          user: member(true),
        ),
        isNull,
      );
    });

    test('inactive $role cannot navigate to Info Centre', () {
      expect(
        routeRedirectForAuthState(
          isLoggedIn: true,
          location: '/info',
          user: member(false),
        ),
        '/unauthorized',
      );
    });
  }

  test('Info Centre requires sign-in and preserves its destination', () {
    final redirect = routeRedirectForAuthState(
      isLoggedIn: false,
      location: '/info',
      user: null,
    );
    expect(Uri.parse(redirect!).path, '/login');
    expect(Uri.parse(redirect).queryParameters['redirect'], '/info');
  });
}
