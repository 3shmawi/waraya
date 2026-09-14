import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'input.dart';

/// Desktop and web keyboard: arrows or WASD to walk, space/up/W to jump,
/// S or down to crouch.
class KeyboardInputSource extends Component
    with KeyboardHandler
    implements InputSource {
  static final _leftKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.keyA,
  };
  static final _rightKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyD,
  };
  static final _jumpKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.keyW,
  };
  static final _crouchKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.keyS,
  };

  double _axis = 0;
  bool _crouching = false;
  bool _jumpHeld = false;
  bool _jumpQueued = false;
  bool _hasBeenUsed = false;

  @override
  String get label => 'keyboard';

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

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final left = keysPressed.any(_leftKeys.contains);
    final right = keysPressed.any(_rightKeys.contains);
    _axis = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    // Held, so these are read from the pressed set rather than from the event.
    _crouching = keysPressed.any(_crouchKeys.contains);
    _jumpHeld = keysPressed.any(_jumpKeys.contains);

    if (event is KeyDownEvent && _jumpKeys.contains(event.logicalKey)) {
      _jumpQueued = true;
    }
    if (event is KeyDownEvent) {
      _hasBeenUsed = true;
    }

    // Don't claim the event — other handlers (debug overlays) may want it.
    return true;
  }
}
