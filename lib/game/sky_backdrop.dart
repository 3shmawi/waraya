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
/// The stops are sampled from `art/source/src_01.jpg`, the dust-storm frame the
/// bands were cut from, so the sky and the layers agree on one light.
class SkyBackdrop extends PositionComponent {
  SkyBackdrop() : super(priority: -1000);

  /// Public so anything else that has to paint this sky — the mark on the
  /// campaign's ending, say — paints *this* sky rather than a second copy of
  /// these numbers that quietly stops matching.
  static const stops = <double>[0.0, 0.35, 0.62, 0.82, 1.0];
  static const colors = <Color>[
    Color(0xFFF7C032), // high dust
    Color(0xFFF1AD0C), // measured at 0.30 of the frame
    Color(0xFFE59D00), // 0.50
    Color(0xFFDE9600), // 0.58
    Color(0xFFD28C02), // 0.68, just above the treeline
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
      colors,
      stops,
    );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _paint);
  }
}
