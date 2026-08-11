import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/dashboard_empty_schedule_state.dart';

void main() {
  Widget subject({required double textScale}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 328,
                  child: DashboardEmptyScheduleState(
                    accessibilityLayout: DashboardEmptyScheduleState
                        .shouldUseAccessibilityLayout(context),
                    titleColor: const Color(0xFF061D3A),
                    bodyColor: const Color(0xFF34516F),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('keeps the compact text column at standard sizes',
      (tester) async {
    await tester.pumpWidget(
      subject(textScale: 1),
    );

    final content = find.byKey(const ValueKey('next-game-empty-text-column'));
    expect(tester.getSize(content).width, closeTo(328 * 0.72, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays practical at accessibility extra large text',
      (tester) async {
    await tester.pumpWidget(
      subject(textScale: 3.2),
    );

    final content = find.byKey(const ValueKey('next-game-empty-text-column'));
    expect(tester.getSize(content).width, closeTo(328, 1));
    final titleContext = tester.element(find.text('No upcoming games'));
    expect(MediaQuery.textScalerOf(titleContext).scale(20), closeTo(28, 0.01));
    expect(tester.getSize(content).height, lessThan(280));
    expect(tester.takeException(), isNull);
  });
}
