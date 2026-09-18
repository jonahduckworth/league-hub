import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/app_user.dart';
import 'package:league_hub/models/message_reaction.dart';
import 'package:league_hub/widgets/message_reactions.dart';

void main() {
  AppUser user(String id, String name) => AppUser(
    id: id,
    email: '$id@example.com',
    displayName: name,
    role: UserRole.staff,
    orgId: 'org-1',
    hubIds: const [],
    teamIds: const [],
    createdAt: DateTime(2024),
    isActive: true,
  );

  testWidgets('reaction bar keeps every interaction at least 44 points', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReactionBar(
            reactions: const {
              'thumbsUp': ['user-1', 'user-2'],
              'heart': ['user-2'],
            },
            currentUserId: 'user-1',
            onReactionTap: (_) {},
            onAddReaction: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('reaction-chip-target-thumbsUp')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('add-reaction-target'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      find.bySemanticsLabel(
        'Thumbs up reaction from 2 people. View who reacted.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('picker identifies and toggles the signed-in user reaction', (
    tester,
  ) async {
    MessageReaction? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageReactionPicker(
            reactions: const {
              'heart': ['user-1'],
            },
            currentUserId: 'user-1',
            onSelected: (reaction) => selected = reaction,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Remove Heart reaction'), findsOneWidget);
    expect(find.bySemanticsLabel('React with Fire'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reaction-picker-fire')));
    expect(selected, MessageReaction.fire);
  });

  testWidgets('reaction people sheet shows names and switches reaction tabs', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final users = [
      user('user-1', 'Jonah Duckworth'),
      user('user-2', 'Richard Nault'),
      user('user-3', 'Chris Campbell'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showMessageReactionUsersSheet(
                  context,
                  reactions: const {
                    'thumbsUp': ['user-1', 'user-2'],
                    'heart': ['user-3'],
                  },
                  initialReaction: MessageReaction.thumbsUp,
                  users: users,
                ),
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.text('Reactions (3)'), findsOneWidget);
    expect(find.text('Jonah Duckworth'), findsOneWidget);
    expect(find.text('Richard Nault'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reaction-filter-heart')));
    await tester.pumpAndSettle();
    expect(find.text('Chris Campbell'), findsOneWidget);
    expect(find.text('Jonah Duckworth'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker remains one row at maximum text scale', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: MessageReactionPicker(
              reactions: const {},
              currentUserId: 'user-1',
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    final centers = MessageReaction.values
        .map(
          (reaction) => tester.getCenter(
            find.byKey(ValueKey('reaction-picker-${reaction.key}')),
          ),
        )
        .toList();
    for (final center in centers.skip(1)) {
      expect(center.dy, closeTo(centers.first.dy, 0.1));
    }
    expect(tester.takeException(), isNull);
  });
}
