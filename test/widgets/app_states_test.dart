import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_states.dart';

void main() {
  group('AppLoadingState', () {
    testWidgets('shows a consistent labelled progress state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingState(label: 'Loading conversations…'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading conversations…'), findsOneWidget);
    });
  });

  group('AppErrorState', () {
    testWidgets('shows context and retries', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              title: 'Unable to load contacts',
              message: 'Check your connection and try again.',
              onRetry: () => retries += 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load contacts'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });
  });
}
