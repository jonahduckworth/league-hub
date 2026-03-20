import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/chat_room_info_screen.dart';

ChatRoom _leagueRoom() => ChatRoom(
      id: 'cr1',
      orgId: 'org-1',
      name: 'PL - General',
      type: ChatRoomType.league,
      leagueId: 'l1',
      participants: ['u1', 'u2'],
      createdAt: DateTime(2025, 3, 1),
      isArchived: false,
      lastMessage: 'Hello',
      lastMessageAt: DateTime(2025, 3, 15),
      lastMessageBy: 'Admin',
    );

ChatRoom _dmRoom() => ChatRoom(
      id: 'cr2',
      orgId: 'org-1',
      name: 'Sarah Johnson',
      type: ChatRoomType.direct,
      participants: ['u1', 'u2'],
      createdAt: DateTime(2025, 3, 1),
      isArchived: false,
    );

AppUser _adminUser() => AppUser(
      id: 'u1',
      email: 'admin@test.com',
      displayName: 'Admin',
      role: UserRole.platformOwner,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

AppUser _staffUser() => AppUser(
      id: 'u2',
      email: 'staff@test.com',
      displayName: 'Staff Member',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: [],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

Widget _buildTestWidget({
  required String roomId,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: ChatRoomInfoScreen(roomId: roomId),
    ),
  );
}

void main() {
  group('ChatRoomInfoScreen', () {
    testWidgets('renders league room info', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Chat Info'), findsOneWidget);
      expect(find.text('PL - General'), findsOneWidget);
      expect(find.text('League Chat'), findsOneWidget);
    });

    testWidgets('shows member list with participant data', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('MEMBERS (2)'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Staff Member'), findsOneWidget);
    });

    testWidgets('shows "You" badge for current user', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('shows archive button for admin on league room',
        (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Archive Chat Room'), findsOneWidget);
    });

    testWidgets('hides archive button on DM rooms', (tester) async {
      final room = _dmRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr2',
        overrides: [
          chatRoomProvider('cr2')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Direct Message'), findsOneWidget);
      expect(find.text('Archive Chat Room'), findsNothing);
    });

    testWidgets('hides archive for staff users', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _staffUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Archive Chat Room'), findsNothing);
    });

    testWidgets('shows created date', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1')
              .overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Created'), findsOneWidget);
    });
  });
}
