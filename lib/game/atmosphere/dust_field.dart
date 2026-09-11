import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Wind-blown dust, in a few depth layers.
///
/// It lives in the viewport rather than the world on purpose: airborne dust is
/// carried by the wind, not fixed to the ground, so it should not slide past at
/// the camera's speed. Depth comes from the layers instead — far motes are
/// small, faint and slow, near ones large, brighter and quick.
///
/// Each layer is one `drawRawPoints` call, so the whole field costs a handful
/// of draws however many motes it holds.
class DustField extends PositionComponent {
  DustField({
    required this.color,
    this.layers = 3,
    this.motesPerLayer = 240,
    int seed = 41,
    super.priority,
  }) : _random = Random(seed);

  final Color color;
  final int layers;
  final int motesPerLayer;

  final Random _random;

  final List<Float32List> _points = [];
  final List<Paint> _paints = [];
  final List<double> _speeds = [];
  final List<double> _bobs = [];
  double _elapsed = 0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    if (_points.isEmpty) _build();
  }

  void _build() {
    for (var layer = 0; layer < layers; layer++) {
      // 0 is the furthest layer, layers - 1 the nearest.
      final depth = layers == 1 ? 1.0 : layer / (layers - 1);
      final data = Float32List(motesPerLayer * 2);
      for (var i = 0; i < motesPerLayer; i++) {
        data[i * 2] = _random.nextDouble();
        data[i * 2 + 1] = _random.nextDouble();
      }
      _points.add(data);
      _paints.add(
        Paint()
          ..color = color.withValues(alpha: 0.05 + depth * 0.16)
          ..strokeWidth = 1.0 + depth * 2.6
          ..strokeCap = StrokeCap.round,
      );
      _speeds.add(0.018 + depth * 0.085);
      _bobs.add(0.004 + depth * 0.012);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    for (var layer = 0; layer < _points.length; layer++) {
      final data = _points[layer];
      final step = _speeds[layer] * dt;
      for (var i = 0; i < data.length; i += 2) {
        // Fractions of the viewport, so a resize never strands a mote.
        var x = data[i] - step;
        if (x < 0) x += 1;
        data[i] = x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (var layer = 0; layer < _points.length; layer++) {
      final data = _points[layer];
      final bob = _bobs[layer];
      final pixels = Float32List(data.length);
      for (var i = 0; i < data.length; i += 2) {
        // The vertical wander is derived rather than stored: dust does not fall
        // so much as swim, and one sine per mote is cheaper than a velocity.
        final wander = sin(_elapsed * 0.6 + data[i] * 40 + layer) * bob;
        pixels[i] = data[i] * size.x;
        pixels[i + 1] = (data[i + 1] + wander) * size.y;
      }
      canvas.drawRawPoints(PointMode.points, pixels, _paints[layer]);
    }
  }
}
