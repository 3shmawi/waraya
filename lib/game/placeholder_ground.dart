import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';

/// Flat fill from the horizon down, so the scene reads as a surface the
/// character stands on rather than sky all the way to the bottom.
///
/// PLACEHOLDER for Friday 2's foreground rooftop layer.
class PlaceholderGround extends PositionComponent {
  PlaceholderGround({required this.color, required this.span, super.priority});

  final Color color;
  final double span;

  late final Paint _paint = Paint()..color = color;
  late final Rect _rect = Rect.fromLTRB(
    -span / 2,
    WarayaConfig.horizonY,
    span / 2,
    // Overdraw well past the bottom so no device height exposes an edge.
    WarayaConfig.worldHeight * 2,
  );

  @override
  void render(Canvas canvas) => canvas.drawRect(_rect, _paint);
}
