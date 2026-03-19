import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/chat_bubble.dart';
import 'package:league_hub/models/message.dart';

void main() {
  final testDate = DateTime(2024, 6, 1, 10, 30);

  Message makeMessage({
    String id = 'msg1',
    String senderId = 'user1',
    String senderName = 'Alice',
    String? text = 'Hello!',
    List<String>? readBy,
  }) =>
      Message(
        id: id,
        chatRoomId: 'room1',
        senderId: senderId,
        senderName: senderName,
        text: text,
        createdAt: testDate,
        readBy: readBy ?? [senderId],
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

    testWidgets('does NOT show sender name when isSelf is true', (tester) async {
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

    testWidgets('shows single checkmark when only sender has read', (tester) async {
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

    testWidgets('shows double checkmark when multiple people have read', (tester) async {
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

    testWidgets('does NOT show read receipt icons when isSelf is false', (tester) async {
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
  });
}
