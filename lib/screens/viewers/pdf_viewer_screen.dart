import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/theme.dart';

typedef PdfDownloadCallback = Future<void> Function({
  required String url,
  required String savePath,
  required void Function(int received, int total) onProgress,
});

typedef PdfOpenCallback = Future<OpenResult> Function(String path);

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

Future<OpenResult> _openPdfWithSystemPreview(String path) {
  return OpenFilex.open(path);
}

/// Downloads a PDF into the app sandbox and opens the native iOS/Android
/// document preview. Keeping the route mounted gives people a clear way to
/// reopen the document after dismissing the platform preview.
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final PdfDownloadCallback? downloadPdf;
  final PdfOpenCallback? openPdf;
  final Directory Function()? temporaryDirectory;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.downloadPdf,
    this.openPdf,
    this.temporaryDirectory,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _loading = true;
  bool _openingPreview = false;
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
      final fileName =
          'league_hub_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
        await _openLocalPdf();
      }
    } catch (e) {
      debugPrint('PDF download failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'We couldn\'t download this PDF. Check your connection and try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openLocalPdf() async {
    final localPath = _localPath;
    if (localPath == null || _openingPreview) return;

    setState(() {
      _openingPreview = true;
      _errorMessage = null;
    });

    try {
      final result =
          await (widget.openPdf ?? _openPdfWithSystemPreview)(localPath);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        setState(() {
          _errorMessage =
              'The PDF downloaded, but the device couldn\'t open its preview.';
        });
      }
    } catch (e) {
      debugPrint('PDF preview failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'The PDF downloaded, but the device couldn\'t open its preview.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _openingPreview = false);
      }
    }
  }

  void _retryDownload() {
    setState(() {
      _loading = true;
      _openingPreview = false;
      _errorMessage = null;
      _localPath = null;
      _progress = 0;
    });
    _downloadPdf();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null),
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
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(
                          _localPath == null
                              ? 'Couldn\'t load PDF'
                              : 'Couldn\'t open PDF',
                          style: const TextStyle(
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
                          onPressed: _localPath == null
                              ? _retryDownload
                              : _openLocalPdf,
                          icon: Icon(_localPath == null
                              ? Icons.refresh
                              : Icons.picture_as_pdf_outlined),
                          label: Text(_localPath == null
                              ? 'Try Again'
                              : 'Try Preview Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _localPath != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf,
                              size: 64, color: AppColors.danger),
                          const SizedBox(height: 16),
                          const Text('PDF ready',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text)),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'The document preview is ready. You can reopen it anytime while this page is open.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _openingPreview ? null : _openLocalPdf,
                            icon: _openingPreview
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label:
                                Text(_openingPreview ? 'Opening…' : 'Open PDF'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}
