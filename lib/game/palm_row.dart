import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'endless.dart';

/// Palms along the road, standing behind the mid treeline band.
///
/// The asset is a crown, not a whole tree: every palm in `art/source` has its
/// lower trunk crossing something as dark as itself, and dark-on-dark defeats a
/// brightness matte in both axes. Rendering the row behind the band sinks each
/// crown's feathered lower edge inside it, so only the part that cut cleanly is
/// ever visible — and a palm showing just its head above the trees is what a
/// village skyline looks like anyway.
///
/// The crown is a flat silhouette rather than a textured cut-out. A silhouette
/// carries no light of its own, which is why a crown photographed at dusk sits
/// correctly in dust-storm bands.
class PalmRow extends EndlessRow {
  PalmRow({
    required this.sprite,
    required super.visibleWorldRect,
    required this.heightUnits,
    required this.baseY,
    super.spacing = 560,
    super.seed = 17,
    super.priority,
  });

  final Sprite sprite;

  /// Height of a typical crown in world units.
  final double heightUnits;

  /// World y the crowns sit on, inside the band that hides their cut edge.
  final double baseY;

  @override
  Paint get fillPaint => _unused;
  static final Paint _unused = Paint();

  @override
  void buildItem(EndlessItem item, int index, double x) {}

  @override
  void render(Canvas canvas) {
    final view = visibleWorldRect();
    final first = (view.left / spacing).floor() - margin;
    final last = (view.right / spacing).ceil() + margin;
    final aspect = sprite.srcSize.x / sprite.srcSize.y;

    for (var i = first; i <= last; i++) {
      final height = heightUnits * (0.78 + noise(i, seed ^ 0x31) * 0.44);
      final width = height * aspect;
      // Mirroring half of them stops the row reading as one repeated tree.
      final flip = noise(i, seed ^ 0x5D) < 0.5;
      final x = itemX(i);

      canvas.save();
      canvas.translate(x, baseY);
      if (flip) canvas.scale(-1, 1);
      sprite.render(
        canvas,
        position: Vector2(-width / 2, -height),
        size: Vector2(width, height),
      );
      canvas.restore();
    }
  }
}
