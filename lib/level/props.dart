import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import '../shadow/shadow_recorder.dart';
import 'level.dart';

/// Every immovable block in one component. They never change within a level,
/// so there is no reason for each to carry its own transform.
class Blocks extends PositionComponent {
  Blocks(this.rects, {this.look = LevelLook.greyBox, super.priority = -10});

  final List<Rect> rects;
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

  late final Paint _fill = Paint()
    ..color = _lit ? SilhouettePalette.blockFill : Palette.blockFill;
  late final Paint _top = Paint()
    ..color = _lit ? SilhouettePalette.blockTop : Palette.blockTop;
  late final Paint _edge = Paint()
    ..color = _lit ? SilhouettePalette.blockEdge : Palette.blockEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// How far the backlight spills over a lit edge into the air above it.
  static const double _bloom = 22;

  /// The face shading and the light spilling over the top edge, one pair per
  /// rectangle.
  ///
  /// Flat near-black on a photograph reads as a hole cut in the picture rather
  /// than as a thing standing in front of it — reported from playing as the
  /// blocks looking "detached from the background". Two cheap gradients fix
  /// it: the face is not one flat value, and the edge the light is coming from
  /// glows a little into the air, which is what an edge lit from behind does.
  ///
  /// Built once. They are vertical, so they do not care where the rectangle is
  /// horizontally, which is what lets the ground fill stretch to the camera
  /// without rebuilding anything.
  late final List<(Paint, Paint)> _shading = [
    for (final rect in rects) (_faceFor(rect), _bloomFor(rect)),
  ];

  Paint _faceFor(Rect rect) => Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, rect.top),
      Offset(0, rect.top + min(140, rect.height)),
      const [Color(0xFF191020), Color(0x00191020)],
    );

  Paint _bloomFor(Rect rect) => Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, rect.top - _bloom),
      Offset(0, rect.top),
      const [Color(0x00E8B55E), Color(0x38E8B55E)],
    );

  @override
  void render(Canvas canvas) {
    for (final (i, rect) in rects.indexed) {
      final body = rect;
      if (_lit) {
        final (face, bloom) = _shading[i];
        // On the real rectangle, not the stretched fill: the glow belongs to
        // the lit edge, and the lit edge stops where the floor does.
        canvas.drawRect(
          Rect.fromLTRB(rect.left, rect.top - _bloom, rect.right, rect.top),
          bloom,
        );
        canvas.drawRect(body, _fill);
        canvas.drawRect(body, face);
      } else {
        canvas.drawRect(body, _fill);
      }
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

  /// Whether the door is being asked to be open this frame.
  ///
  /// Write it through [hold] rather than directly: a door with a linger has to
  /// remember that it was asked a moment ago.
  bool wantsOpen = false;

  bool _pressed = false;

  /// Seconds of grace left since the plate was last held.
  double _linger = 0;

  double _open = 0;
  double get openFraction => _open;

  String get id => spec.id;

  /// Ask the door to be open this frame because a plate is held.
  ///
  /// Returns true if the answer changed, which is what the scene listens to so
  /// a door makes its noise once rather than every frame.
  bool hold(bool pressed) {
    _pressed = pressed;
    if (pressed) _linger = spec.lingerSeconds;
    final wanted = pressed || _linger > 0;
    if (wanted == wantsOpen) return false;
    wantsOpen = wanted;
    return true;
  }

  /// Solid until it is nearly all the way up, so squeezing through a door
  /// that is still closing is not a thing.
  bool get isSolid => _open < 0.9;

  Rect get bounds => spec.closed.translate(0, -spec.closed.height * _open);

  void reset() {
    _open = 0;
    // Also the request, or the door creeps open for one frame after a reload
    // because the plate was still held when everything was put back.
    wantsOpen = false;
    _pressed = false;
    _linger = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Runs before the scene asks again this frame, so the moment the grace
    // runs out is picked up by the next `hold` and the door makes its noise.
    if (!_pressed && _linger > 0) _linger = max(0, _linger - dt);
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
