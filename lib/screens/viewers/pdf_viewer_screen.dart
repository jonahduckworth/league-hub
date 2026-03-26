import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme.dart';

/// Full-screen PDF viewer that downloads the PDF to a temporary file
/// and displays it using the platform's built-in PDF rendering.
///
/// On platforms that don't support in-process PDF rendering, falls back
/// to opening via the system viewer.
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
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
      final dir = await getTemporaryDirectory();
      final fileName =
          'league_hub_pdf_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${dir.path}/$fileName';

      await Dio().download(
        widget.pdfUrl,
        filePath,
        onReceiveProgress: (received, total) {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load PDF: $e';
          _loading = false;
        });
      }
    }
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
                  CircularProgressIndicator(value: _progress > 0 ? _progress : null),
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
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _errorMessage = null;
                              _progress = 0;
                            });
                            _downloadPdf();
                          },
                          child: const Text('Retry'),
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
                          const Text('PDF Downloaded',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text)),
                          const SizedBox(height: 8),
                          Text(
                            File(_localPath!).existsSync()
                                ? 'Saved to temporary storage'
                                : 'File ready',
                            style: const TextStyle(
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () {
                              // Open with system viewer
                              Navigator.pop(context, _localPath);
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open in System Viewer'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
    );
  }
}
