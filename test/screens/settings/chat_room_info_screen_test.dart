import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/chat_room.dart';
import 'package:league_hub/models/organization.dart';
import 'package:league_hub/providers/auth_provider.dart';
import 'package:league_hub/providers/data_providers.dart';
import 'package:league_hub/screens/settings/chat_room_info_screen.dart';
import 'package:league_hub/services/authorized_firestore_service.dart';
import 'package:league_hub/services/firestore_service.dart';
import 'package:league_hub/services/permission_service.dart';
import 'package:league_hub/widgets/avatar_widget.dart';

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
      roomIconName: 'trophy',
    );

ChatRoom _eventRoomWithImage() => ChatRoom(
      id: 'cr3',
      orgId: 'org-1',
      name: 'Spring Tournament',
      type: ChatRoomType.event,
      participants: ['u1', 'u2'],
      createdAt: DateTime(2025, 4, 1),
      isArchived: false,
      roomImageUrl: 'https://example.com/room.png',
    );

ChatRoom _eventRoomWithIcon() => ChatRoom(
      id: 'cr4',
      orgId: 'org-1',
      name: 'Spring Tournament',
      type: ChatRoomType.event,
      participants: ['u1', 'u2'],
      createdAt: DateTime(2025, 4, 1),
      isArchived: false,
      roomIconName: 'trophy',
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
      title: 'League Director',
      role: UserRole.platformOwner,
      orgId: 'org-1',
      hubIds: [],
      leagueIds: ['l1'],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
    );

AppUser _staffUser() => AppUser(
      id: 'u2',
      email: 'staff@test.com',
      displayName: 'Staff Member',
      title: 'Head Coach',
      role: UserRole.staff,
      orgId: 'org-1',
      hubIds: [],
      leagueIds: ['l1'],
      teamIds: [],
      createdAt: DateTime(2025, 1, 1),
      isActive: true,
      avatarUrl: 'https://example.com/staff.png',
    );

Organization _organization() => Organization(
      id: 'org-1',
      name: 'Test Org',
      primaryColor: '#1A3A5C',
      secondaryColor: '#2E75B6',
      accentColor: '#4DA3FF',
      createdAt: DateTime(2025, 1, 1),
      ownerId: 'u1',
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

class _FakeAuthorizedFirestoreService extends AuthorizedFirestoreService {
  _FakeAuthorizedFirestoreService()
      : super(
          FirestoreService(firestore: FakeFirebaseFirestore()),
          const PermissionService(),
        );

  String? updatedRoomId;
  Map<String, dynamic>? updatedData;

  @override
  Future<void> updateChatRoomFields(
    AppUser actor,
    String orgId,
    String roomId,
    Map<String, dynamic> data,
  ) async {
    updatedRoomId = roomId;
    updatedData = data;
  }
}

void main() {
  group('ChatRoomInfoScreen', () {
    testWidgets('renders league room info', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1').overrideWith((ref) => Stream.value(room)),
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
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('uses room icon when an event room has no image',
        (tester) async {
      final room = _eventRoomWithIcon();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr4',
        overrides: [
          chatRoomProvider('cr4').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Event Chat'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
    });

    testWidgets('uses room image when a room image is available',
        (tester) async {
      final room = _eventRoomWithImage();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr3',
        overrides: [
          chatRoomProvider('cr3').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CachedNetworkImage &&
              widget.imageUrl == 'https://example.com/room.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows member list with participant data', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('MEMBERS (2)'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('League Director'), findsOneWidget);
      expect(find.text('Staff Member'), findsOneWidget);
      expect(find.text('Head Coach'), findsOneWidget);
      expect(find.text('Staff'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AvatarWidget &&
              widget.imageUrl == 'https://example.com/staff.png',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows league members for league-attached event rooms',
        (tester) async {
      final room = ChatRoom(
        id: 'event-league',
        orgId: 'org-1',
        name: 'JPHL Tournament',
        type: ChatRoomType.event,
        leagueId: 'l1',
        participants: ['u1'],
        createdAt: DateTime(2025, 4, 1),
        isArchived: false,
      );

      await tester.pumpWidget(_buildTestWidget(
        roomId: room.id,
        overrides: [
          chatRoomProvider(room.id).overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('MEMBERS (2)'), findsOneWidget);
      expect(find.text('Staff Member'), findsOneWidget);
    });

    testWidgets('shows "You" badge for current user', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1').overrideWith((ref) => Stream.value(room)),
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
          chatRoomProvider('cr1').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Archive Chat Room'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('saves room edits without using a disposed controller',
        (tester) async {
      final room = _eventRoomWithIcon();
      final fakeService = _FakeAuthorizedFirestoreService();

      await tester.pumpWidget(_buildTestWidget(
        roomId: room.id,
        overrides: [
          chatRoomProvider(room.id).overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => _organization()),
          authorizedFirestoreServiceProvider.overrideWithValue(fakeService),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Spring Tournament'),
        'Updated Tournament',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Room'), findsNothing);
      expect(fakeService.updatedRoomId, room.id);
      expect(fakeService.updatedData?['name'], 'Updated Tournament');
      expect(fakeService.updatedData?['roomIconName'], 'trophy');
    });

    testWidgets('hides archive button on DM rooms', (tester) async {
      final room = _dmRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr2',
        overrides: [
          chatRoomProvider('cr2').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Direct Message'), findsOneWidget);
      expect(find.text('Archive Chat Room'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('shows peer-focused details for DM rooms', (tester) async {
      final room = _dmRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr2',
        overrides: [
          chatRoomProvider('cr2').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _adminUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Staff Member'), findsWidgets);
      expect(find.text('DIRECT MESSAGE'), findsOneWidget);
      expect(find.text('Private one-on-one conversation'), findsOneWidget);
      expect(find.text('Only you and this person can see messages here.'),
          findsOneWidget);
      expect(find.text('MEMBERS (2)'), findsNothing);
      expect(find.text('Admin'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AvatarWidget &&
              widget.imageUrl == 'https://example.com/staff.png',
        ),
        findsWidgets,
      );
    });

    testWidgets('hides archive for staff users', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1').overrideWith((ref) => Stream.value(room)),
          orgUsersProvider.overrideWith(
              (ref) => Stream.value([_adminUser(), _staffUser()])),
          currentUserProvider.overrideWith((ref) async => _staffUser()),
          organizationProvider.overrideWith((ref) async => null),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Archive Chat Room'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('shows created date', (tester) async {
      final room = _leagueRoom();
      await tester.pumpWidget(_buildTestWidget(
        roomId: 'cr1',
        overrides: [
          chatRoomProvider('cr1').overrideWith((ref) => Stream.value(room)),
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
