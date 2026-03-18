import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/chat_conversation_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/announcements_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/bottom_nav_bar.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _MainScaffold(child: child, location: state.uri.toString()),
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
      ],
    ),
    GoRoute(
      path: '/chat/:roomId',
      builder: (context, state) => ChatConversationScreen(
        roomId: state.pathParameters['roomId']!,
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
            case 0: context.go('/');
            case 1: context.go('/chat');
            case 2: context.go('/documents');
            case 3: context.go('/announcements');
            case 4: context.go('/settings');
          }
        },
      ),
    );
  }
}
