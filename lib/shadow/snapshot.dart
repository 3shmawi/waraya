import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

/// What the character was doing on one fixed tick.
///
/// This is the whole of the Phase 2 mechanic's data model. The plan picks
/// **transform recording over input recording** (طريقة ب): we store where the
/// character *ended up*, not which keys were held, so the shadow reproduces the
/// path exactly instead of re-simulating it and drifting. A puzzle where the
/// shadow has to stand on a plate cannot tolerate drift, and `update(dt)` in
/// Flame is not deterministic across frame rates. Do not swap this for input
/// recording without writing down why.
///
/// The position is stored as two doubles rather than a `Vector2` on purpose:
/// `Vector2` is mutable and cannot be `const`, and sixty of these are built
/// every second.
///
/// Named `PoseSnapshot` rather than the plan's `Snapshot` only because Flame
/// already exports a `Snapshot` mixin, and importing both is a compile
/// error.
@immutable
class PoseSnapshot {
  const PoseSnapshot({
    required this.x,
    required this.y,
    required this.facing,
    required this.state,
    required this.stridePhase,
    this.jumpPressed = false,
  });

  /// Feet position in world units — the walker is anchored bottom-centre.
  final double x;
  final double y;

  /// -1 or 1, matching `ProbeWalker.facing`.
  final double facing;

  final PoseState state;

  /// How far through the stride the legs were, in radians.
  ///
  /// The character's gait is solved from a phase rather than played from a
  /// sprite sheet (see `Figure`), so in this project the phase *is* part of the
  /// animation state the plan asks us to record.
  final double stridePhase;

  /// Recorded for events only — never used to move the shadow. When the shadow
  /// eventually needs to *do* something at a moment (grab, press, throw), this
  /// is the field that says when.
  final bool jumpPressed;

  Vector2 get position => Vector2(x, y);

  bool get facingRight => facing >= 0;

  @override
  String toString() =>
      'PoseSnapshot(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${state.name})';
}

/// The four poses `Figure` can draw. Kept as an enum rather than the plan's
/// `String` so a typo is a compile error.
enum PoseState {
  idle,
  walk,
  jump,
  fall;

  bool get isMoving => this == PoseState.walk;
  bool get isAirborne => this == PoseState.jump || this == PoseState.fall;
}
