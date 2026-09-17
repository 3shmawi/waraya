import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// A dark wash over the screen that clears in a third of a second.
///
/// A reload used to be instantaneous and silent: you were somewhere, and then
/// without a frame in between you were at the spawn, facing the other way. It
/// reads as a glitch rather than as dying, and in the levels where the shadow
/// kills you it is genuinely hard to tell that anything happened at all.
///
/// Not a fade *out* and back — that would mean holding the player still while
/// the screen was black, and this game's whole feel is that the delay never
/// stops for you. The screen is darkest on the frame you are put back and
/// clears while you are already moving.
class ResetFlash extends PositionComponent {
  ResetFlash({super.priority = 500});

  /// How long the wash takes to clear.
  ///
  /// Measured rather than guessed: at a third of a second with a squared
  /// falloff, a screenshot burst could barely tell the frames apart — the
  /// visible part was over in about a tenth of a second, which is a blink you
  /// would miss while looking at your own feet. Half a second with a gentler
  /// curve is still out of the way before you have finished turning round.
  static const double _seconds = 0.5;

  /// How dark it gets on the first frame.
  static const double _peak = 0.78;

  /// How the darkness falls off. Above 1 so it lets go quickly and then
  /// lingers; squared was too eager.
  static const double _falloff = 1.6;

  double _left = 0;

  /// Puts the screen back to full dark. Called on every reload, including one
  /// that interrupts another: the second death is the one you are watching.
  void show() => _left = _seconds;

  bool get isShowing => _left > 0;

  void clear() => _left = 0;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_left > 0) _left = (_left - dt).clamp(0.0, _seconds);
  }

  @override
  void render(Canvas canvas) {
    if (_left <= 0) return;
    final fraction = math.pow(_left / _seconds, _falloff).toDouble();
    canvas.drawRect(
      size.toRect(),
      Paint()
        ..color = const Color(0xFF0B0709).withValues(alpha: _peak * fraction),
    );
  }
}
