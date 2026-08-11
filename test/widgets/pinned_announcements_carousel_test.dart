import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/models/announcement.dart';
import 'package:league_hub/widgets/pinned_announcements_carousel.dart';

void main() {
  Announcement announcement(int index, {bool isPinned = true}) {
    return Announcement(
      id: 'announcement-$index',
      orgId: 'org-1',
      scope: AnnouncementScope.league,
      title: 'Update $index',
      body: 'Details for update $index',
      authorId: 'author-1',
      authorName: 'League Admin',
      authorRole: 'Administrator',
      attachments: const [],
      isPinned: isPinned,
      createdAt: DateTime(2026, 8, index + 1),
    );
  }

  Widget app({
    required List<Announcement> announcements,
    ValueChanged<Announcement>? onTap,
    VoidCallback? onViewAll,
    double textScale = 1,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PinnedAnnouncementsCarousel(
              announcements: announcements,
              onViewAll: onViewAll ?? () {},
              onAnnouncementTap: onTap ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  test('keeps only pinned announcements and caps the carousel', () {
    final results = pinnedAnnouncementsForCarousel([
      announcement(0, isPinned: false),
      for (var index = 1; index <= 7; index++) announcement(index),
    ]);

    expect(results, hasLength(maxPinnedAnnouncementsInCarousel));
    expect(results.every((item) => item.isPinned), isTrue);
    expect(results.first.id, 'announcement-1');
    expect(results.last.id, 'announcement-5');
  });

  testWidgets('uses a user-controlled page view with visible progress',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(announcements: [announcement(1), announcement(2)]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsOneWidget);
    expect(
      find.byKey(const ValueKey('announcement-page-indicator-0')),
      findsOneWidget,
    );

    await tester.fling(find.byType(PageView), const Offset(-340, 0), 1200);
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('pinned-page-semantics')),
    );
    expect(semantics.label, contains('Announcement 2 of 2'));
  });

  testWidgets('keeps the carousel usable with accessibility text sizes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(
        announcements: [announcement(1), announcement(2)],
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(PageView)).height, 250);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a compact empty pinned state', (tester) async {
    await tester.pumpWidget(app(announcements: const []));
    await tester.pumpAndSettle();

    expect(find.text('No pinned announcements'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });
}
