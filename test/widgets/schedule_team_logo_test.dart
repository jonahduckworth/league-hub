import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/schedule_team_logo.dart';

void main() {
  Widget subject({String? imageUrl}) => MaterialApp(
        home: Scaffold(
          body: ScheduleTeamLogo(
            teamName: 'Wolves HC',
            imageUrl: imageUrl,
            size: 28,
          ),
        ),
      );

  testWidgets('reserves a fixed contained frame and falls back to initials',
      (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('WH'), findsOneWidget);
    expect(tester.getSize(find.byType(ScheduleTeamLogo)), const Size(28, 28));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a cached network image when a logo URL is available',
      (tester) async {
    await tester
        .pumpWidget(subject(imageUrl: 'https://example.com/wolves.png'));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fit, BoxFit.contain);
    expect(tester.getSize(find.byType(ScheduleTeamLogo)), const Size(28, 28));
  });
}
