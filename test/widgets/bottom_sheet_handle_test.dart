import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/bottom_sheet_handle.dart';

void main() {
  group('BottomSheetHandle', () {
    testWidgets('renders a Container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BottomSheetHandle(),
          ),
        ),
      );

      expect(find.byType(Container), findsAtLeastNWidgets(1));
    });

    testWidgets('has correct width (40) and height (4)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: BottomSheetHandle()),
          ),
        ),
      );

      final container = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(BottomSheetHandle),
          matching: find.byType(Container),
        ),
      ).first;

      expect(container.constraints?.maxWidth, 40);
      expect(container.constraints?.maxHeight, 4);
    });

    testWidgets('has border radius', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BottomSheetHandle(),
          ),
        ),
      );

      final container = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(BottomSheetHandle),
          matching: find.byType(Container),
        ),
      ).first;

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(2));
    });

    testWidgets('has bottom margin of 12', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BottomSheetHandle(),
          ),
        ),
      );

      final container = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(BottomSheetHandle),
          matching: find.byType(Container),
        ),
      ).first;

      expect(container.margin, const EdgeInsets.only(bottom: 12));
    });
  });
}
