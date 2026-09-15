import 'dart:math';

import 'package:flutter/material.dart';

import 'endless.dart';

/// Poles and the wire sagging between them, drawn rather than photographed.
///
/// The photographed wires band was cut from a frame where the wires run
/// diagonally, so every tile boundary chopped them mid-span and the repeat read
/// as broken cable. No seam blend fixes that: the wire enters one edge at a
/// different height and angle than it leaves the other.
///
/// Drawing them is not a compromise here. A wire at this scale is a two-pixel
/// dark line, so a photograph contributes no texture worth keeping, while a
/// catenary computed between known poles is continuous forever and costs no
/// download.
///
/// Each pole's height, lean and position come from its own index, so the span
/// between any two of them can be drawn without knowing about the rest.
class PowerLine extends EndlessRow {
  PowerLine({
    required this.color,
    required super.visibleWorldRect,
    required this.baseY,
    super.spacing = 460,
    this.poleHeight = 250,
    super.seed = 11,
    super.priority,
  });

  final Color color;

  /// World y the poles stand on. A parameter rather than the Phase 1 horizon,
  /// because a scene whose ground is somewhere else gets poles hanging in the
  /// air above it.
  final double baseY;

  /// Height of a typical pole above [baseY], in world units.
  final double poleHeight;

  @override
  late final Paint fillPaint = Paint()..color = color;

  @override
  late final Paint strokePaint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round;

  double _heightOf(int index) =>
      poleHeight * (0.9 + noise(index, seed ^ 0x51) * 0.24);

  /// Village poles are rarely plumb; a perfectly upright row reads as a fence.
  double _leanOf(int index) => (noise(index, seed ^ 0x77) - 0.5) * 18;

  double _topOf(int index) => baseY - _heightOf(index);

  @override
  void buildItem(EndlessItem item, int index, double x) {
    final height = _heightOf(index);
    final top = _topOf(index);
    final headX = x + _leanOf(index);

    _pole(item.fill, x, headX, top);
    _crossarm(item.fill, headX, top + height * 0.06);

    if (noise(index, seed ^ 0x9B) < 0.3) {
      _streetLamp(
        item,
        headX,
        top + height * 0.16,
        noise(index, seed ^ 0xA3) < 0.5 ? 1 : -1,
      );
    }

    // The span to the next pole. Every property of it is a function of the
    // index, so neighbouring items always agree on where the wire lands.
    final nextIndex = index + 1;
    final nextX = itemX(nextIndex) + _leanOf(nextIndex);
    final nextTop = _topOf(nextIndex);
    final nextHeight = _heightOf(nextIndex);
    final gap = (nextX - headX).abs();

    // Three strands rather than two: a single pair reads as a fence wire.
    for (final offset in const [0.06, 0.105, 0.15]) {
      final y1 = top + height * offset;
      final y2 = nextTop + nextHeight * offset;
      final sag = gap * (0.09 + noise(index, seed ^ 0xC5) * 0.06);
      item.stroke
        ..moveTo(headX, y1)
        // A quadratic through a control point below both ends approximates the
        // catenary closely enough at this scale.
        ..quadraticBezierTo((headX + nextX) / 2, max(y1, y2) + sag, nextX, y2);
    }
  }

  /// A tapered post, wider at the foot, leaning toward [headX].
  void _pole(Path path, double baseX, double headX, double top) {
    const footHalf = 5.5;
    const headHalf = 3.5;
    path
      ..moveTo(baseX - footHalf, baseY)
      ..lineTo(headX - headHalf, top)
      ..lineTo(headX + headHalf, top)
      ..lineTo(baseX + footHalf, baseY)
      ..close();
  }

  /// The crossarm and the insulator nubs the wires sit on.
  void _crossarm(Path path, double x, double y) {
    path.addRect(Rect.fromLTRB(x - 36, y, x + 36, y + 5));
    for (final dx in const [-27.0, -9.0, 9.0, 27.0]) {
      path.addRect(Rect.fromLTRB(x + dx - 2, y - 6, x + dx + 2, y));
    }
  }

  /// A street lamp on a curved arm, the kind on every second pole in the
  /// source photographs.
  void _streetLamp(EndlessItem item, double x, double y, double side) {
    final reach = 26.0 * side;
    item.stroke
      ..moveTo(x, y)
      ..quadraticBezierTo(x + reach * 0.8, y - 10, x + reach, y - 4);
    item.fill.addOval(
      Rect.fromCenter(center: Offset(x + reach, y - 1), width: 13, height: 7),
    );
  }
}
