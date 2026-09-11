import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'endless.dart';

/// The road surface, from the horizon down.
///
/// Graded rather than filled flat: near the horizon it carries the haze the
/// bands fade into, and it darkens toward the bottom of the screen, where the
/// ground is closest and deepest in its own shadow.
///
/// A clean gradient is what gives drawn ground away, so two things break it up:
/// a grain texture baked once and tiled as a shader, and a ragged verge instead
/// of the ruled line a rectangle would leave along the horizon. Both the rect
/// and the verge follow the camera, so the road has no end.
class GroundPlane extends PositionComponent {
  GroundPlane({
    required this.horizonColor,
    required this.nearColor,
    required this.visibleWorldRect,
    super.priority,
  });

  /// Colour where the ground meets the horizon; match it to the haze.
  final Color horizonColor;

  /// Colour at the bottom of the screen, where the ground is nearest.
  final Color nearColor;

  final ValueGetter<Rect> visibleWorldRect;

  static const double _bottom = WarayaConfig.worldHeight * 2;

  late final Paint _paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, WarayaConfig.horizonY),
      Offset(0, WarayaConfig.worldHeight * 1.05),
      [horizonColor, nearColor],
    );

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
  /// stones drawn over it break up what is left.
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
    _grain = await _bakeGrain();
    _grainPaint = Paint()
      ..filterQuality = FilterQuality.low
      ..shader = ui.ImageShader(
        _grain!,
        TileMode.repeated,
        TileMode.repeated,
        Float64List.fromList(<double>[
          1, 0, 0, 0, //
          0, 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1, //
        ]),
      );
  }

  @override
  void render(Canvas canvas) {
    final view = visibleWorldRect();
    final rect = Rect.fromLTRB(
      view.left - 200,
      WarayaConfig.horizonY,
      view.right + 200,
      _bottom,
    );
    canvas.drawRect(rect, _paint);

    // A ragged verge, rebuilt across whatever the camera is looking at. The
    // hump heights come from the slot index, so the same stretch of road always
    // has the same edge.
    const step = 18.0;
    final first = (rect.left / step).floor();
    final last = (rect.right / step).ceil();
    final verge = Path()..moveTo(first * step, WarayaConfig.horizonY + 12);
    for (var i = first; i <= last; i++) {
      verge.lineTo(i * step, WarayaConfig.horizonY - noise(i, 0x3B) * 7);
    }
    verge
      ..lineTo(last * step, WarayaConfig.horizonY + 12)
      ..close();
    canvas.drawPath(verge, _vergePaint);

    final grain = _grainPaint;
    if (grain != null) canvas.drawRect(rect, grain);
  }
}

/// Everything loose on the road: weeds, stones, twigs, pebble scatters and the
/// ruts worn along it.
///
/// These are the only things in the scene at the character's own depth, so they
/// are the only ones that move at the character's own speed. Without them
/// everything that scrolls is far away and walking reads as standing still on a
/// moving backdrop.
class GroundDetail extends EndlessRow {
  GroundDetail({
    required this.color,
    required super.visibleWorldRect,
    required this.baseY,
    this.sizeScale = 1.0,
    super.spacing = 120,
    super.seed = 29,
    super.priority,
  });

  final Color color;

  /// World y the clumps stand on.
  final double baseY;

  /// Overall size multiplier; the nearest row is drawn larger.
  final double sizeScale;

  @override
  late final Paint fillPaint = Paint()..color = color;

  double _n(int index, int salt) => noise(index, seed ^ salt);

  @override
  void buildItem(EndlessItem item, int index, double x) {
    final kind = _n(index, 0x11);
    if (kind < 0.34) {
      _tuft(item.fill, index, x, (14 + _n(index, 0x21) * 22) * sizeScale);
    } else if (kind < 0.48) {
      _stone(item.fill, index, x, (4 + _n(index, 0x31) * 8) * sizeScale);
    } else if (kind < 0.62) {
      _scatter(item.fill, index, x);
    } else if (kind < 0.74) {
      _twig(item.fill, index, x, (18 + _n(index, 0x41) * 26) * sizeScale);
    } else if (kind < 0.84) {
      _rut(item.fill, index, x);
    } else if (kind < 0.93) {
      _tyrePair(item.fill, index, x);
    } else {
      _scrap(item.fill, index, x, (7 + _n(index, 0x19) * 11) * sizeScale);
    }
  }

