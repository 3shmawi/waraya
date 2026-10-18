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
  PressurePlate(
    this.spec, {
    this.look = LevelLook.greyBox,
    super.priority = -6,
  });

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

  /// Which of the level's doors and lights this one belongs to, drawn as a
  /// small shape on it and on its door ([PairMark]). Null when the level has
  /// only one thing to open: then there is nothing to tell apart.
  int? mark;

  /// How far the button's cap stands proud of its housing when nobody is on
  /// it. Pressed, it sinks flush.
  static const double capRise = 7;

  @override
  void render(Canvas canvas) {
    final housing = spec.area;
    // A button, not a slab: a housing that stays put and a cap on top of it
    // that goes down under a body. The old plate was a dark strip that sank
    // into the floor, and in the lit scene a dark strip on a dark floor was
    // nothing at all. Asked for: every thing in a level should say what it is
    // by its shape.
    final inset = min(housing.width * 0.16, 14.0);
    final rise = isPressed ? 3.0 : capRise;
    final cap = Rect.fromLTRB(
      housing.left + inset,
      housing.top - rise,
      housing.right - inset,
      housing.top + 1,
    );
    // An inverted plate's "doing its thing" is holding the door shut, so it
    // lights while nobody is on it — the same swap the slab always had.
    final lively = inverts ? !isPressed : isPressed;
    final capShape = RRect.fromRectAndCorners(
      cap,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
    );
    canvas.drawRRect(capShape, Paint()..color = _capColor(lively));
    // Against a sunset, an unlit cap is a dark bump on a dark housing; the
    // backlight catching its edge is what keeps it there.
    if (_lit && !lively) {
      canvas.drawRRect(
        capShape,
        Paint()
          ..color = SilhouettePalette.blockTop
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawRect(housing, Paint()..color = _housingColor);
    if (inverts) _hazard(canvas, housing);
    // The lit lip every standable thing has, here so the housing does not
    // vanish into the floor it sits on.
    canvas.drawRect(
      Rect.fromLTWH(housing.left, housing.top, housing.width, 2),
      Paint()..color = _lit ? SilhouettePalette.blockTop : Palette.blockTop,
    );
    PairMark.draw(
      canvas,
      mark,
      Offset(housing.center.dx, housing.center.dy + 1),
      lit: lively,
      look: look,
    );
  }

  Color get _housingColor =>
      _lit ? const Color(0xFF1C1418) : const Color(0xFF3E3E3E);

  Color _capColor(bool lively) => _lit
      ? (lively ? const Color(0xFFFFC46A) : const Color(0xFF2A1E18))
      : (lively ? const Color(0xFFE0533D) : const Color(0xFF9C3A2C));

  /// Warning stripes on the housing of a plate that holds its door **shut**,
  /// so it does not read as one more button to stand on. The same shape as
  /// every other plate, because it is one; striped, because standing on it is
  /// the mistake.
  void _hazard(Canvas canvas, Rect housing) {
    canvas.save();
    canvas.clipRect(housing);
    final stripe = Paint()
      ..color = _lit ? const Color(0xFFD9A25C) : const Color(0xFFE8C23A)
      ..strokeWidth = 4;
    for (var x = housing.left - housing.height; x < housing.right; x += 12) {
      canvas.drawLine(
        Offset(x, housing.bottom),
        Offset(x + housing.height, housing.top),
        stripe,
      );
    }
    canvas.restore();
  }
}

/// The small shape that says which button opens which door.
///
/// One per door or named light, in the level's order — a circle, a triangle,
/// a square, a diamond, a cross — drawn on the thing that opens it and on the
/// thing it opens. Lit while it is doing its thing, outlined while it is not,
/// so stepping on a button lights the same shape on the door across the room.
/// Only in a level with more than one: with one door there is nothing to
/// pair.
abstract final class PairMark {
  static const double size = 10;

  static void draw(
    Canvas canvas,
    int? mark,
    Offset center, {
    required bool lit,
    required LevelLook look,
    double size = PairMark.size,
  }) {
    if (mark == null) return;
    final silhouette = look == LevelLook.silhouette;
    final color = silhouette
        ? const Color(0xFFFFE7B0)
        : const Color(0xFFF4F4F4);
    final paint = Paint()
      ..color = lit ? color : color.withValues(alpha: 0.75)
      ..style = lit ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final r = size / 2;
    final c = center;
    switch (mark % 5) {
      case 0:
        canvas.drawCircle(c, r, paint);
      case 1:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy + r * 0.8)
            ..lineTo(c.dx - r, c.dy + r * 0.8)
            ..close(),
          paint,
        );
      case 2:
        canvas.drawRect(Rect.fromCircle(center: c, radius: r * 0.85), paint);
      case 3:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r, c.dy)
            ..close(),
          paint,
        );
      default:
        final cross = Paint()
          ..color = paint.color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c + Offset(-r, -r), c + Offset(r, r), cross);
        canvas.drawLine(c + Offset(r, -r), c + Offset(-r, r), cross);
    }
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
  LightZone(
    this.spec, {
    this.look = LevelLook.greyBox,
    this.landsOnSomething = true,
    super.priority = 60,
  });

  final LightSpec spec;
  Rect get area => spec.area;
  final LevelLook look;

  /// Whether it is lit right now — the rule, decided on the level's own
  /// clock (`LevelGame._resolveInteractions`). Only a named light
  /// ([LightSpec.id]) is ever anything but on.
  bool isOn = true;

  /// How much of the light is drawn: 1 lit, 0 out. Paint only, and it trails
  /// [isOn] by [_fadeSeconds] so a light going out reads as going out rather
  /// than as a frame missing. The rule changed the moment [isOn] did.
  double _glow = 1;

  static const double _fadeSeconds = 0.15;

  /// Sets the light, and says whether that changed it.
  bool hold({required bool on}) {
    if (on == isOn) return false;
    isOn = on;
    return true;
  }

  void reset() {
    isOn = true;
    _glow = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final step = dt / _fadeSeconds;
    _glow = (isOn ? _glow + step : _glow - step).clamp(0.0, 1.0);
  }

  /// Whether the beam comes down onto a floor, or stops in the air.
  ///
  /// A beam that stops short — the lamp in `underTheLight`, which ends above
  /// a ducked head — used to be drawn exactly like one that reaches the
  /// floor: a hard-sided pool at its bottom edge, hanging in mid-air. Reported
  /// from playing as looking cut off. With nothing to land on it now thins
  /// out over its last stretch instead, and gets no pool: a pool is light
  /// *on* something. The rule is the same rectangle either way — the fade
  /// ends where the rule does.
  final bool landsOnSomething;

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
    ..shader = landsOnSomething
        ? ui.Gradient.linear(
            Offset(0, area.top),
            Offset(0, area.bottom),
            _lit
                ? const [Color(0x44E8B55E), Color(0x14E8B55E)]
                : const [Color(0x40FFFFFF), Color(0x18FFFFFF)],
          )
        : ui.Gradient.linear(
            Offset(0, area.top),
            Offset(0, area.bottom),
            _lit
                ? const [
                    Color(0x44E8B55E),
                    Color(0x2AE8B55E),
                    Color(0x00E8B55E),
                  ]
                : const [
                    Color(0x40FFFFFF),
                    Color(0x26FFFFFF),
                    Color(0x00FFFFFF),
                  ],
            [0, _fadeFrom, 1],
          );

  /// Where a beam with nothing under it starts thinning out, as a fraction of
  /// its height.
  double get _fadeFrom =>
      (1 - _fadeDepth / area.height).clamp(0.0, 1.0).toDouble();

  /// How far above its bottom edge a hanging beam fades to nothing.
  static const double _fadeDepth = 90;

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

  /// The lamp the beam comes out of.
  ///
  /// Reported from looking at it: the column stopped dead in the middle of
  /// the sky, lit from nowhere. Light with no source reads as a tinted
  /// rectangle somebody drew on the scene, which is exactly what the player
  /// must not think it is — the rectangle *is* the rule here.
  ///
  /// Horizontal and well above the play plane on purpose. A dark vertical in
  /// reach is something the player tries to stand on, which is why there are
  /// no lamp posts anywhere in this game.
  static const double _lampDepth = 13;
  static const double _lampInset = 0.16;

  /// Which shape the buttons that put this light out carry ([PairMark]).
  /// Only a light with a name has one.
  int? mark;

  @override
  void render(Canvas canvas) {
    final lamp = Rect.fromLTRB(
      area.left + area.width * _lampInset,
      area.top - _lampDepth,
      area.right - area.width * _lampInset,
      area.top,
    );
    // What it hangs from, running off the top of the view. Two units wide and
    // lit, for the same reason the door frames are: a dark upright is a thing
    // the player tries to stand on.
    canvas.drawRect(
      Rect.fromLTRB(
        lamp.center.dx - 1,
        lamp.top - 900,
        lamp.center.dx + 1,
        lamp.top,
      ),
      Paint()..color = const Color(0x66FFE7B0),
    );
    canvas.drawRect(
      lamp,
      Paint()..color = _lit ? SilhouettePalette.blockFill : Palette.blockFill,
    );
    // The bulb: the underside of the housing, which is the brightest thing in
    // the level and the place the eye follows down into the beam.
    // Out, the bulb is the housing's own dark, with only a rim to say there
    // is a lamp there to come back on.
    canvas.drawRect(
      Rect.fromLTWH(lamp.left, lamp.bottom - 3, lamp.width, 3),
      Paint()
        ..color = Color.lerp(
          const Color(0x55FFE7B0),
          const Color(0xFFFFE7B0),
          _glow,
        )!,
    );

    PairMark.draw(
      canvas,
      mark,
      Offset(lamp.center.dx, lamp.center.dy - 1),
      lit: !isOn,
      look: look,
      size: 8,
    );

    if (_glow > 0) {
      // Faded as one layer while it is going out or coming on, so beam, core
      // and pool fade together; lit or out, nothing extra is drawn.
      final fading = _glow < 1;
      if (fading) {
        canvas.saveLayer(
          area.inflate(4),
          Paint()..color = Color.fromRGBO(0, 0, 0, _glow),
        );
      }
      _drawBeam(canvas);
      if (fading) canvas.restore();
    }
    if (_lit) return;
    // The bench is for measuring, so there the rectangle has an outline and
    // you can see exactly where it ends — fainter while the light is out,
    // because the rule is not there then, only the place it would be.
    canvas.drawRect(
      area,
      Paint()
        ..color = isOn ? const Color(0x66FFFFFF) : const Color(0x26FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawBeam(Canvas canvas) {
    canvas.drawRect(area, _beam);
    canvas.drawRect(area.deflate(area.width * 0.28), _core);
    if (landsOnSomething) {
      canvas.drawRect(
        Rect.fromLTRB(
          area.left,
          max(area.top, area.bottom - _poolDepth),
          area.right,
          area.bottom,
        ),
        _pool,
      );
    }
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

  /// Which door or light this flips, as a shape. See [PairMark].
  int? mark;

  /// How far the lever leans, so which way it is thrown reads at a glance
  /// from across the level.
  static const double _lean = 26;
  static const double _reach = 34;

  @override
  void render(Canvas canvas) {
    final base = spec.area;
    // A lever on a housing: the housing is the plate's, so the two read as
    // the same family, and the stick with a knob on it is what says this one
    // is thrown rather than pressed. A plate sinks; a key has nothing to sink
    // and leans instead — one way thrown, the other way not.
    final pivot = Offset(base.center.dx, base.top);
    final knob = Offset(
      pivot.dx + (flipped ? _lean : -_lean),
      base.top - _reach,
    );
    final stick = _lit
        ? (flipped ? const Color(0xFFFFC46A) : SilhouettePalette.blockTop)
        : (flipped ? const Color(0xFFE0533D) : const Color(0xFF4A4A4A));
    canvas.drawLine(
      pivot,
      knob,
      Paint()
        ..color = stick
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(knob, 6, Paint()..color = stick);
    // The hub it turns on: half a disc sitting on the housing.
    canvas.drawArc(
      Rect.fromCircle(center: pivot, radius: 9),
      pi,
      pi,
      true,
      Paint()..color = _lit ? const Color(0xFF1C1418) : const Color(0xFF3E3E3E),
    );
    canvas.drawRect(
      base,
      Paint()..color = _lit ? const Color(0xFF1C1418) : const Color(0xFF3E3E3E),
    );
    canvas.drawRect(
      Rect.fromLTWH(base.left, base.top, base.width, 2),
      Paint()..color = _lit ? SilhouettePalette.blockTop : Palette.blockTop,
    );
    // Off-centre, clear of the hub, on the side the lever is not leaning to.
    PairMark.draw(
      canvas,
      mark,
      Offset(
        base.center.dx + (flipped ? -1 : 1) * min(base.width / 2 - 8, 24),
        base.center.dy + 1,
      ),
      lit: flipped,
      look: look,
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
  /// 3. otherwise shut, after [DoorSpec.lingerSeconds] — but only if [lingers].
  ///
  /// [lingers] is false when the only thing holding this door open is the
  /// **player's own body**, and it is the difference between a puzzle and a
  /// corridor. The grace exists for one reason: so that arriving a beat after
  /// your past steps off the plate is not a lost run. Your own weight needs
  /// no such forgiveness — you can simply keep standing there — and giving it
  /// any means a door you opened yourself is still open when you get to it.
  ///
  /// Reported from playing, twice, before this was the rule. A six-second
  /// grace on a door 340 units from its plate meant you could touch the
  /// plate, run, and be through before your shadow existed at all: two
  /// levels, both of them about needing your past, both finishable without
  /// ever having one. A number in the data can only paper over that one
  /// level at a time; this is the shape of the thing.
  ///
  /// Returns true if the answer changed, which is what the scene listens to so
  /// a door makes its noise once rather than every frame.
  bool hold(bool open, {bool forcedShut = false, bool lingers = true}) {
    if (forcedShut) {
      // The grace goes with it. A door being held shut that drifts open again
      // a moment later because something was standing on a plate six seconds
      // ago is not a door anybody is holding.
      _pressed = false;
      _linger = 0;
    } else {
      _pressed = open;
      // Grace only for a door your **past** was holding. See [lingers].
      if (open) _linger = lingers ? spec.lingerSeconds : 0;
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

  /// How far the head sticks out past the opening on each side, and how deep
  /// it is.
  static const double _headOverhang = 9;
  static const double _headDepth = 20;

  /// How far apart the shutter's slats are.
  static const double _slat = 14;

  /// Which shape the buttons that open this one carry. See [PairMark].
  int? mark;

  @override
  void render(Canvas canvas) {
    final lit = look == LevelLook.silhouette;
    final opening = spec.closed;
    final fill = Paint()
      ..color = lit ? SilhouettePalette.doorColor : Palette.doorColor;
    final edge = Paint()
      ..color = lit ? SilhouettePalette.blockTop : Palette.blockEdge;

    // The head of the frame, and the reason it is here: the slab travels up
    // by its own height, so an open door used to be a black bar hanging in
    // the sky above an empty gap, attached to nothing. Now it goes somewhere.
    // Out of reach by construction — `Levels.minDoorHeight` is 250 and a body
    // on a shadow gets to 232, so the top of any door is already above
    // anywhere the player can stand, and the head is above that.
    final head = Rect.fromLTRB(
      opening.left - _headOverhang,
      opening.top - _headDepth,
      opening.right + _headOverhang,
      opening.top,
    );
    canvas.drawRect(head, fill);
    canvas.drawRect(
      Rect.fromLTWH(head.left, head.top, head.width, lit ? 3 : 2),
      edge,
    );
    PairMark.draw(
      canvas,
      mark,
      head.center + const Offset(0, 1),
      lit: wantsOpen,
      look: look,
    );

    // The slab, clipped to the opening, so it slides up into the head rather
    // than past it. The collision box is [bounds] and is unchanged: what is
    // hidden is the part that has left the doorway, and the doorway is the
    // only part of it anybody can reach.
    canvas.save();
    canvas.clipRect(opening);
    canvas.drawRect(bounds, fill);
    // Slats, like the steel shutter on every shop front: what makes a shut
    // door a door and not one more wall. The two were the same dark bar.
    final slat = Paint()
      ..color = lit ? const Color(0xFF3A2C30) : const Color(0xFF7A7A7A)
      ..strokeWidth = 2;
    for (var y = bounds.top + _slat; y < bounds.bottom - 2; y += _slat) {
      canvas.drawLine(
        Offset(bounds.left + 3, y),
        Offset(bounds.right - 3, y),
        slat,
      );
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..color = lit ? SilhouettePalette.blockTop : Palette.blockEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();

    // The jambs and the sill, which turn the head from a bar hanging in the
    // sky into a doorway. There is no wall either side of these — they are
    // free-standing gates on flat ground — so without the uprights the frame
    // has nothing holding it up.
    //
    // Lit lines rather than dark posts, and that is not decoration. A dark
    // vertical in this game is a thing the player tries to stand on, and a
    // drawn solid that the body walks straight through is a lie. A hairline
    // is the backlight catching an edge, which is the whole grammar of the
    // scene and cannot be mistaken for somewhere to put your feet.
    final jamb = lit ? 3.0 : 2.0;
    for (final x in [opening.left - jamb, opening.right]) {
      canvas.drawRect(
        Rect.fromLTRB(x, opening.top, x + jamb, opening.bottom),
        edge,
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(
        head.left,
        opening.bottom - jamb,
        head.right,
        opening.bottom,
      ),
      edge,
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

      // Light coming out of it, pooling at the bottom. A rectangle with a
      // stroke all the way round it reads as a picture frame hung on the sky;
      // something spilling light reads as somewhere to walk into, which is
      // what it is.
      if (!reached) {
        canvas.drawRect(
          area,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.linear(
              Offset(0, area.top),
              Offset(0, area.bottom),
              const [Color(0x00E8B55E), Color(0x66FFC46A)],
            ),
        );
      }

      // Framed on three sides. Not the fourth: the bottom of this is the
      // floor you walk in over, and a line across it turns the doorway back
      // into a box.
      canvas.drawPath(
        Path()
          ..moveTo(area.left, area.bottom)
          ..lineTo(area.left, area.top)
          ..lineTo(area.right, area.top)
          ..lineTo(area.right, area.bottom),
        Paint()
          ..color = SilhouettePalette.goalReached
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      return;
    }
    if (endsLevel) {
      // The way out is a lit doorway on the bench too. A pale outlined square
      // was the same shape as a marker and nearly the same as a block; a
      // doorway with light coming out of it is somewhere to walk into.
      canvas.drawRect(
        area,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, area.top),
            Offset(0, area.bottom),
            reached
                ? const [Color(0xFF2B2B2B), Color(0xFF2B2B2B)]
                : const [Color(0x33FFFFFF), Color(0xEEFFFFFF)],
          ),
      );
      canvas.drawPath(
        Path()
          ..moveTo(area.left, area.bottom)
          ..lineTo(area.left, area.top)
          ..lineTo(area.right, area.top)
          ..lineTo(area.right, area.bottom),
        Paint()
          ..color = Palette.goalReached
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
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

/// A mark on the ground where your past will be [ahead] from now
/// (`docs/phase-11-feel.md` §4.2) — on the bench, behind a switch.
///
/// The hardest question in the game is *when will my past get here?*, and
/// today the player counts it in their head. This answers it from the buffer,
/// which already holds the answer: the pose [ahead] down the queue is exactly
/// where the shadow will stand then. It shows only what the player **did**,
/// never what to do — the rule any such aid has to keep to.
///
/// Paint only, like the trail. It reads the buffer and changes nothing.
class ShadowForecast extends PositionComponent {
  ShadowForecast({
    required this.recorder,
    required this.enabled,
    this.ahead = 1,
    this.tickRate = 1 / 60,
    this.look = LevelLook.greyBox,
    super.priority = 81,
  });

  final ShadowRecorder recorder;
  final ValueGetter<bool> enabled;

  /// Seconds into the future the mark stands.
  final double ahead;
  final double tickRate;
  final LevelLook look;

  /// Where the mark goes, or null when the buffer does not reach that far —
  /// the delay is shorter than [ahead], or the past has not got there yet.
  Offset? get point {
    final steps = (ahead / tickRate).round();
    final pending = recorder.pending;
    // The head plays only once the buffer holds a whole delay. Each tick adds
    // one pose and, past `delayTicks`, plays one — so pose i plays on tick
    // delayTicks - length + 1 + i. While the buffer is still filling, a
    // second from now may be a pose far down the queue, or nothing at all.
    if (steps < 1) return null;
    final i = steps - 1 - recorder.delayTicks + pending.length;
    if (i < 0 || i >= pending.length) return null;
    final pose = pending.elementAt(i);
    return Offset(pose.x, pose.y);
  }

  late final Paint _ring = Paint()
    ..color =
        (look == LevelLook.silhouette
                ? SilhouettePalette.shadowColor
                : Palette.shadowColor)
            .withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  late final Paint _fill = Paint()
    ..color =
        (look == LevelLook.silhouette
                ? SilhouettePalette.shadowColor
                : Palette.shadowColor)
            .withValues(alpha: 0.3);

  @override
  void render(Canvas canvas) {
    if (!enabled()) return;
    final at = point;
    if (at == null) return;
    // A flat ring on the floor: a place, not a body.
    final mark = Rect.fromCenter(center: at, width: 34, height: 9);
    canvas.drawOval(mark, _fill);
    canvas.drawOval(mark, _ring);
  }
}
