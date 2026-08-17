import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/viewers/pdf_viewer_screen.dart';

Future<void> _pendingDownload({
  required String url,
  required String savePath,
  required void Function(int received, int total) onProgress,
}) {
  return Completer<void>().future;
}

void main() {
  group('PdfViewerScreen', () {
    test('uses a readable policy title for the local viewer copy', () {
      expect(policyPdfFileName('Lily v2'), 'Lily v2.pdf');
      expect(policyPdfFileName('Rules.pdf'), 'Rules.pdf');
      expect(policyPdfFileName('Policy / Final'), 'Policy _ Final.pdf');
    });

    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Test PDF',
          downloadPdf: _pendingDownload,
        ),
      ));
      await tester.pump();

      expect(find.text('Test PDF'), findsOneWidget);
    });

    testWidgets('shows loading state initially', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Loading PDF',
          downloadPdf: _pendingDownload,
        ),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Downloading PDF...'), findsOneWidget);
    });

    testWidgets('has an AppBar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: const PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'PDF',
          downloadPdf: _pendingDownload,
        ),
      ));
      await tester.pump();

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('downloads and renders the PDF inside the app', (tester) async {
      final tempDirectory =
          Directory.systemTemp.createTempSync('league_hub_pdf_test_');
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      String? renderedPath;

      await tester.pumpWidget(MaterialApp(
        home: PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Preview PDF',
          temporaryDirectory: () => tempDirectory,
          downloadPdf: (
              {required url, required savePath, required onProgress}) async {
            onProgress(4, 4);
          },
          pdfContentBuilder: (context, path) {
            renderedPath = path;
            return const ColoredBox(
              key: ValueKey('embedded-pdf-viewer'),
              color: Colors.white,
            );
          },
        ),
      ));

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(renderedPath, isNotNull);
      expect(renderedPath, endsWith('Preview PDF.pdf'));
      expect(find.byKey(const ValueKey('embedded-pdf-viewer')), findsOneWidget);
      expect(find.text('Open PDF'), findsNothing);
      expect(find.text('PDF ready'), findsNothing);
    });

    testWidgets('shows a concise error instead of native exception details',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Broken PDF',
          downloadPdf: (
              {required url, required savePath, required onProgress}) async {
            throw ArgumentError(
              "Couldn't resolve native function 'DOBJC_initializeApi'",
            );
          },
        ),
      ));

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Couldn\'t load PDF'), findsOneWidget);
      expect(find.textContaining('Check your connection'), findsOneWidget);
      expect(find.textContaining('DOBJC_initializeApi'), findsNothing);
    });
  });
}
