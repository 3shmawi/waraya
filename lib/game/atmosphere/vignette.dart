import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A soft darkening toward the edges of the frame.
///
/// The cheapest of the plan's shader-free atmosphere tricks and the one that
/// does the most: it pulls the eye to the middle of the screen, where the
/// character is, and stops the flat sky reaching the corners at full strength.
class Vignette extends PositionComponent {
  Vignette({required this.color, this.strength = 0.42, super.priority});

  final Color color;

  /// Opacity at the corners.
  final double strength;

  final Paint _paint = Paint();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    final centre = Offset(size.x / 2, size.y * 0.52);
    _paint.shader = ui.Gradient.radial(
      centre,
      size.length * 0.52,
      [
        color.withValues(alpha: 0),
        color.withValues(alpha: strength * 0.25),
        color.withValues(alpha: strength),
      ],
      const [0.0, 0.62, 1.0],
    );
  }

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _paint);
}
