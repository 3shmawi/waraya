import 'dart:math';

import 'package:flame/components.dart';

/// Palm crowns standing along the horizon, cut out of a photograph.
///
/// Only the crown and the trunk above the treeline are in the image. Every palm
/// in `art/source` has its lower trunk crossing buildings as dark as itself, so
/// no brightness matte separates them — but a palm in a real village skyline is
/// mostly hidden behind the trees anyway, so the row renders *behind* the mid
/// treeline band and the missing trunk is never on screen.
///
/// A palm is a discrete object, so these are placed sprites rather than a tiled
/// layer: tiling one tree reads as wallpaper.
class PalmRow extends Component {
  PalmRow({
    required this.sprite,
    required this.span,
    required this.heightUnits,
    required this.baseY,
    int seed = 7,
    super.priority,
  }) : _random = Random(seed);

  final Sprite sprite;
  final double span;

  /// Height of the crown in world units -- the image is the crown alone, not a
  /// whole tree, so this is much smaller than a palm's real height.
  final double heightUnits;

  /// World y the crown's feathered lower edge sits on. It belongs *inside* the
  /// treeline band, so the cut is never visible.
  final double baseY;

  final Random _random;

  @override
  Future<void> onLoad() async {
    final aspect = sprite.srcSize.x / sprite.srcSize.y;

    for (
      var x = -span / 2;
      x < span / 2;
      x += 700 + _random.nextDouble() * 900
    ) {
      final height = heightUnits * (0.82 + _random.nextDouble() * 0.36);
      await add(
        SpriteComponent(
          sprite: sprite,
          size: Vector2(height * aspect, height),
          position: Vector2(x, baseY + _random.nextDouble() * 30),
          anchor: Anchor.bottomCenter,
          // Mirroring half of them stops the row reading as one repeated tree.
          scale: _random.nextBool() ? Vector2(1, 1) : Vector2(-1, 1),
        ),
      );
    }
  }
}
