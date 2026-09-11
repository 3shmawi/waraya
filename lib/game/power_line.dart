import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';

/// Poles and the wire sagging between them, drawn rather than photographed.
///
/// The photographed wires band was cut from a frame where the wires run
/// diagonally, so every tile boundary chopped them mid-span and the repeat read
/// as broken cable. No seam blend fixes that: the wire enters one edge at a
/// different height and angle than it leaves the other.
///
/// Drawing them is not a compromise here. A wire at this scale is a two-pixel
/// dark line, so a photograph contributes no texture worth keeping, while a
/// catenary computed between known poles is continuous forever, tiles by
/// construction, and costs no download.
class PowerLine extends PositionComponent {
  PowerLine({
    required this.color,
    required this.span,
    required this.visibleWorldRect,
    this.spacing = 460,
    this.poleHeight = 250,
    int seed = 11,
    super.priority,
  }) : _random = Random(seed);

  final Color color;

  /// Total horizontal extent covered, centred on the world origin.
  final double span;

  final ValueGetter<Rect> visibleWorldRect;

  /// Distance between poles, in world units.
  final double spacing;

  /// Height of a pole above the horizon, in world units.
  final double poleHeight;

  final Random _random;

  late final Paint _solid = Paint()..color = color;
  late final Paint _wire = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  final Path _poles = Path();
  final Path _wires = Path();

  @override
  void onLoad() {
    double? previousX;
    var previousTop = 0.0;

    for (var x = -span / 2; x < span / 2; x += spacing) {
      // Real poles lean and vary; a perfectly regular row reads as a fence.
      final height = poleHeight * (0.92 + _random.nextDouble() * 0.16);
      final top = WarayaConfig.horizonY - height;

      _poles.addRect(Rect.fromLTRB(x - 4, top, x + 4, WarayaConfig.horizonY));
      _poles.addRect(Rect.fromLTRB(x - 38, top + 14, x + 38, top + 20));

      if (previousX != null) {
        for (final offset in const [17.0, 38.0]) {
          final y1 = previousTop + offset;
          final y2 = top + offset;
          final sag = spacing * (0.10 + _random.nextDouble() * 0.05);
          _wires.moveTo(previousX, y1);
          // A quadratic through a control point below both ends approximates
          // the catenary closely enough at this scale.
          _wires.quadraticBezierTo(
            (previousX + x) / 2,
            max(y1, y2) + sag,
            x,
            y2,
          );
        }
      }
      previousX = x;
      previousTop = top;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(_wires, _wire);
    canvas.drawPath(_poles, _solid);
  }
}
