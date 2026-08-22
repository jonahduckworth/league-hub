import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_glass.dart';
import 'package:league_hub/widgets/schedule_team_logo.dart';

void main() {
  Widget subject({
    String? imageUrl,
    Color fallbackTextColor = AppGlassColors.ink,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: ScheduleTeamLogo(
            teamName: 'Wolves HC',
            imageUrl: imageUrl,
            size: 28,
            fallbackTextColor: fallbackTextColor,
          ),
        ),
      );

  testWidgets('uses a transparent fixed frame and falls back to initials',
      (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('WH'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('WH')).style?.color,
      AppGlassColors.ink,
    );
    expect(tester.getSize(find.byType(ScheduleTeamLogo)), const Size(28, 28));
    expect(
      find.descendant(
        of: find.byType(ScheduleTeamLogo),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports dark fallback initials on a light card',
      (tester) async {
    const fallbackColor = Color(0xFF061D3A);
    await tester.pumpWidget(subject(fallbackTextColor: fallbackColor));

    expect(
      tester.widget<Text>(find.text('WH')).style?.color,
      fallbackColor,
    );
  });

  testWidgets('uses a cached network image when a logo URL is available',
      (tester) async {
    await tester
        .pumpWidget(subject(imageUrl: 'https://example.com/wolves.png'));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fit, BoxFit.contain);
    final expectedCacheDimension = (28 * tester.view.devicePixelRatio).ceil();
    expect(image.memCacheWidth, expectedCacheDimension);
    expect(image.memCacheHeight, expectedCacheDimension);
    expect(image.maxWidthDiskCache, expectedCacheDimension);
    expect(image.maxHeightDiskCache, expectedCacheDimension);
    expect(tester.getSize(find.byType(ScheduleTeamLogo)), const Size(28, 28));
  });
}
