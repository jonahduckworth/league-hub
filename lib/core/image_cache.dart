import 'package:flutter/widgets.dart';

const int _maximumThumbnailCacheDimension = 512;

/// Returns a physical-pixel decode target for a square on-screen thumbnail.
///
/// Network logos are often much larger than their rendered frames. Bounding
/// their decode size avoids a burst of full-resolution image allocations when
/// a logo-heavy list is opened for the first time.
int thumbnailCacheDimension(BuildContext context, double logicalSize) {
  final physicalSize =
      (logicalSize * MediaQuery.devicePixelRatioOf(context)).ceil();
  return physicalSize.clamp(1, _maximumThumbnailCacheDimension).toInt();
}
