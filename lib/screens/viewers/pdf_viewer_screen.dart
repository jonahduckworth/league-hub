import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/theme.dart';

typedef PdfDownloadCallback = Future<void> Function({
  required String url,
  required String savePath,
  required void Function(int received, int total) onProgress,
});

typedef PdfContentBuilder = Widget Function(
  BuildContext context,
  String localPath,
);

String policyPdfFileName(String title) {
  final sanitized = title.replaceAll(RegExp(r'[^\w\-. ]'), '_').trim();
  final baseName = sanitized.isEmpty ? 'League Hub Policy' : sanitized;
  return baseName.toLowerCase().endsWith('.pdf') ? baseName : '$baseName.pdf';
}

Future<void> _downloadPdfWithDio({
  required String url,
  required String savePath,
  required void Function(int received, int total) onProgress,
}) async {
  await Dio().download(
    url,
    savePath,
    onReceiveProgress: onProgress,
  );
}

Widget _buildEmbeddedPdf(BuildContext context, String localPath) {
  return PdfViewer.file(
    localPath,
    params: PdfViewerParams(
      backgroundColor: AppColors.background,
      margin: 12,
      pageDropShadow: const BoxShadow(
        color: Colors.black38,
        blurRadius: 8,
        offset: Offset(0, 3),
      ),
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
          const Center(child: CircularProgressIndicator()),
      errorBannerBuilder: (context, error, stackTrace, documentRef) =>
          const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This PDF could not be rendered. Please try downloading it again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
    ),
  );
}

/// Downloads a policy PDF into the app sandbox and renders it inside the app.
///
/// The local copy keeps Firebase Storage delivery reliable, while the embedded
/// viewer avoids the iOS share sheet that a generic file opener displays.
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final PdfDownloadCallback? downloadPdf;
  final PdfContentBuilder? pdfContentBuilder;
  final Directory Function()? temporaryDirectory;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.downloadPdf,
    this.pdfContentBuilder,
    this.temporaryDirectory,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _loading = true;
  double _progress = 0;
  String? _errorMessage;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      final dir = widget.temporaryDirectory?.call() ?? Directory.systemTemp;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final fileName = policyPdfFileName(widget.title);
      final filePath = '${dir.path}/$fileName';

      await (widget.downloadPdf ?? _downloadPdfWithDio)(
        url: widget.pdfUrl,
        savePath: filePath,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (mounted) {
        setState(() {
          _localPath = filePath;
          _loading = false;
        });
      }
    } catch (error) {
      debugPrint('PDF download failed: $error');
      if (mounted) {
        setState(() {
          _errorMessage =
              'We couldn\'t download this PDF. Check your connection and try again.';
          _loading = false;
        });
      }
    }
  }

  void _retryDownload() {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _localPath = null;
      _progress = 0;
    });
    _downloadPdf();
  }

  @override
  Widget build(BuildContext context) {
    final localPath = _localPath;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _progress > 0
                        ? 'Downloading ${(_progress * 100).toStringAsFixed(0)}%...'
                        : 'Downloading PDF...',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: AppColors.danger,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Couldn\'t load PDF',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _retryDownload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : localPath != null
                  ? Semantics(
                      label: '${widget.title} PDF document',
                      child: (widget.pdfContentBuilder ?? _buildEmbeddedPdf)(
                        context,
                        localPath,
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}
