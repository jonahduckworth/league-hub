class AppConstants {
  static const String appName = 'League Hub';
  static const String appVersion = '1.0.0';

  // Collections
  static const String usersCollection = 'users';
  static const String orgsCollection = 'organizations';
  static const String leaguesCollection = 'leagues';
  static const String hubsCollection = 'hubs';
  static const String teamsCollection = 'teams';
  static const String chatRoomsCollection = 'chatRooms';
  static const String messagesCollection = 'messages';
  static const String documentsCollection = 'documents';
  static const String announcementsCollection = 'announcements';

  // Routes
  static const String loginRoute = '/login';
  static const String dashboardRoute = '/';
  static const String chatRoute = '/chat';
  static const String chatConversationRoute = '/chat/:roomId';
  static const String documentsRoute = '/documents';
  static const String announcementsRoute = '/announcements';
  static const String settingsRoute = '/settings';
}
