import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';

/// The sunset sky, drawn as a vertical gradient.
///
/// It lives in the camera's viewport rather than the world, so it never scrolls
/// — the correct behaviour for an infinitely distant layer, and the cheapest
/// possible "background" on every platform including web.
///
/// PLACEHOLDER: Friday 2 replaces this with the photographed silhouette layers
/// in a `ParallaxComponent`.
class SkyBackdrop extends PositionComponent {
  SkyBackdrop() : super(priority: -1000);

  static const _stops = <double>[0.0, 0.42, 0.68, 0.86, 1.0];
  static const _colors = <Color>[
    Color(0xFF1B2A4A), // high indigo
    Color(0xFF4B3F63), // dusty violet
    Color(0xFF9C5B54), // haze over the city
    Color(0xFFD98E4A), // sun band
    Color(0xFFF0C27B), // horizon glow
  ];

  final Paint _paint = Paint();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    // The camera's vertical position is pinned, so the horizon always lands at
    // the same fraction of the screen on every device. Ending the ramp there
    // keeps the whole sunset above the ground instead of burying the warm end
    // of it under the foreground.
    final horizonOnScreen =
        size.y * WarayaConfig.horizonY / WarayaConfig.worldHeight;
    _paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, horizonOnScreen),
      _colors,
      _stops,
    );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _paint);
  }
}
