import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../game/config.dart';
import 'input.dart';

/// Mobile touch: hold the lower-left or lower-right of the screen to walk,
/// touch the upper band to jump.
///
/// It lives in the camera's viewport, so its coordinates are screen-space and
/// independent of where the camera happens to be looking.
class TouchInputSource extends PositionComponent
    with DragCallbacks, TapCallbacks
    implements InputSource {
  double _axis = 0;
  bool _jumpQueued = false;
  bool _hasBeenUsed = false;

  @override
  String get label => 'touch';

  @override
  bool get hasBeenUsed => _hasBeenUsed;

  @override
  InputIntent poll() {
    final intent = InputIntent(moveAxis: _axis, jump: _jumpQueued);
    _jumpQueued = false;
    return intent;
  }

  void _applyPointer(Vector2 local) {
    _hasBeenUsed = true;
    if (local.y < size.y * WarayaConfig.touchJumpBandFraction) {
      _jumpQueued = true;
      _axis = 0;
      return;
    }
    _axis = local.x < size.x / 2 ? -1.0 : 1.0;
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
    _axis = 0;
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _axis = 0;
  }

  @override
  void onTapDown(TapDownEvent event) => _applyPointer(event.localPosition);

  @override
  void onTapUp(TapUpEvent event) => _axis = 0;

  @override
  void onTapCancel(TapCancelEvent event) => _axis = 0;
}
