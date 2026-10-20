import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/widgets/app_shell_header.dart';
import 'package:league_hub/widgets/app_glass.dart';
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

    testWidgets('uses the app glass background', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://example.com/image.png',
          title: 'Photo',
        ),
      ));
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.transparent);
      expect(find.byType(AppGlassBackground), findsOneWidget);
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

    testWidgets('uses the shared app header', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ImageViewerScreen(
          imageUrl: 'https://example.com/image.png',
          title: 'With AppBar',
        ),
      ));
      await tester.pump();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(AppShellHeader), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byType(AppHeaderLogoMark), findsOneWidget);
    });
  });
}
