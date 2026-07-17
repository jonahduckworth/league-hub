import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/viewers/pdf_viewer_screen.dart';
import 'package:open_filex/open_filex.dart';

Future<void> _pendingDownload({
  required String url,
  required String savePath,
  required void Function(int received, int total) onProgress,
}) {
  return Completer<void>().future;
}

void main() {
  group('PdfViewerScreen', () {
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

    testWidgets('downloads and opens the native PDF preview automatically',
        (tester) async {
      final tempDirectory =
          Directory.systemTemp.createTempSync('league_hub_pdf_test_');
      addTearDown(() => tempDirectory.deleteSync(recursive: true));
      String? openedPath;

      await tester.pumpWidget(MaterialApp(
        home: PdfViewerScreen(
          pdfUrl: 'https://example.com/doc.pdf',
          title: 'Preview PDF',
          temporaryDirectory: () => tempDirectory,
          downloadPdf: (
              {required url, required savePath, required onProgress}) async {
            onProgress(4, 4);
          },
          openPdf: (path) async {
            openedPath = path;
            return OpenResult();
          },
        ),
      ));

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(openedPath, isNotNull);
      expect(find.text('PDF ready'), findsOneWidget);
      expect(find.text('Open PDF'), findsOneWidget);
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
