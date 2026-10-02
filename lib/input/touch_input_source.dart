import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';

import 'input.dart';

/// Which right-hand button a finger is on.
enum _Pad { jump, crouch }

/// The on-screen controls (`docs/phase-11-feel.md` §2).
///
/// **The left side is one big pad that walks.** A fixed circle, bottom left:
/// press left of its middle to walk left, right of it to walk right, slide
/// across to turn. The old two arrows were 36 across, and a game that asks
/// you to stand a third of a body onto a plate cannot also ask you to hit a
/// 36-pixel circle without looking; this one is 108 across and hears a thumb
/// well outside its rim.
///
/// **It stays where it is drawn.** The first version put the pad wherever
/// the thumb landed and dragged it along behind the thumb — reported from
/// playing as the control wandering off. A thumb learns a place; a place
/// that moves cannot be learned.
///
/// **Crouch is the button on the right, and only there.** The first version
/// also crouched on a drag down the pad, which made two ways to do one thing
/// and one of them easy to do by accident — and an accidental crouch is an
/// accidental step left for your past, the one thing in this game that
/// should always be a decision. A crouched body cannot jump, so the right
/// thumb never needs both at once.
///
/// **Every finger is tracked separately**, as before: a thumb walking and a
/// thumb jumping are most of a platformer, and one pointer's worth of state
/// lost the walk the moment the other thumb jumped.
///
/// Whatever is drawn, the output is an [InputIntent] and nothing else. The
/// recorded solutions cannot tell this from a keyboard, which is the whole
/// reason it is safe to change.
///
/// It lives in the camera's viewport, so its coordinates are screen-space and
/// independent of where the camera happens to be looking.
class TouchInputSource extends PositionComponent
    with DragCallbacks, TapCallbacks
    implements InputSource {
  TouchInputSource({double Function()? scale, double Function()? opacity})
    : _scale = scale ?? _one,
      _opacity = opacity ?? _one;

  static double _one() => 1;

  /// Only drawn, and only live, where there are fingers.
  ///
  /// A mouse has a keyboard next to it, and buttons this size across a desktop
  /// window would be in the way of the thing they are drawn on top of. On the
  /// web this follows the browser's own idea of the platform, which is what
  /// tells a phone browser from a laptop one.
  static bool get isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// The settings page's button size, read every frame.
  final double Function() _scale;

  /// The settings page's button strength, read every frame.
  final double Function() _opacity;

  /// How far outside the pad's rim a thumb still counts as on it, as a
  /// multiple of its radius. Generous: a thumb lands low and wide.
  static const double stickReach = 1.6;

  /// Base sizes in screen pixels, before the setting scales them.
  static const double _jumpRadius = 46;
  static const double _crouchRadius = 36;
  static const double _stickRadius = 54;
  static const double _margin = 26;

  /// How much further in from the left edge the walk pad sits than the
  /// buttons do from the right. Asked for after playing: at the bare margin
  /// the thumb's natural resting place was off the pad's left side, and on
  /// a phone with a curved edge the pad's rim was under the curve.
  static const double _stickInset = 34;
  static const double _gap = 18;

  /// How far a thumb has to move before it means anything. Sideways for a
  /// walk; down, further, for a crouch — so a walk that drifts a little
  /// downwards does not duck by accident.
  static const double _walkDead = 12;

  final Map<int, _Pad> _held = {};

  /// The stick's finger, where it landed and where it is now.
  int? _stickPointer;
  Vector2 _stickNow = Vector2.zero();

  bool _jumpQueued = false;
  bool _hasBeenUsed = false;

  @override
  String get label => 'touch';

  @override
  bool get hasBeenUsed => _hasBeenUsed;

  double get _k => _scale().clamp(0.5, 2.0);

  /// Where the pad is drawn, always.
  Vector2 get stickCentre {
    final ring = _stickRadius * _k;
    return Vector2(
      (_margin + _stickInset) * _k + ring,
      size.y - _margin * _k - ring,
    );
  }

  /// Where the stick's thumb is from the pad's middle, or zero without one.
  Vector2 get _drag =>
      _stickPointer == null ? Vector2.zero() : _stickNow - stickCentre;

  /// The walk the stick is asking for: -1, 0 or 1.
  ///
  /// Digital on purpose. A keyboard can only say full speed, the recorded
  /// solutions are written in full-speed moves, and a half-pressed stick that
  /// creeps at 40% would be a way to play this game that no level was ever
  /// measured against.
  double get stickAxis {
    final dx = _drag.x;
    if (dx.abs() < _walkDead * _k) return 0;
    return dx.sign;
  }


  @override
  InputIntent poll() {
    final pads = _held.values.toSet();
    final intent = InputIntent(
      moveAxis: stickAxis,
      jump: _jumpQueued,
      // Keeping a finger on the jump button is how you ask for a high jump.
      jumpHeld: pads.contains(_Pad.jump),
      crouch: pads.contains(_Pad.crouch),
    );
    _jumpQueued = false;
    return intent;
  }

  Offset _centreOf(_Pad pad) {
    final k = _k;
    final jump = Offset(
      size.x - (_margin + _jumpRadius) * k,
      size.y - (_margin + _jumpRadius) * k,
    );
    return switch (pad) {
      _Pad.jump => jump,
      // Up and to the left of jump, where a thumb rolls to rather than
      // reaches for.
      _Pad.crouch => jump.translate(
        -(_jumpRadius + _gap + _crouchRadius) * k,
        (_jumpRadius - _crouchRadius) * k,
      ),
    };
  }

  double _radiusOf(_Pad pad) =>
      (pad == _Pad.jump ? _jumpRadius : _crouchRadius) * _k;

  /// Which button [local] is on, or null for a touch that missed them all.
  ///
  /// The hit circle is bigger than the drawn one. A thumb is wider than a
  /// fingertip and lands low, and a control that needs aiming is worse than no
  /// control.
  _Pad? _padAt(Vector2 local) {
    final point = Offset(local.x, local.y);
    for (final pad in _Pad.values) {
      if ((_centreOf(pad) - point).distance <= _radiusOf(pad) * 1.35) {
        return pad;
      }
    }
    return null;
  }

  /// A finger came down.
  void _down(int pointerId, Vector2 local) {
    if (!isTouchPlatform) return;
    final pad = _padAt(local);
    if (pad != null) {
      _hasBeenUsed = true;
      _hold(pointerId, pad);
      return;
    }
    final onPad =
        (local - stickCentre).length <= _stickRadius * _k * stickReach;
    if (onPad && _stickPointer == null) {
      _hasBeenUsed = true;
      _stickPointer = pointerId;
      _stickNow = local.clone();
    }
  }

  /// A finger already down moved.
  void _move(int pointerId, Vector2 local) {
    if (!isTouchPlatform) return;
    if (pointerId == _stickPointer) {
      // The pad stays put; only where the thumb is on it changes. A thumb
      // that slides off it keeps walking the way it went until it lifts.
      _stickNow = local.clone();
      return;
    }
    // A button finger slides: onto another button is that button, off all of
    // them is nothing.
    final pad = _padAt(local);
    if (pad == null) {
      _held.remove(pointerId);
    } else {
      _hold(pointerId, pad);
    }
  }

  void _hold(int pointerId, _Pad pad) {
    // Only the first frame of a press is a jump request; holding it after that
    // is the variable height, which `Locomotion` reads from jumpHeld.
    if (pad == _Pad.jump && !_held.values.contains(_Pad.jump)) {
      _jumpQueued = true;
    }
    _held[pointerId] = pad;
  }

  void _lift(int pointerId) {
    _held.remove(pointerId);
    if (pointerId == _stickPointer) _stickPointer = null;
  }

  /// Whether a finger is on the stick, for tests.
  @visibleForTesting
  bool get stickHeld => _stickPointer != null;

  /// A finger, as the event handlers see one — for tests, which cannot
  /// easily build Flame's events.
  @visibleForTesting
  void debugDown(int pointer, Vector2 at) => _down(pointer, at);

  @visibleForTesting
  void debugMove(int pointer, Vector2 to) => _move(pointer, to);

  @visibleForTesting
  void debugUp(int pointer) => _end(pointer);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Cover the whole viewport: a finger that slides off a button still has to
    // be heard letting go.
    this.size = size;
  }

  /// Fingers Flame is reporting as drags, and fingers whose tap was
  /// cancelled with what they were holding at the time.
  ///
  /// A finger that lands and then moves is reported twice: a tap-down, then
  /// — after a few pixels — a cancelled tap and a drag start, in an order
  /// this does not rely on. The cancel would otherwise drop the stick the
  /// moment the thumb started to walk.
  final Set<int> _dragging = {};
  final Map<int, (_Pad?, Vector2?)> _cancelled = {};

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final id = event.pointerId;
    _dragging.add(id);
    if (_held.containsKey(id) || id == _stickPointer) return;
    final was = _cancelled.remove(id);
    if (was != null && isTouchPlatform) {
      final (pad, origin) = was;
      if (pad != null) {
        _held[id] = pad;
      } else if (origin != null && _stickPointer == null) {
        _stickPointer = id;
        _stickNow = event.localPosition.clone();
      }
      return;
    }
    _down(id, event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _move(event.pointerId, event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _end(event.pointerId);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _end(event.pointerId);
  }

  @override
  void onTapDown(TapDownEvent event) {
    _cancelled.remove(event.pointerId);
    _down(event.pointerId, event.localPosition);
  }

  @override
  void onTapUp(TapUpEvent event) => _end(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) {
    final id = event.pointerId;
    if (_dragging.contains(id)) return;
    _cancelled[id] = (
      _held[id],
      id == _stickPointer ? stickCentre : null,
    );
    _lift(id);
  }

  void _end(int pointerId) {
    _dragging.remove(pointerId);
    _cancelled.remove(pointerId);
    _lift(pointerId);
  }

  static const Color _faceColor = Color(0x2E140E08);
  static const Color _pressedColor = Color(0x66140E08);
  static const Color _litColor = Color(0x33FFE7B0);
  static const Color _rimColor = Color(0x59FFE7B0);
  static const Color _glyphColor = Color(0xE6FFE7B0);

  /// Paints by colour and strength, made once. The strength only changes
  /// when the setting does, and a dozen fresh paints every frame is garbage
  /// on exactly the phones this is drawn on.
  final Map<(Color, double), Paint> _paints = {};

  Paint _fill(Color color, double strength) => _paints.putIfAbsent(
    (color, strength),
    () => Paint()..color = color.withValues(alpha: color.a * strength),
  );

  final Map<double, Paint> _rims = {};

  @override
  void render(Canvas canvas) {
    if (!isTouchPlatform) return;
    final strength = _opacity().clamp(0.0, 1.0);
    final k = _k;
    final rim = _rims.putIfAbsent(
      strength,
      () => Paint()
        ..color = _rimColor.withValues(alpha: _rimColor.a * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    final glyph = _fill(_glyphColor, strength);

    // The pad, always in the same place, fainter while nobody is on it.
    final ring = _stickRadius * k;
    final centre = stickCentre;
    final origin = Offset(centre.x, centre.y);
    final idle = _stickPointer == null;
    canvas.drawCircle(
      origin,
      ring,
      _fill(_faceColor, strength * (idle ? 0.6 : 1)),
    );
    canvas.drawCircle(origin, ring, rim);
    // The knob follows the thumb sideways only, inside the rim: that is all
    // the pad does.
    final knob = Vector2(_drag.x.clamp(-ring * 0.55, ring * 0.55), 0);
    canvas.drawCircle(
      origin + Offset(knob.x, knob.y),
      ring * 0.42,
      _fill(idle ? _faceColor : _litColor, strength),
    );
    // Arrows on the ring for left and right — what it does, drawn.
    for (final (dx, dy) in const [(-1.0, 0.0), (1.0, 0.0)]) {
      final lit = stickAxis == dx;
      canvas.drawPath(
        _arrow(origin + Offset(dx, dy) * ring * 0.72, dx, dy, k * 0.7),
        lit ? glyph : _fill(_glyphColor, strength * 0.55),
      );
    }

    final pads = _held.values.toSet();
    for (final pad in _Pad.values) {
      final centre = _centreOf(pad);
      final radius = _radiusOf(pad);
      final pressed = pads.contains(pad);
      canvas.drawCircle(
        centre,
        radius,
        _fill(pressed ? _pressedColor : _faceColor, strength),
      );
      // Lit while held: a button that does not change when it is pressed
      // leaves the thumb wondering whether it landed.
      if (pressed) {
        canvas.drawCircle(centre, radius, _fill(_litColor, strength));
      }
      canvas.drawCircle(centre, radius, rim);
      final dy = pad == _Pad.jump ? -1.0 : 1.0;
      canvas.drawPath(_arrow(centre, 0, dy, k), glyph);
    }
  }

  /// A solid triangle pointing the way [dx], [dy] go. Drawn rather than set
  /// in type: the bundled fonts have no arrow glyphs, and a shape this simple
  /// is not worth a font.
  Path _arrow(Offset centre, double dx, double dy, double k) {
    final reach = 13.0 * k;
    final half = 11.0 * k;
    // Along the direction for the tip, across it for the base.
    final tip = centre + Offset(dx, dy) * reach;
    final base = centre - Offset(dx, dy) * (reach * 0.45);
    final across = Offset(-dy, dx) * half;
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + across).dx, (base + across).dy)
      ..lineTo((base - across).dx, (base - across).dy)
      ..close();
  }
}
