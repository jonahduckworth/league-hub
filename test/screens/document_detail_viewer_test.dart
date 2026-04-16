import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/document_detail_screen.dart';

/// Tests for file-type based viewer routing logic in DocumentDetailScreen.
void main() {
  group('Document viewer routing', () {
    test('PNG files route to image viewer', () {
      expect(documentViewerTypeForExt('png'), DocumentViewerType.image);
    });

    test('JPG files route to image viewer', () {
      expect(documentViewerTypeForExt('jpg'), DocumentViewerType.image);
    });

    test('JPEG files route to image viewer', () {
      expect(documentViewerTypeForExt('jpeg'), DocumentViewerType.image);
    });

    test('GIF files route to image viewer', () {
      expect(documentViewerTypeForExt('gif'), DocumentViewerType.image);
    });

    test('WEBP files route to image viewer', () {
      expect(documentViewerTypeForExt('webp'), DocumentViewerType.image);
    });

    test('BMP files route to image viewer', () {
      expect(documentViewerTypeForExt('bmp'), DocumentViewerType.image);
    });

    test('PDF files route to PDF viewer', () {
      expect(documentViewerTypeForExt('pdf'), DocumentViewerType.pdf);
    });

    test('DOCX files route to office viewer', () {
      expect(documentViewerTypeForExt('docx'), DocumentViewerType.native);
    });

    test('XLSX files route to office viewer', () {
      expect(documentViewerTypeForExt('xlsx'), DocumentViewerType.native);
    });

    test('DOC files route to office viewer', () {
      expect(documentViewerTypeForExt('doc'), DocumentViewerType.native);
    });

    test('XLS files route to office viewer', () {
      expect(documentViewerTypeForExt('xls'), DocumentViewerType.native);
    });

    test('CSV files route to native preview fallback', () {
      expect(documentViewerTypeForExt('csv'), DocumentViewerType.native);
    });

    test('PPTX files route to native preview fallback', () {
      expect(documentViewerTypeForExt('pptx'), DocumentViewerType.native);
    });

    test('all image extensions are recognized', () {
      for (final ext in _testImageExts) {
        expect(
          documentViewerTypeForExt(ext),
          DocumentViewerType.image,
          reason: '.$ext should be image',
        );
      }
    });

    test('non-image non-pdf extensions route to native preview', () {
      for (final ext in _testOfficeExts) {
        expect(
          documentViewerTypeForExt(ext),
          DocumentViewerType.native,
          reason: '.$ext should use native preview',
        );
      }
    });

    test('case insensitive matching works', () {
      expect(documentViewerTypeForExt('PNG'), DocumentViewerType.image);
      expect(documentViewerTypeForExt('PDF'), DocumentViewerType.pdf);
      expect(documentViewerTypeForExt('DOCX'), DocumentViewerType.native);
    });

    test('unknown extension falls back to native preview', () {
      expect(documentViewerTypeForExt('xyz'), DocumentViewerType.native);
      expect(documentViewerTypeForExt(''), DocumentViewerType.native);
    });
  });

  group('URL extension extraction', () {
    test('extracts pdf from URL', () {
      expect(
        extractDocumentExtensionFromUrl('https://storage.example.com/docs/report.pdf'),
        'pdf',
      );
    });

    test('extracts jpg from URL', () {
      expect(
        extractDocumentExtensionFromUrl('https://storage.example.com/images/photo.jpg'),
        'jpg',
      );
    });

    test('handles URL with query params', () {
      expect(
        extractDocumentExtensionFromUrl('https://example.com/file.png?token=abc'),
        'png',
      );
    });

    test('returns empty for URL without extension', () {
      expect(extractDocumentExtensionFromUrl('https://example.com/file'), '');
    });

    test('handles complex paths', () {
      expect(
        extractDocumentExtensionFromUrl(
          'https://storage.googleapis.com/bucket/org1/docs/v2/report.xlsx',
        ),
        'xlsx',
      );
    });
  });
}

const _testImageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _testOfficeExts = {'docx', 'xlsx', 'doc', 'xls'};
