import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';

import 'input.dart';

/// Which right-hand button a finger is on.
enum _Pad { jump, crouch }

/// The on-screen controls (`docs/phase-11-feel.md` §2).
///
/// **The left side is a stick, not two arrows.** Put a thumb down anywhere on
/// the left part of the screen and drag: sideways walks, down crouches. The
/// stick is drawn where the thumb landed, so there is nothing to aim for —
/// the old two arrows were 36 across, and a game that asks you to stand a
/// third of a body onto a plate cannot also ask you to hit a 36-pixel circle
/// without looking.
///
/// **Down on the same thumb is crouch**, because in this game crouching is
/// the decision (it is how you leave a step) and it is usually made while
/// walking. Holding a separate button with the hand that jumps was the hard
/// way round. The crouch button stays on the right for whoever prefers it.
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

  /// Where the stick may start: this fraction of the width, from the left.
  static const double stickZone = 0.45;

  /// Base sizes in screen pixels, before the setting scales them.
  static const double _jumpRadius = 46;
  static const double _crouchRadius = 36;
  static const double _stickRadius = 54;
  static const double _margin = 26;
  static const double _gap = 18;

  /// How far a thumb has to move before it means anything. Sideways for a
  /// walk; down, further, for a crouch — so a walk that drifts a little
  /// downwards does not duck by accident.
  static const double _walkDead = 12;
  static const double _crouchDead = 30;

  final Map<int, _Pad> _held = {};

  /// The stick's finger, where it landed and where it is now.
  int? _stickPointer;
  Vector2 _stickOrigin = Vector2.zero();
  Vector2 _stickNow = Vector2.zero();

  bool _jumpQueued = false;
  bool _hasBeenUsed = false;

  @override
  String get label => 'touch';

  @override
  bool get hasBeenUsed => _hasBeenUsed;

  double get _k => _scale().clamp(0.5, 2.0);

  /// Sideways and downwards travel of the stick's thumb, or zero without one.
  Vector2 get _drag =>
      _stickPointer == null ? Vector2.zero() : _stickNow - _stickOrigin;

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

  /// Whether the stick is pulled down far enough to crouch.
  bool get stickCrouch => _drag.y >= _crouchDead * _k;

  @override
  InputIntent poll() {
    final pads = _held.values.toSet();
    final intent = InputIntent(
      moveAxis: stickAxis,
      jump: _jumpQueued,
      // Keeping a finger on the jump button is how you ask for a high jump.
      jumpHeld: pads.contains(_Pad.jump),
      crouch: pads.contains(_Pad.crouch) || stickCrouch,
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
    if (local.x <= size.x * stickZone && _stickPointer == null) {
      _hasBeenUsed = true;
      _stickPointer = pointerId;
      _stickOrigin = local.clone();
      _stickNow = local.clone();
    }
  }

  /// A finger already down moved.
  void _move(int pointerId, Vector2 local) {
    if (!isTouchPlatform) return;
    if (pointerId == _stickPointer) {
      _stickNow = local.clone();
      // A thumb dragged far past the ring pulls the ring along behind it, so
      // reversing does not need the whole distance back first.
      final reach = _stickRadius * _k;
      final drag = _stickNow - _stickOrigin;
      if (drag.length > reach) {
        _stickOrigin = _stickNow - drag.normalized() * reach;
      }
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
        _stickOrigin = origin;
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
      id == _stickPointer ? _stickOrigin.clone() : null,
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

  Paint _fill(Color color, double strength) =>
      Paint()..color = color.withValues(alpha: color.a * strength);

  @override
  void render(Canvas canvas) {
    if (!isTouchPlatform) return;
    final strength = _opacity().clamp(0.0, 1.0);
    final k = _k;
    final rim = _fill(_rimColor, strength)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final glyph = _fill(_glyphColor, strength);

    // The stick: where the thumb landed, or — with no thumb on it — a faint
    // ring where a thumb usually goes, so the left side is not an invisible
    // control. Invisible zones were the first version, and the first person
    // handed the link on a phone did not guess them.
    final ring = _stickRadius * k;
    final origin = _stickPointer == null
        ? Offset(_margin * k + ring, size.y - _margin * k - ring)
        : Offset(_stickOrigin.x, _stickOrigin.y);
    final idle = _stickPointer == null;
    canvas.drawCircle(
      origin,
      ring,
      _fill(_faceColor, strength * (idle ? 0.6 : 1)),
    );
    canvas.drawCircle(origin, ring, rim);
    final drag = _drag;
    final knob = drag.length > ring ? drag.normalized() * ring : drag;
    canvas.drawCircle(
      origin + Offset(knob.x, knob.y),
      ring * 0.42,
      _fill(idle ? _faceColor : _litColor, strength),
    );
    // Arrows on the ring for left, right and down — what it does, drawn.
    for (final (dx, dy) in const [(-1.0, 0.0), (1.0, 0.0), (0.0, 1.0)]) {
      final lit =
          (dx != 0 && stickAxis == dx) || (dy != 0 && stickCrouch && !idle);
      canvas.drawPath(
        _arrow(origin + Offset(dx, dy) * ring * 0.72, dx, dy, k * 0.7),
        lit ? glyph : _fill(_glyphColor, strength * 0.55),
      );
    }

    final pads = _held.values.toSet();
    for (final pad in _Pad.values) {
      final centre = _centreOf(pad);
      final radius = _radiusOf(pad);
      final pressed = pads.contains(pad) || (pad == _Pad.crouch && stickCrouch);
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
