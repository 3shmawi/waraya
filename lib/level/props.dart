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

  /// Id of the door this plate holds open — or, if it [inverts], holds shut.
  String get opens => spec.opens;

  /// Whether a body on this plate holds its door shut instead of open.
  bool get inverts => spec.inverts;

  Rect get trigger => spec.trigger;

  void reset() {
    pressedByPlayer = false;
    pressedByShadow = false;
  }

  @override
  void render(Canvas canvas) {
    final rect = isPressed ? spec.area.translate(0, 6) : spec.area;
    // An inverted plate reads as the same slab with its two states swapped
    // round, because that is what it is. Lit up under a body means "this one
    // is doing its thing"; on this plate its thing is holding the door shut.
    final lively = inverts ? !isPressed : isPressed;
    canvas.drawRect(
      rect,
      Paint()
        ..color = _lit
            ? (lively ? SilhouettePalette.plateDown : SilhouettePalette.plateUp)
            : (lively ? Palette.plateDown : Palette.plateUp),
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

/// A shaft of light, and the only place in the game where the shadow is not a
/// thing.
///
/// Drawn behind the bodies rather than over them, so a player standing in it
/// is still a clean silhouette — the beam is the air being lit, not a filter
/// laid over the character. The shadow keeps its own drawing and simply goes
/// faint, which is the feedback that matters: the rule is about the shadow, so
/// the shadow is what has to look different.
///
/// Three gradients and no shader. The atmosphere in this game is painted with
/// blend modes and layers on purpose — a fragment shader is the one thing the
/// web build cannot be trusted with — and god rays are already in the art
/// direction, so a lit column strengthens the scene rather than fighting it.
class LightZone extends PositionComponent {
  LightZone(this.area, {this.look = LevelLook.greyBox, super.priority = 60});

  final Rect area;
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

  /// How deep the pool of light on the floor is.
  ///
  /// The beam itself fades out, which is right for air and wrong for a rule:
  /// the player has to be able to see where the light stops, because that is
  /// where their shadow starts existing again. The pool has hard sides and
  /// gives the rectangle an edge you can stand next to.
  static const double _poolDepth = 54;

  late final Paint _beam = Paint()
    ..blendMode = _lit ? BlendMode.plus : BlendMode.srcOver
    ..shader = ui.Gradient.linear(
      Offset(0, area.top),
      Offset(0, area.bottom),
      _lit
          ? const [Color(0x44E8B55E), Color(0x14E8B55E)]
          : const [Color(0x40FFFFFF), Color(0x18FFFFFF)],
    );

  /// A narrower, brighter core, so the column reads as a beam rather than as a
  /// tinted rectangle.
  late final Paint _core = Paint()
    ..blendMode = _lit ? BlendMode.plus : BlendMode.srcOver
    ..shader = ui.Gradient.linear(
      Offset(0, area.top),
      Offset(0, area.bottom),
      _lit
          ? const [Color(0x3AFFE7B0), Color(0x00FFE7B0)]
          : const [Color(0x22FFFFFF), Color(0x00FFFFFF)],
    );

  late final Paint _pool = Paint()
    ..blendMode = _lit ? BlendMode.plus : BlendMode.srcOver
    ..shader = ui.Gradient.linear(
      Offset(0, area.bottom - _poolDepth),
      Offset(0, area.bottom),
      _lit
          ? const [Color(0x00FFE7B0), Color(0x4CFFE7B0)]
          : const [Color(0x00FFFFFF), Color(0x33FFFFFF)],
    );

  @override
  void render(Canvas canvas) {
    canvas.drawRect(area, _beam);
    canvas.drawRect(area.deflate(area.width * 0.28), _core);
    canvas.drawRect(
      Rect.fromLTRB(
        area.left,
        max(area.top, area.bottom - _poolDepth),
        area.right,
        area.bottom,
      ),
      _pool,
    );
    if (_lit) return;
    // The bench is for measuring, so there the rectangle has an outline and
    // you can see exactly where it ends.
    canvas.drawRect(
      area,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// A key. Flips its door the moment a body steps onto it — yours, or the one
/// walking your path D seconds behind you.
///
/// The edge is the whole thing. [PressurePlate] answers *is anyone standing
/// here* every frame; this answers *did anyone just arrive* and then keeps its
/// answer. Standing on it for a second and standing on it for a minute do
/// exactly the same thing, which is what makes it a key and not a plate.
class Toggle extends PositionComponent {
  Toggle(this.spec, {this.look = LevelLook.greyBox, super.priority = -6});

  final ToggleSpec spec;
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

  /// Which way this key is currently asking its door to be.
  bool flipped = false;

  bool _playerOn = false;
  bool _shadowOn = false;

  /// Id of the door this flips.
  String get flips => spec.flips;

  Rect get trigger => spec.trigger;

  /// Feeds this frame's contacts in and returns true if the state changed,
  /// which is what the scene listens to so a key clicks once rather than
  /// every frame.
  ///
  /// Both arriving on the same frame flips it twice, which is no flip at all.
  /// That is not a special case being handled, it is the rule applied twice —
  /// and it is the same arithmetic that makes two of your own crossings cancel
  /// each other out.
  bool touch({required bool player, required bool shadow}) {
    var changed = false;
    if (player && !_playerOn) {
      flipped = !flipped;
      changed = true;
    }
    if (shadow && !_shadowOn) {
      flipped = !flipped;
      changed = true;
    }
    _playerOn = player;
    _shadowOn = shadow;
    return changed;
  }

  void reset() {
    flipped = false;
    _playerOn = false;
    _shadowOn = false;
  }

  /// How far the lever leans, so which way it is thrown reads at a glance
  /// from across the level.
  static const double _lean = 26;

  @override
  void render(Canvas canvas) {
    final base = spec.area;
    canvas.drawRect(
      base,
      Paint()
        ..color = _lit
            ? (flipped
                  ? SilhouettePalette.plateDown
                  : SilhouettePalette.plateUp)
            : (flipped ? Palette.plateDown : Palette.plateUp),
    );
    // The lever. A plate says what it is by sinking; a key has nothing to sink
    // and has to say it some other way, so it leans — one way thrown, the
    // other way not.
    final foot = Offset(base.center.dx, base.top);
    canvas.drawLine(
      foot,
      Offset(foot.dx + (flipped ? _lean : -_lean), base.top - 34),
      Paint()
        ..color = _lit
            ? (flipped
                  ? SilhouettePalette.plateDown
                  : SilhouettePalette.blockTop)
            : Palette.blockEdge
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    if (_lit) return;
    canvas.drawRect(
      base,
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

  /// Ask the door what it should be this frame.
  ///
  /// [open] is any plate held down or key thrown its way. [forcedShut] is an
  /// inverted plate with a body on it, and it beats everything — the other
  /// plates, the key, and the linger that would otherwise carry the door a few
  /// seconds past the moment it was let go. The order is the rule:
  ///
  /// 1. an inverted plate pressed → shut, whatever else is true;
  /// 2. otherwise a plate held or a key thrown → open;
  /// 3. otherwise shut, after [DoorSpec.lingerSeconds].
  ///
  /// Returns true if the answer changed, which is what the scene listens to so
  /// a door makes its noise once rather than every frame.
  bool hold(bool open, {bool forcedShut = false}) {
    if (forcedShut) {
      // The grace goes with it. A door being held shut that drifts open again
      // a moment later because something was standing on a plate six seconds
      // ago is not a door anybody is holding.
      _pressed = false;
      _linger = 0;
    } else {
      _pressed = open;
      if (open) _linger = spec.lingerSeconds;
    }
    final wanted = !forcedShut && (_pressed || _linger > 0);
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
