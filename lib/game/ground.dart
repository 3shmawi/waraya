import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';

/// The road surface, from the horizon down.
///
/// Graded rather than filled flat: near the horizon it carries the haze the
/// bands fade into, and it darkens toward the bottom of the screen, where the
/// ground is closest and deepest in its own shadow. Tyre ruts run along it
/// because a dirt road in the source photographs always has them.
class GroundPlane extends PositionComponent {
  GroundPlane({
    required this.horizonColor,
    required this.nearColor,
    required this.span,
    int seed = 23,
    super.priority,
  }) : _random = Random(seed);

  /// Colour where the ground meets the horizon; match it to the haze.
  final Color horizonColor;

  /// Colour at the bottom of the screen, where the ground is nearest.
  final Color nearColor;

  final double span;
  final Random _random;

  static const double _bottom = WarayaConfig.worldHeight * 2;

  late final Rect _rect = Rect.fromLTRB(
    -span / 2,
    WarayaConfig.horizonY,
    span / 2,
    _bottom,
  );

  late final Paint _paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, WarayaConfig.horizonY),
      Offset(0, WarayaConfig.worldHeight * 1.05),
      [horizonColor, nearColor],
    );

  final Path _ruts = Path();
  late final Paint _rutPaint = Paint()
    ..color = nearColor.withValues(alpha: 0.30);

  @override
  void onLoad() {
    // Long shallow ruts, thinner and shorter further back so they read as
    // receding rather than as stripes.
    for (var i = 0; i < 260; i++) {
      final depth = _random.nextDouble();
      final y = WarayaConfig.horizonY + depth * 140;
      final length = 120 + depth * 620 * _random.nextDouble();
      final thickness = 1.5 + depth * 6;
      final x = -span / 2 + _random.nextDouble() * span;
      _ruts.addOval(
        Rect.fromCenter(center: Offset(x, y), width: length, height: thickness),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(_rect, _paint);
    canvas.drawPath(_ruts, _rutPaint);
  }
}

/// Weeds, tufts and stones scattered along the roadside.
///
/// These are the only things in the scene at the character's own depth, so
/// they are the only ones that move at the character's own speed. Without them
/// everything that scrolls is far away and walking reads as standing still on
/// a moving backdrop.
class GroundDetail extends PositionComponent {
  GroundDetail({
    required this.color,
    required this.span,
    required this.baseY,
    this.scale2 = 1.0,
    this.density = 340,
    int seed = 29,
    super.priority,
  }) : _random = Random(seed);

  final Color color;
  final double span;

  /// World y the clumps stand on.
  final double baseY;

  /// Overall size multiplier; the nearest row is drawn larger.
  final double scale2;

  /// Average world units between clumps.
  final double density;

  final Random _random;

  late final Paint _paint = Paint()..color = color;
  final Path _path = Path();

  double _between(double a, double b) => a + _random.nextDouble() * (b - a);

  @override
  void onLoad() {
    for (
      var x = -span / 2;
      x < span / 2;
      x += _between(density * 0.4, density * 1.6)
    ) {
      if (_random.nextDouble() < 0.25) {
        _stone(x, _between(4, 11) * scale2);
      } else {
        _tuft(x, _between(14, 34) * scale2);
      }
    }
  }

  /// A clump of weeds: blades fanning up and outward from one point.
  void _tuft(double x, double height) {
    final blades = 5 + _random.nextInt(6);
    for (var i = 0; i < blades; i++) {
      final lean = _between(-0.9, 0.9);
      final h = height * _between(0.55, 1.0);
      final tipX = x + lean * h;
      final half = max(0.7, h * 0.07);
      _path
        ..moveTo(x - half, baseY)
        ..quadraticBezierTo(
          x + lean * h * 0.3,
          baseY - h * 0.7,
          tipX,
          baseY - h,
        )
        ..quadraticBezierTo(
          x + lean * h * 0.3,
          baseY - h * 0.65,
          x + half,
          baseY,
        )
        ..close();
    }
  }

  void _stone(double x, double size) {
    _path.addOval(
      Rect.fromCenter(
        center: Offset(x, baseY - size * 0.35),
        width: size * _between(1.4, 2.4),
        height: size,
      ),
    );
  }

  @override
  void render(Canvas canvas) => canvas.drawPath(_path, _paint);
}
