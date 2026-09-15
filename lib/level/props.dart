import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../shadow/shadow_recorder.dart';
import 'level.dart';

/// Every immovable block in one component. They never change within a level,
/// so there is no reason for each to carry its own transform.
class Blocks extends PositionComponent {
  Blocks(this.rects, {super.priority = -10});

  final List<Rect> rects;

  final Paint _fill = Paint()..color = Palette.blockFill;
  final Paint _top = Paint()..color = Palette.blockTop;
  final Paint _edge = Paint()
    ..color = Palette.blockEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    for (final rect in rects) {
      canvas.drawRect(rect, _fill);
      // A lighter cap on the standable face, so "you can land here" reads
      // without any art.
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 6), _top);
      canvas.drawRect(rect, _edge);
    }
  }
}

/// A plate. Held down by any body resting on it — the player's or, crucially,
/// the shadow's.
class PressurePlate extends PositionComponent {
  PressurePlate(this.spec, {super.priority = -6});

  final PlateSpec spec;

  bool pressedByPlayer = false;
  bool pressedByShadow = false;

  bool get isPressed => pressedByPlayer || pressedByShadow;

  /// Id of the door this plate holds open.
  String get opens => spec.opens;

  Rect get trigger => spec.trigger;

  void reset() {
    pressedByPlayer = false;
    pressedByShadow = false;
  }

  @override
  void render(Canvas canvas) {
    final rect = isPressed ? spec.area.translate(0, 6) : spec.area;
    canvas.drawRect(
      rect,
      Paint()..color = isPressed ? Palette.plateDown : Palette.plateUp,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = Palette.blockEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// A door. Open only while its plate is held.
class Door extends PositionComponent {
  Door(this.spec, {super.priority = -6});

  final DoorSpec spec;

  /// How fast it travels, in fractions of its own height per second. Not a
  /// feel decision — it just needs to be visibly a door opening rather than a
  /// wall blinking out of existence.
  static const double _speed = 3;

  bool wantsOpen = false;

  double _open = 0;
  double get openFraction => _open;

  String get id => spec.id;

  /// Solid until it is nearly all the way up, so squeezing through a door
  /// that is still closing is not a thing.
  bool get isSolid => _open < 0.9;

  Rect get bounds => spec.closed.translate(0, -spec.closed.height * _open);

  void reset() {
    _open = 0;
    // Also the request, or the door creeps open for one frame after a reload
    // because the plate was still held when everything was put back.
    wantsOpen = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _open = (_open + (wantsOpen ? _speed : -_speed) * dt).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(bounds, Paint()..color = Palette.doorColor);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = Palette.blockEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// A square that fills in when the player reaches it.
///
/// With [endsLevel] it is the way out; without, it is a marker — something
/// worth reaching that does not finish anything, which is how the tuning
/// bench shows its two targets without becoming a level to be won.
class Goal extends PositionComponent {
  Goal({required this.area, this.endsLevel = true, super.priority = -6});

  final Rect area;
  final bool endsLevel;
  bool reached = false;

  void reset() => reached = false;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      area,
      Paint()
        ..color = reached ? Palette.goalReached : Palette.goalIdle
        ..style = reached ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// The path the shadow is about to walk — literally the unplayed contents of
/// the buffer.
///
/// A debug toggle the plan was least sure about: seeing the future makes the
/// mechanic instantly legible, and may also delete the puzzle. That is a
/// question for playing, which is why it is a switch and not a decision.
class ShadowTrail extends PositionComponent {
  ShadowTrail({
    required this.recorder,
    required this.enabled,
    super.priority = 80,
  });

  final ShadowRecorder recorder;
  final ValueGetter<bool> enabled;

  final Paint _line = Paint()
    ..color = Palette.trailColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// Every buffered position, oldest first, lifted from the feet to roughly
  /// the body's middle so the line reads as a route rather than as scuffs on
  /// the floor.
  ///
  /// Every one of them, not every sixth. Subsampling looked like a free
  /// saving and was not: the buffer shifts by one entry per tick, so "every
  /// sixth" picks a different six each tick and the whole line shimmers, with
  /// the ends jumping a tenth of a second's travel back and forth.
  Iterable<Offset> points() =>
      recorder.pending.map((s) => Offset(s.x, s.y - 48));

  @override
  void render(Canvas canvas) {
    if (!enabled()) return;
    final trail = points().toList(growable: false);
    if (trail.isEmpty) return;

    final path = Path()..moveTo(trail.first.dx, trail.first.dy);
    for (var i = 1; i < trail.length; i++) {
      path.lineTo(trail[i].dx, trail[i].dy);
    }
    canvas.drawPath(path, _line);

    // Where the shadow appears next, so the head of the queue is obvious.
    canvas.drawCircle(trail.first, 5, _line);
  }
}
