import 'package:flutter/foundation.dart';

/// A platform-agnostic snapshot of what the player is asking the game to do.
///
/// Every backend — keyboard, touch, and later gamepad — produces one of these,
/// so gameplay code never learns which platform it is running on. This is the
/// abstraction the Phase 1 plan asks for "from the first line of code".
@immutable
class InputIntent {
  const InputIntent({this.moveAxis = 0.0, this.jump = false});

  /// Horizontal movement in [-1, 1]; negative is left, positive is right.
  final double moveAxis;

  /// Set only on the frame the jump was requested — edge-triggered, not held.
  final bool jump;

  static const none = InputIntent();

  bool get isIdle => moveAxis == 0 && !jump;

  /// Folds another intent in: the larger axis wins, and jump is sticky so a
  /// tap never gets swallowed by a source that happens to be polled later.
  InputIntent merge(InputIntent other) => InputIntent(
    moveAxis: other.moveAxis.abs() > moveAxis.abs() ? other.moveAxis : moveAxis,
    jump: jump || other.jump,
  );

  @override
  String toString() =>
      'InputIntent(moveAxis: ${moveAxis.toStringAsFixed(1)}, jump: $jump)';
}

/// One way of producing an [InputIntent]: keyboard, touch, gamepad, a replay
/// file, a test harness. Implementations are usually also Flame components so
/// they can receive events, but nothing here depends on that.
abstract interface class InputSource {
  /// Short name for the debug HUD, e.g. `keyboard`.
  String get label;

  /// Whether this source has ever produced real input in this session. Used to
  /// show the player which scheme is live rather than guessing from the
  /// platform, which gets tablets and phone browsers wrong.
  bool get hasBeenUsed;

  /// Returns the current intent and clears any edge-triggered state.
  InputIntent poll();
}
