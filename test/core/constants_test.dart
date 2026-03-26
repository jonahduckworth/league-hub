import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/core/constants.dart';

void main() {
  group('AppConstants', () {
    group('App metadata', () {
      test('appName is League Hub', () {
        expect(AppConstants.appName, 'League Hub');
      });

      test('appVersion is set', () {
        expect(AppConstants.appVersion, isNotEmpty);
      });
    });

    group('Collection names', () {
      test('usersCollection is "users"', () {
        expect(AppConstants.usersCollection, 'users');
      });

      test('orgsCollection is "organizations"', () {
        expect(AppConstants.orgsCollection, 'organizations');
      });

      test('leaguesCollection is "leagues"', () {
        expect(AppConstants.leaguesCollection, 'leagues');
      });

      test('hubsCollection is "hubs"', () {
        expect(AppConstants.hubsCollection, 'hubs');
      });

      test('teamsCollection is "teams"', () {
        expect(AppConstants.teamsCollection, 'teams');
      });

      test('chatRoomsCollection is "chatRooms"', () {
        expect(AppConstants.chatRoomsCollection, 'chatRooms');
      });

      test('messagesCollection is "messages"', () {
        expect(AppConstants.messagesCollection, 'messages');
      });

      test('documentsCollection is "documents"', () {
        expect(AppConstants.documentsCollection, 'documents');
      });

      test('announcementsCollection is "announcements"', () {
        expect(AppConstants.announcementsCollection, 'announcements');
      });

      test('all collection names are non-empty strings', () {
        final collections = [
          AppConstants.usersCollection,
          AppConstants.orgsCollection,
          AppConstants.leaguesCollection,
          AppConstants.hubsCollection,
          AppConstants.teamsCollection,
          AppConstants.chatRoomsCollection,
          AppConstants.messagesCollection,
          AppConstants.documentsCollection,
          AppConstants.announcementsCollection,
        ];
        for (final c in collections) {
          expect(c, isA<String>());
          expect(c, isNotEmpty);
        }
      });
    });

    group('Route constants', () {
      test('loginRoute is /login', () {
        expect(AppConstants.loginRoute, '/login');
      });

      test('dashboardRoute is /', () {
        expect(AppConstants.dashboardRoute, '/');
      });

      test('chatRoute is /chat', () {
        expect(AppConstants.chatRoute, '/chat');
      });

      test('chatConversationRoute has roomId param', () {
        expect(AppConstants.chatConversationRoute, '/chat/:roomId');
      });

      test('documentsRoute is /documents', () {
        expect(AppConstants.documentsRoute, '/documents');
      });

      test('announcementsRoute is /announcements', () {
        expect(AppConstants.announcementsRoute, '/announcements');
      });

      test('settingsRoute is /settings', () {
        expect(AppConstants.settingsRoute, '/settings');
      });

      test('all routes start with /', () {
        final routes = [
          AppConstants.loginRoute,
          AppConstants.dashboardRoute,
          AppConstants.chatRoute,
          AppConstants.chatConversationRoute,
          AppConstants.documentsRoute,
          AppConstants.announcementsRoute,
          AppConstants.settingsRoute,
        ];
        for (final r in routes) {
          expect(r.startsWith('/'), isTrue, reason: '$r should start with /');
        }
      });
    });
  });
}
