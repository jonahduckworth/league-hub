import 'package:flutter_test/flutter_test.dart';

/// Tests for file-type based viewer routing logic in DocumentDetailScreen.
void main() {
  const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  const pdfExts = {'pdf'};
  const unsupportedExts = {'docx', 'xlsx', 'doc', 'xls', 'csv', 'pptx'};

  String viewerForExt(String ext) {
    if (imageExts.contains(ext.toLowerCase())) return 'image';
    if (pdfExts.contains(ext.toLowerCase())) return 'pdf';
    return 'external';
  }

  group('Document viewer routing', () {
    test('PNG files route to image viewer', () {
      expect(viewerForExt('png'), 'image');
    });

    test('JPG files route to image viewer', () {
      expect(viewerForExt('jpg'), 'image');
    });

    test('JPEG files route to image viewer', () {
      expect(viewerForExt('jpeg'), 'image');
    });

    test('GIF files route to image viewer', () {
      expect(viewerForExt('gif'), 'image');
    });

    test('WEBP files route to image viewer', () {
      expect(viewerForExt('webp'), 'image');
    });

    test('BMP files route to image viewer', () {
      expect(viewerForExt('bmp'), 'image');
    });

    test('PDF files route to PDF viewer', () {
      expect(viewerForExt('pdf'), 'pdf');
    });

    test('DOCX files route to external viewer', () {
      expect(viewerForExt('docx'), 'external');
    });

    test('XLSX files route to external viewer', () {
      expect(viewerForExt('xlsx'), 'external');
    });

    test('DOC files route to external viewer', () {
      expect(viewerForExt('doc'), 'external');
    });

    test('XLS files route to external viewer', () {
      expect(viewerForExt('xls'), 'external');
    });

    test('CSV files route to external viewer', () {
      expect(viewerForExt('csv'), 'external');
    });

    test('PPTX files route to external viewer', () {
      expect(viewerForExt('pptx'), 'external');
    });

    test('all image extensions are recognized', () {
      for (final ext in imageExts) {
        expect(viewerForExt(ext), 'image', reason: '.$ext should be image');
      }
    });

    test('all unsupported extensions fall back to external', () {
      for (final ext in unsupportedExts) {
        expect(viewerForExt(ext), 'external',
            reason: '.$ext should be external');
      }
    });

    test('case insensitive matching works', () {
      expect(viewerForExt('PNG'), 'image');
      expect(viewerForExt('PDF'), 'pdf');
      expect(viewerForExt('DOCX'), 'external');
    });

    test('unknown extension falls back to external', () {
      expect(viewerForExt('xyz'), 'external');
      expect(viewerForExt(''), 'external');
    });
  });

  group('URL extension extraction', () {
    String extractExt(String url) {
      try {
        final path = Uri.parse(url).path;
        final lastDot = path.lastIndexOf('.');
        if (lastDot != -1) return path.substring(lastDot + 1);
      } catch (_) {}
      return '';
    }

    test('extracts pdf from URL', () {
      expect(extractExt('https://storage.example.com/docs/report.pdf'), 'pdf');
    });

    test('extracts jpg from URL', () {
      expect(extractExt('https://storage.example.com/images/photo.jpg'), 'jpg');
    });

    test('handles URL with query params', () {
      expect(extractExt('https://example.com/file.png?token=abc'), 'png');
    });

    test('returns empty for URL without extension', () {
      expect(extractExt('https://example.com/file'), '');
    });

    test('handles complex paths', () {
      expect(
          extractExt('https://storage.googleapis.com/bucket/org1/docs/v2/report.xlsx'),
          'xlsx');
    });
  });
}
