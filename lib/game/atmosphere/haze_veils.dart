import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Veils of hanging dust drifting across the frame.
///
/// The strongest of the shader-free atmosphere tricks for this scene: a dust
/// storm is mostly this, air thick enough to hide the middle distance and then
/// let it back.
///
/// One soft blob is baked at load and then drawn a dozen times at different
/// sizes, speeds and opacities. Blurring per frame is far too slow — that
/// mistake already cost the ground its frame rate once — but drawing a
/// pre-blurred image is a single cheap draw each.
class HazeVeils extends PositionComponent {
  HazeVeils({
    required this.color,
    this.count = 11,
    this.maxOpacity = 0.20,
    int seed = 53,
    super.priority,
  }) : _random = Random(seed);

  final Color color;
  final int count;

  /// Opacity of the densest veil.
  final double maxOpacity;

  final Random _random;

  ui.Image? _veil;
  final List<_Veil> _veils = [];

  Future<ui.Image> _bakeVeil() {
    const w = 512;
    const h = 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // A wide soft smear, blurred well past its own edges so it has no border.
    canvas.drawOval(
      Rect.fromLTWH(-30, 22, w + 60, h - 44),
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34)
        ..color = const Color(0xFFFFFFFF),
    );
    return recorder.endRecording().toImage(w, h);
  }

  @override
  Future<void> onLoad() async {
    _veil = await _bakeVeil();
    for (var i = 0; i < count; i++) {
      final depth = i / max(1, count - 1);
      _veils.add(
        _Veil(
          x: _random.nextDouble(),
          // Banked around the horizon, where hanging dust actually sits.
          y: 0.34 + _random.nextDouble() * 0.46,
          width: 0.45 + _random.nextDouble() * 1.1,
          height: 0.06 + _random.nextDouble() * 0.20,
          // Nearer veils are denser and quicker, which is the only depth cue
          // a flat smear gets.
          opacity: maxOpacity * (0.25 + depth * 0.75) * _random.nextDouble(),
          speed: 0.008 + depth * 0.045,
          color: color,
        ),
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final veil in _veils) {
      veil.x -= veil.speed * dt;
      if (veil.x < -veil.width) veil.x += 1 + veil.width * 2;
    }
  }

  @override
  void render(Canvas canvas) {
    final image = _veil;
    if (image == null) return;
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    for (final veil in _veils) {
      final w = veil.width * size.x;
      final h = veil.height * size.y;
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(veil.x * size.x, veil.y * size.y - h / 2, w, h),
        veil.paint,
      );
    }
  }
}

class _Veil {
  _Veil({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.opacity,
    required this.speed,
    required Color color,
  }) : paint = Paint()
         ..filterQuality = FilterQuality.low
         ..colorFilter = ColorFilter.mode(
           color.withValues(alpha: opacity),
           BlendMode.srcIn,
         );

  final Paint paint;

  double x;
  final double y;
  final double width;
  final double height;
  final double opacity;
  final double speed;
}
