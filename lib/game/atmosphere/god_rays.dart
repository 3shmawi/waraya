import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Shafts of light fanning down from the brightest part of the sky.
///
/// The whole fan is baked into one blurred image and then drawn once per frame
/// under an additive blend. Drawing the wedges directly, as the first version
/// did, gave them hard geometric edges that read as cones rather than light —
/// and softening them per frame would have meant blurring every frame, which
/// already cost the ground its frame rate once.
///
/// Worth knowing what this is doing: a dust storm scatters light rather than
/// beaming it, so there is no sun disc here to justify hard shafts. [strength]
/// is deliberately low, and setting it to zero is a defensible decision for
/// this scene rather than a missing feature.
class GodRays extends PositionComponent {
  GodRays({
    required this.color,
    this.strength = 0.07,
    this.count = 6,
    this.origin = const Offset(0.64, -0.28),
    int seed = 67,
    super.priority,
  }) : _random = Random(seed);

  final Color color;

  /// Opacity of the fan at its brightest.
  final double strength;

  final int count;

  /// Where the shafts come from, in fractions of the viewport. Above the top
  /// edge, so the source itself is never in frame.
  final Offset origin;

  final Random _random;

  ui.Image? _fan;
  Vector2? _bakedFor;
  double _elapsed = 0;
  late final Paint _paint = Paint()
    ..blendMode = BlendMode.plus
    ..filterQuality = FilterQuality.low;

  Future<ui.Image> _bakeFan(int w, int h) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final start = Offset(origin.dx * w, origin.dy * h);
    final reach = sqrt(w * w + h * h) * 1.2;

    for (var i = 0; i < count; i++) {
      final t = count == 1 ? 0.5 : i / (count - 1);
      final angle =
          pi / 2 + (t - 0.5) * 0.7 + (_random.nextDouble() - 0.5) * 0.08;
      final spread = 0.03 + _random.nextDouble() * 0.05;
      final opacity = 0.4 + _random.nextDouble() * 0.6;

      final a = angle - spread;
      final b = angle + spread;
      final end = start + Offset(cos(angle), sin(angle)) * reach;

      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx + cos(a) * reach, start.dy + sin(a) * reach)
          ..lineTo(start.dx + cos(b) * reach, start.dy + sin(b) * reach)
          ..close(),
        Paint()
          // Generous blur: this is what turns a wedge into a shaft.
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.022)
          ..shader = ui.Gradient.linear(
            start,
            end,
            [
              const Color(0xFFFFFFFF).withValues(alpha: opacity),
              const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.45),
              const Color(0x00FFFFFF),
            ],
            const [0.0, 0.4, 1.0],
          ),
      );
    }
    return recorder.endRecording().toImage(w, h);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    if (size.x < 1 || size.y < 1) return;
    if (_bakedFor == size) return;
    _bakedFor = size.clone();
    // Half resolution: the fan is nothing but soft gradients, so nobody can
    // tell, and it quarters the bake.
    _bakeFan((size.x / 2).round(), (size.y / 2).round()).then((image) {
      _fan?.dispose();
      _fan = image;
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final fan = _fan;
    if (fan == null || strength <= 0) return;
    // One slow breath over the whole fan, so the light is never quite static.
    final alpha = strength * (0.78 + 0.22 * sin(_elapsed * 0.15));
    canvas.drawImageRect(
      fan,
      Rect.fromLTWH(0, 0, fan.width.toDouble(), fan.height.toDouble()),
      size.toRect(),
      _paint
        ..colorFilter = ColorFilter.mode(
          color.withValues(alpha: alpha),
          BlendMode.modulate,
        ),
    );
  }

  @override
  void onRemove() {
    _fan?.dispose();
    super.onRemove();
  }
}
