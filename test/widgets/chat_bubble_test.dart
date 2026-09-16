import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/message.dart';
import 'package:league_hub/screens/viewers/image_viewer_screen.dart';
import 'package:league_hub/widgets/chat_bubble.dart';

void main() {
  final testDate = DateTime(2024, 6, 1, 10, 30);

  Message makeMessage({
    String id = 'msg1',
    String senderId = 'user1',
    String senderName = 'Alice',
    String? text = 'Hello!',
    List<String>? readBy,
    String? mediaUrl,
    Map<String, List<String>> reactions = const {},
  }) =>
      Message(
        id: id,
        chatRoomId: 'room1',
        senderId: senderId,
        senderName: senderName,
        text: text,
        mediaUrl: mediaUrl,
        createdAt: testDate,
        readBy: readBy ?? [senderId],
        reactions: reactions,
      );

  group('ChatBubble', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(text: 'Hello World'),
              isSelf: false,
            ),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('shows sender name when isSelf is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(senderName: 'Bob'),
              isSelf: false,
            ),
          ),
        ),
      );

      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('does NOT show sender name when isSelf is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(senderName: 'Alice'),
              isSelf: true,
            ),
          ),
        ),
      );

      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('shows avatar when isSelf is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(),
              isSelf: false,
            ),
          ),
        ),
      );

      // AvatarWidget renders initials
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('does NOT show avatar when isSelf is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(senderName: 'Alice'),
              isSelf: true,
            ),
          ),
        ),
      );

      // No avatar initials shown for self messages
      expect(find.text('A'), findsNothing);
    });

    testWidgets('shows single checkmark when only sender has read',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(readBy: ['user1']),
              isSelf: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('shows double checkmark when multiple people have read',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(readBy: ['user1', 'user2']),
              isSelf: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.byIcon(Icons.done), findsNothing);
    });

    testWidgets('does NOT show read receipt icons when isSelf is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(readBy: ['user1', 'user2']),
              isSelf: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('renders empty string when text is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(text: null),
              isSelf: false,
            ),
          ),
        ),
      );

      // Widget renders without throwing
      expect(find.byType(ChatBubble), findsOneWidget);
    });

    testWidgets('opens a chat photo in the zoomable full-screen viewer',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(
                senderName: 'Beth',
                text: null,
                mediaUrl: 'https://example.com/photo.jpg',
              ),
              isSelf: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Open photo from Beth',
        ),
        findsOneWidget,
      );
      final tapTargetSize = tester.getSize(
        find.byKey(const Key('chat-image-msg1')),
      );
      expect(tapTargetSize.width, lessThanOrEqualTo(220));
      expect(tapTargetSize.height, greaterThanOrEqualTo(48));
      await tester.tap(find.byKey(const Key('chat-image-msg1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ImageViewerScreen), findsOneWidget);
      expect(find.text('Photo from Beth'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('keeps the photo target usable in compact landscape',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(568, 320);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(
                text: null,
                mediaUrl: 'https://example.com/photo.jpg',
              ),
              isSelf: true,
            ),
          ),
        ),
      );
      await tester.pump();

      final tapTargetSize = tester.getSize(
        find.byKey(const Key('chat-image-msg1')),
      );
      expect(tapTargetSize.width, lessThanOrEqualTo(220));
      expect(tapTargetSize.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers separate reporting and blocking actions for others',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(senderName: 'Bob'),
              isSelf: false,
              onReportMessage: () {},
              onReportUser: () {},
              onBlockUser: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();

      expect(find.text('Report message'), findsOneWidget);
      expect(find.text('Report user'), findsOneWidget);
      expect(find.text('Block Bob'), findsOneWidget);
    });

    testWidgets('does not expose safety actions for own message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(),
              isSelf: true,
              onReportMessage: () {},
              onReportUser: () {},
              onBlockUser: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('shows formatted time', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(),
              isSelf: false,
            ),
          ),
        ),
      );

      // testDate is 10:30 AM
      expect(find.text('10:30 AM'), findsOneWidget);
    });

    testWidgets('shows reactions and opens the named reactor list',
        (tester) async {
      final users = [
        AppUser(
          id: 'user1',
          orgId: 'org1',
          email: 'alice@example.com',
          displayName: 'Alice',
          role: UserRole.staff,
          hubIds: const [],
          teamIds: const [],
          createdAt: testDate,
          isActive: true,
        ),
        AppUser(
          id: 'user2',
          orgId: 'org1',
          email: 'richard@example.com',
          displayName: 'Richard Nault',
          role: UserRole.staff,
          hubIds: const [],
          teamIds: const [],
          createdAt: testDate,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatBubble(
              message: makeMessage(
                reactions: const {
                  'thumbsUp': ['user1', 'user2'],
                },
              ),
              isSelf: false,
              currentUserId: 'user1',
              users: users,
              onToggleReaction: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('reaction-chip-target-thumbsUp')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reactions (2)'), findsOneWidget);
      expect(find.text('Alice'), findsNWidgets(2));
      expect(find.text('Richard Nault'), findsOneWidget);
    });
  });
}
