import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../shadow/shadow_recorder.dart';
import 'lab_scene.dart';

/// Every immovable grey box in one component. They never change, so there is
/// no reason for each to carry its own transform.
class LabBlocks extends PositionComponent {
  LabBlocks({super.priority = -10});

  final Paint _fill = Paint()..color = LabScene.blockFill;
  final Paint _top = Paint()..color = LabScene.blockTop;
  final Paint _edge = Paint()
    ..color = LabScene.blockEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    for (final rect in LabScene.blocking) {
      canvas.drawRect(rect, _fill);
      // A lighter cap on the standable face, so "you can land here" reads
      // without any art.
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 6), _top);
      canvas.drawRect(rect, _edge);
    }
  }
}

/// Test 1's plate. Held down by any body resting on it — the player's or,
/// crucially, the shadow's.
class PressurePlate extends PositionComponent {
  PressurePlate({super.priority = -6});

  bool pressedByPlayer = false;
  bool pressedByShadow = false;

  bool get isPressed => pressedByPlayer || pressedByShadow;

  @override
  void render(Canvas canvas) {
    final rect = isPressed ? LabScene.plate.translate(0, 6) : LabScene.plate;
    canvas.drawRect(
      rect,
      Paint()..color = isPressed ? LabScene.plateDown : LabScene.plateUp,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = LabScene.blockEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// Test 1's door. Open only while the plate is held.
class LabDoor extends PositionComponent {
  LabDoor({super.priority = -6});

  /// How fast it travels, in fractions of its own height per second. Not a
  /// feel decision — it just needs to be visibly a door opening rather than a
  /// wall blinking out of existence.
  static const double _speed = 3;

  bool wantsOpen = false;

  double _open = 0;
  double get openFraction => _open;

  /// Solid until it is nearly all the way up, so squeezing through a door
  /// that is still closing is not a thing.
  bool get isSolid => _open < 0.9;

  Rect get bounds => LabScene.door.translate(0, -LabScene.door.height * _open);

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
    canvas.drawRect(bounds, Paint()..color = LabScene.doorColor);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = LabScene.blockEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// A square that fills in when the player reaches it.
///
/// Not a level-completion system — the plan forbids building one here. It is
/// the cheapest possible answer to "did that work?", so the three Friday tests
/// have a moment to point at.
class LabGoal extends PositionComponent {
  LabGoal({required this.area, super.priority = -6});

  final Rect area;
  bool reached = false;

  void reset() => reached = false;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      area,
      Paint()
        ..color = reached ? LabScene.goalReached : LabScene.goalIdle
        ..style = reached ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// The path the shadow is about to walk — literally the unplayed contents of
/// the buffer.
///
/// This is the debug toggle the plan is least sure about: seeing the future
/// makes the mechanic instantly legible, and may also delete the puzzle. That
/// is a question for Friday, which is why it is a switch and not a decision.
class ShadowTrail extends PositionComponent {
  ShadowTrail({
    required this.recorder,
    required this.enabled,
    super.priority = 80,
  });

  final ShadowRecorder recorder;
  final ValueGetter<bool> enabled;

  final Paint _line = Paint()
    ..color = LabScene.trailColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// Every buffered position, oldest first, lifted from the feet to roughly
  /// the body's middle so the line reads as a route rather than as scuffs on
  /// the floor.
  ///
  /// Every one of them, not every sixth. Subsampling looked like a free
  /// saving and was not: the buffer shifts by one entry per tick, so "every
  /// sixth" picks a different six each tick and the whole line shimmers, with
  /// the ends jumping a tenth of a second's travel back and forth. A few
  /// hundred `lineTo`s are nothing next to that.
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
