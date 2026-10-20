import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'level.dart';

/// The old lift with the folding iron gate (`Level.lifts`, on the bench): it
/// goes to whichever floor's button was stepped on last ([LiftSpec]).
///
/// Like the basket it does not move itself — the game moves it, first thing
/// in a frame, and carries whoever is standing in it by exactly as far
/// (`LevelGame._liftCabins`). Unlike the basket nothing holds it: a call is
/// an arrival, the way a key's is, and it stands until the next one.
///
/// Drawn as the cage every old Cairo building has in its stairwell: a floor
/// you stand on, with the warm rim every floor in the game has; a lattice
/// of thin lit bars round it that folds shut while it travels; and its cable
/// going up out of the view, lit like a lamp's cord. No roof and no solid
/// sides — a dark box in reach is a thing the player tries to climb.
class Lift extends PositionComponent {
  Lift(this.spec, {this.look = LevelLook.greyBox, super.priority = -6})
    : _goingUp = spec.startsUp,
      _raised = spec.startsUp ? spec.rise : 0;

  final LiftSpec spec;
  final LevelLook look;

  String get id => spec.id;

  bool _goingUp;
  double _raised;

  /// Which floor it was called to last: up or down.
  bool get calledUp => _goingUp;

  /// How far above the bottom floor it is, from 0 to [LiftSpec.rise].
  double get raised => _raised;

  /// Between floors. Its gate is shut.
  bool get moving => _raised != (_goingUp ? spec.rise : 0);

  /// The cabin's floor, where it is now.
  Rect get bounds => spec.area.translate(0, -_raised);

  /// What a body bumps into besides the floor: the gate, while it travels.
  List<Rect> get gates {
    if (!moving) return const [];
    final floor = bounds;
    final top = floor.top - LiftSpec.gateHeight;
    return [
      Rect.fromLTRB(floor.left, top, floor.left + 4, floor.top),
      Rect.fromLTRB(floor.right - 4, top, floor.right, floor.top),
    ];
  }

  bool _youOnDown = false;
  bool _youOnUp = false;
  bool _pastOnDown = false;
  bool _pastOnUp = false;

  /// Feeds who is on each button this frame, and says whether a call
  /// changed which floor it is going to.
  ///
  /// Arrivals, not presence, exactly as a key counts them. Your pasts first
  /// and you last, so if you and your past arrive on the same frame the call
  /// is yours — the one the player can see being made.
  bool touch({
    required bool youDown,
    required bool youUp,
    required bool pastDown,
    required bool pastUp,
  }) {
    var up = _goingUp;
    if (pastDown && !_pastOnDown) up = false;
    if (pastUp && !_pastOnUp) up = true;
    if (youDown && !_youOnDown) up = false;
    if (youUp && !_youOnUp) up = true;
    _youOnDown = youDown;
    _youOnUp = youUp;
    _pastOnDown = pastDown;
    _pastOnUp = pastUp;
    if (up == _goingUp) return false;
    _goingUp = up;
    return true;
  }

  /// Moves it for [dt] seconds towards the floor it was called to, and says
  /// how far it went in world y — up negative — for whoever rides it.
  double lift(double dt) {
    final target = _goingUp ? spec.rise : 0.0;
    final step = LiftSpec.speed * dt;
    final before = _raised;
    _raised = _raised < target
        ? min(target, _raised + step)
        : max(target, _raised - step);
    return before - _raised;
  }

  /// Whether a body with its feet at [feet] and its middle at [x] is
  /// standing in it — the basket's test, the same half body of grace.
  bool carries({required double x, required double feet}) {
    final floor = bounds;
    return (feet - floor.top).abs() <= 2 &&
        x + 22 > floor.left &&
        x - 22 < floor.right;
  }

  void reset() {
    _goingUp = spec.startsUp;
    _raised = spec.startsUp ? spec.rise : 0;
    _youOnDown = false;
    _youOnUp = false;
    _pastOnDown = false;
    _pastOnUp = false;
  }

  @override
  void render(Canvas canvas) {
    final lit = look == LevelLook.silhouette;
    final floor = bounds;
    final bars = Paint()
      ..color = lit ? const Color(0x59FFE7B0) : const Color(0x80FFFFFF)
      ..strokeWidth = 1.5;

    if (!lit) {
      // The bench measures: the top floor's cabin as an outline.
      canvas.drawRect(
        spec.up,
        Paint()
          ..color = const Color(0x40FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // The cable, up out of the view.
    canvas.drawRect(
      Rect.fromLTRB(
        floor.center.dx - 1,
        floor.top - 900,
        floor.center.dx + 1,
        floor.top - LiftSpec.gateHeight,
      ),
      Paint()..color = lit ? const Color(0x66FFE7B0) : const Color(0x99FFFFFF),
    );

    // The cage: a thin bar along the top, and the gate on each side —
    // folded into a few uprights at the corner while it waits, a lattice of
    // crossed bars while it travels.
    final top = floor.top - LiftSpec.gateHeight;
    canvas.drawLine(Offset(floor.left, top), Offset(floor.right, top), bars);
    for (final (edge, inward) in [(floor.left, 1.0), (floor.right, -1.0)]) {
      if (moving) {
        const cells = 5;
        const cell = LiftSpec.gateHeight / cells;
        for (var i = 0; i < cells; i++) {
          final y0 = top + i * cell;
          canvas.drawLine(
            Offset(edge, y0),
            Offset(edge + inward * 10, y0 + cell),
            bars,
          );
          canvas.drawLine(
            Offset(edge + inward * 10, y0),
            Offset(edge, y0 + cell),
            bars,
          );
        }
      }
      for (var k = 0; k < (moving ? 2 : 3); k++) {
        final x = edge + inward * k * 4;
        canvas.drawLine(Offset(x, top), Offset(x, floor.top), bars);
      }
    }

    // The floor, which is the only part you stand on.
    canvas.drawRect(
      floor,
      Paint()..color = lit ? SilhouettePalette.blockFill : Palette.blockFill,
    );
    canvas.drawRect(
      Rect.fromLTWH(floor.left, floor.top, floor.width, 2),
      Paint()..color = lit ? SilhouettePalette.blockTop : Palette.blockTop,
    );

    _button(canvas, spec.callDown, up: false, lit: lit);
    _button(canvas, spec.callUp, up: true, lit: lit);
  }

  /// A call button: a plate's housing with its arrow on it, the arrow lit
  /// while the cabin is going (or gone) that way.
  void _button(
    Canvas canvas,
    Rect area, {
    required bool up,
    required bool lit,
  }) {
    canvas.drawRect(
      area,
      Paint()..color = lit ? SilhouettePalette.plateUp : Palette.plateDown,
    );
    final on = _goingUp == up;
    final c = Offset(area.center.dx, area.top - 9);
    const r = 6.0;
    final arrow = Path();
    if (up) {
      arrow
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + r, c.dy + r * 0.7)
        ..lineTo(c.dx - r, c.dy + r * 0.7);
    } else {
      arrow
        ..moveTo(c.dx, c.dy + r)
        ..lineTo(c.dx + r, c.dy - r * 0.7)
        ..lineTo(c.dx - r, c.dy - r * 0.7);
    }
    arrow.close();
    final color = lit ? const Color(0xFFFFE7B0) : const Color(0xFFF4F4F4);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = on ? color : color.withValues(alpha: 0.6)
        ..style = on ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }
}
