import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// One photographed band, tiled horizontally and scrolled by depth.
///
/// Flame's [ParallaxComponent] scrolls on its own velocity in its own space and
/// ignores the camera zoom, which fights the fixed world height this project
/// uses. This does the same job against the camera instead: [depth] 0 is
/// infinitely far and stays locked to the viewport, 1 sits in the world plane
/// and moves with it.
///
/// The source image tiles under `ImageRepeat.repeatX`, so one photograph is
/// enough -- `tools/silhouette.py --tile` makes the seam invisible.
class PhotoBand extends PositionComponent {
  PhotoBand({
    required this.image,
    required this.depth,
    required this.heightUnits,
    required this.bottomY,
    required this.visibleWorldRect,
    super.priority,
  });

  final ui.Image image;

  /// 0 = infinitely distant, 1 = in the world plane.
  final double depth;

  /// How tall the band is in world units; the width follows the aspect ratio.
  final double heightUnits;

  /// World y the bottom edge sits on.
  final double bottomY;

  final ValueGetter<Rect> visibleWorldRect;

  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;
  late final Rect _src = Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );

  @override
  void render(Canvas canvas) {
    final view = visibleWorldRect();
    final scale = heightUnits / image.height;
    final tileWidth = image.width * scale;

    // Shifting the band by the camera's own displacement is what creates the
    // parallax: a far band is dragged along with the viewport, a near one is
    // left behind in the world.
    final shift = view.center.dx * (1 - depth);

    canvas.save();
    canvas.translate(shift, 0);

    final left = view.left - shift;
    final firstTile = (left / tileWidth).floor();
    final tileCount = (view.width / tileWidth).ceil() + 2;
    final top = bottomY - heightUnits;

    for (var i = 0; i < tileCount; i++) {
      canvas.drawImageRect(
        image,
        _src,
        Rect.fromLTWH((firstTile + i) * tileWidth, top, tileWidth, heightUnits),
        _paint,
      );
    }
    canvas.restore();
  }
}
