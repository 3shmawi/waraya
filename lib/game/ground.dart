import 'dart:math';
import 'dart:typed_data';
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
///
/// A clean gradient is what gives drawn ground away, so three things break it
/// up: a grain texture baked once and tiled as a shader, soft tonal patches so
/// the dirt is not uniformly one colour, and a ragged verge instead of the
/// ruled line a rectangle would leave along the horizon.
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

  final Path _verge = Path();
  late final Paint _vergePaint = Paint()..color = horizonColor;

  ui.Image? _grain;
  Paint? _grainPaint;

  /// Bakes the dirt: broad tonal patches and fine grit, in one tile.
  ///
  /// Both have to be baked. Drawing this many marks per frame is far too slow —
  /// the blurred patches alone took the frame rate to single digits — and drawn
  /// once into an image and tiled through a shader the whole surface costs one
  /// rect per frame.
  ///
  /// The tile is wide rather than square for one reason: at 512 units its
  /// repeat was plainly visible as a grid of blocks across the road. At 2048 a
  /// screen holds well under one tile, and the non-repeating ruts, weeds and
  /// stones drawn over it break up what is left. Only [_height] units of it are
  /// ever on screen, so the patches are kept to the top of the tile.
  Future<ui.Image> _bakeGrain() {
    const width = 2048;
    const height = 512;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = Random(91);

    // Broad patches: dirt is never one flat tone. Kept above row 300 because
    // that is all of the tile the camera ever sees.
    for (var i = 0; i < 300; i++) {
      final lighter = random.nextDouble() < 0.45;
      canvas.drawCircle(
        Offset(random.nextDouble() * width, random.nextDouble() * 300),
        60 + random.nextDouble() * 190,
        Paint()
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 38)
          ..color =
              (lighter ? const Color(0xFFC98F49) : const Color(0xFF000000))
                  .withValues(alpha: 0.03 + random.nextDouble() * 0.045),
      );
    }

    // Then the fine stuff: grit, pebbles, scuffs.
    for (var i = 0; i < 42000; i++) {
      final dark = random.nextDouble() < 0.78;
      canvas.drawCircle(
        Offset(random.nextDouble() * width, random.nextDouble() * height),
        0.3 + random.nextDouble() * 0.9,
        Paint()
          ..color = (dark ? const Color(0xFF000000) : const Color(0xFFD9A05A))
              .withValues(alpha: 0.02 + random.nextDouble() * 0.045),
      );
    }
    return recorder.endRecording().toImage(width, height);
  }

  @override
  Future<void> onLoad() async {
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

    // A ragged verge: small humps of dirt along the horizon so the ground does
    // not meet the treeline along a ruled line.
    _verge.moveTo(-span / 2, WarayaConfig.horizonY + 12);
    for (var x = -span / 2; x < span / 2; x += 14 + _random.nextDouble() * 26) {
      _verge.lineTo(x, WarayaConfig.horizonY - _random.nextDouble() * 7);
    }
    _verge
      ..lineTo(span / 2, WarayaConfig.horizonY + 12)
      ..close();

    _grain = await _bakeGrain();
    _grainPaint = Paint()
      ..filterQuality = FilterQuality.low
      ..shader = ui.ImageShader(
        _grain!,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList(<double>[
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
      );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(_rect, _paint);
    canvas.drawPath(_ruts, _rutPaint);
    canvas.drawPath(_verge, _vergePaint);
    final grain = _grainPaint;
    if (grain != null) {
      canvas.drawRect(_rect, grain);
    }
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
