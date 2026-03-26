import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/viewers/image_viewer_screen.dart';

void main() {
  group('ImageViewerScreen', () {
    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://example.com/image.png',
          title: 'Test Image',
        ),
      ));
      await tester.pump();

      expect(find.text('Test Image'), findsOneWidget);
    });

    testWidgets('has black background', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://example.com/image.png',
          title: 'Photo',
        ),
      ));
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('contains InteractiveViewer for zoom', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://example.com/image.png',
          title: 'Zoomable',
        ),
      ));
      await tester.pump();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('has an AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://example.com/image.png',
          title: 'With AppBar',
        ),
      ));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
