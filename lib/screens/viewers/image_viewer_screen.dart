import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/document_viewer_scaffold.dart';

/// Full-screen image viewer with pinch-to-zoom and pan.
class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String title;
  final List<Widget> actions;
  final String leagueName;
  final String? leagueLogoUrl;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.title,
    this.actions = const [],
    this.leagueName = 'League Hub',
    this.leagueLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return DocumentViewerScaffold(
      title: title,
      leagueName: leagueName,
      leagueLogoUrl: leagueLogoUrl,
      icon: Icons.image_outlined,
      actions: actions,
      child: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image,
                      color: AppColors.textMuted, size: 48),
                  SizedBox(height: 8),
                  Text('Failed to load image',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
