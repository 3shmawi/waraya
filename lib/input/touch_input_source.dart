import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';

import 'input.dart';

/// Which on-screen button a finger is on.
enum _Pad { left, right, jump, crouch }

/// The on-screen controls: two arrows bottom left, jump and crouch bottom
/// right.
///
/// It used to be invisible zones — halves of the screen to walk, a band across
/// the top to jump. Nobody can be expected to guess that, and the first person
/// handed the link on a phone did not. Drawn buttons say what they do.
///
/// **Every finger is tracked separately.** The old version kept one pointer's
/// worth of state, so a thumb holding *right* was overwritten the moment the
/// other thumb asked for a jump — which is most of what a platformer is. Held
/// buttons live in a map keyed by pointer id and the intent is derived from
/// the set of them.
///
/// It lives in the camera's viewport, so its coordinates are screen-space and
/// independent of where the camera happens to be looking.
class TouchInputSource extends PositionComponent
    with DragCallbacks, TapCallbacks
    implements InputSource {
  /// Only drawn, and only live, where there are fingers.
  ///
  /// A mouse has a keyboard next to it, and buttons this size across a desktop
  /// window would be in the way of the thing they are drawn on top of. On the
  /// web this follows the browser's own idea of the platform, which is what
  /// tells a phone browser from a laptop one.
  static bool get isTouchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Button radius and the gap to the screen edge, in screen pixels.
  static const double _radius = 36;
  static const double _margin = 22;
  static const double _gap = 14;

  final Map<int, _Pad> _held = {};
  bool _jumpQueued = false;
  bool _hasBeenUsed = false;

  @override
  String get label => 'touch';

  @override
  bool get hasBeenUsed => _hasBeenUsed;

  @override
  InputIntent poll() {
    final pads = _held.values.toSet();
    final left = pads.contains(_Pad.left);
    final right = pads.contains(_Pad.right);
    final intent = InputIntent(
      moveAxis: (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0),
      jump: _jumpQueued,
      // Keeping a finger on the jump button is how you ask for a high jump.
      jumpHeld: pads.contains(_Pad.jump),
      crouch: pads.contains(_Pad.crouch),
    );
    _jumpQueued = false;
    return intent;
  }

  Offset _centreOf(_Pad pad) {
    final bottom = size.y - _margin - _radius;
    final step = _radius * 2 + _gap;
    return switch (pad) {
      _Pad.left => Offset(_margin + _radius, bottom),
      _Pad.right => Offset(_margin + _radius + step, bottom),
      _Pad.crouch => Offset(size.x - _margin - _radius - step, bottom),
      _Pad.jump => Offset(size.x - _margin - _radius, bottom),
    };
  }

  /// Which button [local] is on, or null for a touch that missed them all.
  ///
  /// The hit circle is bigger than the drawn one. A thumb is wider than a
  /// fingertip and lands low, and a control that needs aiming is worse than no
  /// control.
  _Pad? _padAt(Vector2 local) {
    final point = Offset(local.x, local.y);
    for (final pad in _Pad.values) {
      if ((_centreOf(pad) - point).distance <= _radius * 1.35) return pad;
    }
    return null;
  }

  void _press(int pointerId, Vector2 local) {
    if (!isTouchPlatform) return;
    final pad = _padAt(local);
    if (pad == null) {
      _held.remove(pointerId);
      return;
    }
    _hasBeenUsed = true;
    // Only the first frame of a press is a jump request; holding it after that
    // is the variable height, which `Locomotion` reads from jumpHeld.
    if (pad == _Pad.jump && !_held.values.contains(_Pad.jump)) {
      _jumpQueued = true;
    }
    _held[pointerId] = pad;
  }

  void _lift(int pointerId) => _held.remove(pointerId);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Cover the whole viewport: a finger that slides off a button still has to
    // be heard letting go.
    this.size = size;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _press(event.pointerId, event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _press(event.pointerId, event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _lift(event.pointerId);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _lift(event.pointerId);
  }

  @override
  void onTapDown(TapDownEvent event) =>
      _press(event.pointerId, event.localPosition);

  @override
  void onTapUp(TapUpEvent event) => _lift(event.pointerId);

  @override
  void onTapCancel(TapCancelEvent event) => _lift(event.pointerId);

  final Paint _face = Paint()..color = const Color(0x2E140E08);
  final Paint _facePressed = Paint()..color = const Color(0x66140E08);
  final Paint _rim = Paint()
    ..color = const Color(0x59FFE7B0)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  final Paint _glyph = Paint()..color = const Color(0xE6FFE7B0);

  @override
  void render(Canvas canvas) {
    if (!isTouchPlatform) return;
    final pads = _held.values.toSet();
    for (final pad in _Pad.values) {
      final centre = _centreOf(pad);
      canvas.drawCircle(
        centre,
        _radius,
        pads.contains(pad) ? _facePressed : _face,
      );
      canvas.drawCircle(centre, _radius, _rim);
      canvas.drawPath(_arrow(pad, centre), _glyph);
    }
  }

  /// A solid triangle pointing the way the button goes. Drawn rather than set
  /// in type: the bundled fonts have no arrow glyphs, and a shape this simple
  /// is not worth a font.
  Path _arrow(_Pad pad, Offset centre) {
    const reach = 13.0;
    const half = 11.0;
    final (dx, dy) = switch (pad) {
      _Pad.left => (-1.0, 0.0),
      _Pad.right => (1.0, 0.0),
      _Pad.jump => (0.0, -1.0),
      _Pad.crouch => (0.0, 1.0),
    };
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