  /// A clump of weeds: blades fanning up and outward from one point.
  void _tuft(Path path, int index, double x, double height) {
    final blades = 5 + (_n(index, 0x51) * 6).floor();
    for (var i = 0; i < blades; i++) {
      final lean = (_n(index * 31 + i, 0x61) - 0.5) * 1.8;
      final h = height * (0.55 + _n(index * 31 + i, 0x71) * 0.45);
      final tipX = x + lean * h;
      final half = max(0.7, h * 0.07);
      path
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

  void _stone(Path path, int index, double x, double size) {
    path.addOval(
      Rect.fromCenter(
        center: Offset(x, baseY - size * 0.35),
        width: size * (1.4 + _n(index, 0x81)),
        height: size,
      ),
    );
  }

  /// A handful of pebbles rather than one stone; roads are mostly this.
  void _scatter(Path path, int index, double x) {
    final count = 4 + (_n(index, 0x91) * 7).floor();
    for (var i = 0; i < count; i++) {
      final dx = (_n(index * 17 + i, 0xA1) - 0.5) * 70 * sizeScale;
      final dy = _n(index * 17 + i, 0xB1) * 10 * sizeScale;
      final r = (0.9 + _n(index * 17 + i, 0xC1) * 2.4) * sizeScale;
      path.addOval(
        Rect.fromCenter(
          center: Offset(x + dx, baseY + dy),
          width: r * 2.2,
          height: r * 1.3,
        ),
      );
    }
  }

  /// A dry twig or a broken palm frond lying where it fell.
  void _twig(Path path, int index, double x, double length) {
    final tilt = (_n(index, 0xD1) - 0.5) * 0.5;
    final thickness = max(0.9, length * 0.035);
    final dx = cos(tilt) * length;
    final dy = sin(tilt) * length * 0.35;
    path
      ..moveTo(x, baseY - thickness)
      ..lineTo(x + dx, baseY + dy - thickness * 0.4)
      ..lineTo(x + dx, baseY + dy + thickness * 0.4)
      ..lineTo(x, baseY + thickness)
      ..close();
    // A side branch, which is what makes it read as a twig and not a nail.
    final bx = x + dx * (0.4 + _n(index, 0xE1) * 0.3);
    path
      ..moveTo(bx, baseY)
      ..lineTo(bx + dx * 0.22, baseY - length * 0.16)
      ..lineTo(bx + dx * 0.26, baseY - length * 0.15)
      ..close();
  }

  /// The pair of tracks a tuk-tuk or a motorbike leaves, close together and
  /// running the length of the road.
  void _tyrePair(Path path, int index, double x) {
    final length = (260 + _n(index, 0x23) * 620) * sizeScale;
    final gap = (7 + _n(index, 0x29) * 13) * sizeScale;
    final y = baseY + _n(index, 0x2B) * 22 * sizeScale;
    for (final dy in [-gap / 2, gap / 2]) {
      path.addOval(
        Rect.fromCenter(
          center: Offset(x, y + dy),
          width: length,
          height: (1.6 + _n(index, 0x2F) * 2.4) * sizeScale,
        ),
      );
    }
  }

  /// A scrap of cloth or plastic, flattened into the dirt. There is one every
  /// few metres of every road in the source photographs.
  void _scrap(Path path, int index, double x, double size) {
    final y = baseY + _n(index, 0x37) * 16 * sizeScale;
    const points = 7;
    for (var i = 0; i <= points; i++) {
      final a = i / points * pi * 2;
      final r = size * (0.45 + _n(index * 13 + i, 0x3D) * 0.75);
      final px = x + cos(a) * r * 1.9;
      final py = y + sin(a) * r * 0.45;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
  }

  /// A wheel rut: long, shallow, and lying flat on the surface.
  void _rut(Path path, int index, double x) {
    final length = (180 + _n(index, 0xF1) * 520) * sizeScale;
    final thickness = (2 + _n(index, 0x13) * 5) * sizeScale;
    path.addOval(
      Rect.fromCenter(
        center: Offset(x, baseY + _n(index, 0x17) * 26 * sizeScale),
        width: length,
        height: thickness,
      ),
    );
  }
}
