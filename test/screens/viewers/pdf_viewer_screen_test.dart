import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/viewers/pdf_viewer_screen.dart';

void main() {
  group('PdfViewerScreen', () {
    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Test PDF',
        ),
      ));
      await tester.pump();

      expect(find.text('Test PDF'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Loading PDF',
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Downloading PDF...'), findsOneWidget);
    });

    testWidgets('has an AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'PDF',
        ),
      ));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}
