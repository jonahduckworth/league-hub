import 'package:flutter_test/flutter_test.dart';
import 'package:league_hub/screens/policy_detail_screen.dart';

/// Tests for file-type based viewer routing logic in PolicyDetailScreen.
void main() {
  group('Policy viewer routing', () {
    test('PNG files route to image viewer', () {
      expect(policyViewerTypeForExt('png'), PolicyViewerType.image);
    });

    test('JPG files route to image viewer', () {
      expect(policyViewerTypeForExt('jpg'), PolicyViewerType.image);
    });

    test('JPEG files route to image viewer', () {
      expect(policyViewerTypeForExt('jpeg'), PolicyViewerType.image);
    });

    test('GIF files route to image viewer', () {
      expect(policyViewerTypeForExt('gif'), PolicyViewerType.image);
    });

    test('WEBP files route to image viewer', () {
      expect(policyViewerTypeForExt('webp'), PolicyViewerType.image);
    });

    test('BMP files route to image viewer', () {
      expect(policyViewerTypeForExt('bmp'), PolicyViewerType.image);
    });

    test('PDF files route to PDF viewer', () {
      expect(policyViewerTypeForExt('pdf'), PolicyViewerType.pdf);
    });

    test('DOCX files route to office viewer', () {
      expect(policyViewerTypeForExt('docx'), PolicyViewerType.native);
    });

    test('XLSX files route to office viewer', () {
      expect(policyViewerTypeForExt('xlsx'), PolicyViewerType.native);
    });

    test('DOC files route to office viewer', () {
      expect(policyViewerTypeForExt('doc'), PolicyViewerType.native);
    });

    test('XLS files route to office viewer', () {
      expect(policyViewerTypeForExt('xls'), PolicyViewerType.native);
    });

    test('CSV files route to native preview fallback', () {
      expect(policyViewerTypeForExt('csv'), PolicyViewerType.native);
    });

    test('PPTX files route to native preview fallback', () {
      expect(policyViewerTypeForExt('pptx'), PolicyViewerType.native);
    });

    test('all image extensions are recognized', () {
      for (final ext in _testImageExts) {
        expect(
          policyViewerTypeForExt(ext),
          PolicyViewerType.image,
          reason: '.$ext should be image',
        );
      }
    });

    test('non-image non-pdf extensions route to native preview', () {
      for (final ext in _testOfficeExts) {
        expect(
          policyViewerTypeForExt(ext),
          PolicyViewerType.native,
          reason: '.$ext should use native preview',
        );
      }
    });

    test('case insensitive matching works', () {
      expect(policyViewerTypeForExt('PNG'), PolicyViewerType.image);
      expect(policyViewerTypeForExt('PDF'), PolicyViewerType.pdf);
      expect(policyViewerTypeForExt('DOCX'), PolicyViewerType.native);
    });

    test('unknown extension falls back to native preview', () {
      expect(policyViewerTypeForExt('xyz'), PolicyViewerType.native);
      expect(policyViewerTypeForExt(''), PolicyViewerType.native);
    });
  });

  group('URL extension extraction', () {
    test('extracts pdf from URL', () {
      expect(
        extractPolicyExtensionFromUrl(
            'https://storage.example.com/policies/report.pdf'),
        'pdf',
      );
    });

    test('extracts jpg from URL', () {
      expect(
        extractPolicyExtensionFromUrl(
            'https://storage.example.com/images/photo.jpg'),
        'jpg',
      );
    });

    test('handles URL with query params', () {
      expect(
        extractPolicyExtensionFromUrl('https://example.com/file.png?token=abc'),
        'png',
      );
    });

    test('returns empty for URL without extension', () {
      expect(extractPolicyExtensionFromUrl('https://example.com/file'), '');
    });

    test('handles complex paths', () {
      expect(
        extractPolicyExtensionFromUrl(
          'https://storage.googleapis.com/bucket/org1/policies/v2/report.xlsx',
        ),
        'xlsx',
      );
    });
  });
}

const _testImageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _testOfficeExts = {'docx', 'xlsx', 'doc', 'xls'};
