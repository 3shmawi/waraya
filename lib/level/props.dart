import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../game/config.dart';
import '../shadow/shadow_recorder.dart';
import 'level.dart';

/// Every immovable block in one component. They never change within a level,
/// so there is no reason for each to carry its own transform.
class Blocks extends PositionComponent {
  Blocks(
    this.rects, {
    this.look = LevelLook.greyBox,
    this.view,
    super.priority = -10,
  });

  final List<Rect> rects;
  final LevelLook look;

  /// The camera's rectangle, when the ground needs to reach the edge of it.
  /// Null on the bench, where a level ending in mid-air is just a level ending
  /// in mid-air.
  final ValueGetter<Rect>? view;

  bool get _lit => look == LevelLook.silhouette;

  late final Paint _fill = Paint()
    ..color = _lit ? SilhouettePalette.blockFill : Palette.blockFill;
  late final Paint _top = Paint()
    ..color = _lit ? SilhouettePalette.blockTop : Palette.blockTop;
  late final Paint _edge = Paint()
    ..color = _lit ? SilhouettePalette.blockEdge : Palette.blockEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// The ground, drawn out past the edge of the screen.
  ///
  /// A level's floor is a rectangle with ends, and in the lit scene those ends
  /// are a hole: walk far enough and the sunset shows through the ground you
  /// are standing on. Any slab that already falls off the bottom of the world
  /// is ground rather than a ledge, so its *fill* is stretched to the camera's
  /// edges. Only the fill — the warm cap stays on the real rectangle, so the
  /// lit edge is still exactly where the floor stops being standable.
  Rect _fillFor(Rect rect, Rect? visible) {
    if (!_lit || visible == null || rect.bottom < WarayaConfig.worldHeight) {
      return rect;
    }
    return Rect.fromLTRB(
      min(rect.left, visible.left - 64),
      rect.top,
      max(rect.right, visible.right + 64),
      rect.bottom,
    );
  }

  @override
  void render(Canvas canvas) {
    final visible = view?.call();
    for (final rect in rects) {
      canvas.drawRect(_fillFor(rect, visible), _fill);
      // A lighter cap on the standable face, so "you can land here" reads
      // without any art. Lit from behind it is doing more than that: it is
      // the only thing separating one black shape from the next.
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, _lit ? 3 : 6),
        _top,
      );
      canvas.drawRect(rect, _edge);
    }
  }
}

/// A plate. Held down by any body resting on it — the player's or, crucially,
/// the shadow's.
class PressurePlate extends PositionComponent {
  PressurePlate(this.spec, {this.look = LevelLook.greyBox, super.priority = -6});

  final PlateSpec spec;
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

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
      Paint()
        ..color = _lit
            ? (isPressed
                  ? SilhouettePalette.plateDown
                  : SilhouettePalette.plateUp)
            : (isPressed ? Palette.plateDown : Palette.plateUp),
    );
    if (_lit) return;
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
  Door(this.spec, {this.look = LevelLook.greyBox, super.priority = -6});

  final DoorSpec spec;
  final LevelLook look;

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
    final lit = look == LevelLook.silhouette;
    canvas.drawRect(
      bounds,
      Paint()
        ..color = lit ? SilhouettePalette.doorColor : Palette.doorColor,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..color = lit ? SilhouettePalette.blockTop : Palette.blockEdge
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
  Goal({
    required this.area,
    this.endsLevel = true,
    this.look = LevelLook.greyBox,
    super.priority = -6,
  });

  final Rect area;
  final bool endsLevel;
  final LevelLook look;
  bool reached = false;

  void reset() => reached = false;

  @override
  void render(Canvas canvas) {
    if (look == LevelLook.silhouette) {
      // A doorway, not an outline. The grey-box version is a pale stroke, and
      // against a sunset a pale stroke is nothing at all — the way out was
      // invisible the first time the puzzles ran in the real scene. A dark
      // opening with a lit frame reads on both.
      canvas.drawRect(
        area,
        Paint()
          ..color = reached
              ? SilhouettePalette.goalReached
              : SilhouettePalette.goalIdle,
      );
      canvas.drawRect(
        area.deflate(2),
        Paint()
          ..color = SilhouettePalette.goalReached
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      return;
    }
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
    this.look = LevelLook.greyBox,
    super.priority = 80,
  });

  final ShadowRecorder recorder;
  final ValueGetter<bool> enabled;
  final LevelLook look;

  late final Paint _line = Paint()
    ..color = look == LevelLook.silhouette
        ? SilhouettePalette.trailColor
        : Palette.trailColor
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
