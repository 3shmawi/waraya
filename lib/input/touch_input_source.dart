import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../game/config.dart';
import 'input.dart';

/// Mobile touch: hold the lower-left or lower-right of the screen to walk,
/// touch the upper band to jump, and hold the strip between the two walk
/// halves to crouch.
///
/// The crouch zone is carved out of the middle of the lower band rather than
/// given a corner of its own, because a corner would sit under whichever
/// thumb is already busy walking.
///
/// It lives in the camera's viewport, so its coordinates are screen-space and
/// independent of where the camera happens to be looking.
class TouchInputSource extends PositionComponent
    with DragCallbacks, TapCallbacks
    implements InputSource {
  double _axis = 0;
  bool _crouching = false;
  bool _jumpHeld = false;
  bool _jumpQueued = false;
  bool _hasBeenUsed = false;

  @override
  String get label => 'touch';

  @override
  bool get hasBeenUsed => _hasBeenUsed;

  @override
  InputIntent poll() {
    final intent = InputIntent(
      moveAxis: _axis,
      jump: _jumpQueued,
      jumpHeld: _jumpHeld,
      crouch: _crouching,
    );
    _jumpQueued = false;
    return intent;
  }

  void _applyPointer(Vector2 local) {
    _hasBeenUsed = true;
    if (local.y < size.y * WarayaConfig.touchJumpBandFraction) {
      _jumpQueued = true;
      // Keeping a finger in the jump band is how you ask for a high jump.
      _jumpHeld = true;
      _axis = 0;
      _crouching = false;
      return;
    }
    _jumpHeld = false;
    final fromCentre = (local.x - size.x / 2).abs();
    if (fromCentre < size.x * WarayaConfig.touchCrouchBandFraction / 2) {
      _crouching = true;
      _axis = 0;
      return;
    }
    _crouching = false;
    _axis = local.x < size.x / 2 ? -1.0 : 1.0;
  }

  void _release() {
    _axis = 0;
    _crouching = false;
    _jumpHeld = false;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Cover the whole viewport so no touch is missed.
    this.size = size;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _applyPointer(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _applyPointer(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _release();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _release();
  }

  @override
  void onTapDown(TapDownEvent event) => _applyPointer(event.localPosition);

  @override
  void onTapUp(TapUpEvent event) => _release();

  @override
  void onTapCancel(TapCancelEvent event) => _release();
}
