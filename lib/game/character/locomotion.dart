import 'dart:math';

import '../../input/input.dart';
import '../config.dart';

/// The character's feel, in one place.
///
/// Both scenes had their own copy of "read the axis, add gravity, maybe jump",
/// which was fine while that was six lines and a liability the moment Phase 3
/// started tuning it. This owns the velocities and the timers; the caller owns
/// the collision, because that is the part the two scenes genuinely differ on.
///
/// Nothing here touches the shadow. That is the payoff of recording transforms
/// rather than inputs (see the plan's method ب): the feel can be re-tuned
/// every Friday and no recording ever disagrees with it, because what was
/// recorded was where the body went, not which key produced it.
class Locomotion {
  /// Current speed along the ground, world units per second, signed.
  double horizontalVelocity = 0;

  /// Vertical speed, positive downward to match the world's y axis.
  double verticalVelocity = 0;

  /// True on the frame a jump actually launched.
  bool jumped = false;

  /// Seconds since the body was last on the ground. Feeds coyote time, and is
  /// pushed out of range when a jump consumes the window so one press cannot
  /// buy two jumps.
  double _sinceGrounded = _never;

  /// Seconds of credit left on a jump press that arrived before it could be
  /// used.
  double _jumpBuffer = 0;

  static const double _never = 1e9;

  bool get isRising => verticalVelocity < 0;

  /// Whether a jump would be allowed right now, coyote time included.
  bool get hasGroundUnderfoot => _sinceGrounded <= WarayaConfig.coyoteSeconds;

  /// Advances the velocities by one frame.
  ///
  /// [grounded] is the result of the *previous* frame's collision pass, which
  /// is what makes coyote time work at all. [speedScale] is for states that
  /// slow the body down, like a crouch, and [canJump] for states that forbid
  /// leaving the ground.
  void step(
    double dt, {
    required InputIntent intent,
    required bool grounded,
    double speedScale = 1,
    bool canJump = true,
  }) {
    jumped = false;
    _sinceGrounded = grounded ? 0 : _sinceGrounded + dt;
    _jumpBuffer = intent.jump
        ? WarayaConfig.jumpBufferSeconds
        : max(0, _jumpBuffer - dt);

    _steer(dt, intent.moveAxis, grounded: grounded, speedScale: speedScale);

    if (canJump && _jumpBuffer > 0 && hasGroundUnderfoot) {
      verticalVelocity = -WarayaConfig.jumpSpeed;
      _jumpBuffer = 0;
      _sinceGrounded = _never;
      jumped = true;
    }

    // Let go early and the climb is cut short. Never on the launch frame: a
    // buffered press that was already released would otherwise be clipped
    // before it had risen at all.
    final cutSpeed = WarayaConfig.jumpSpeed * WarayaConfig.jumpCutFactor;
    if (!jumped && !intent.jumpHeld && verticalVelocity < -cutSpeed) {
      verticalVelocity = -cutSpeed;
    }

    final gravity = isRising ? WarayaConfig.gravity : WarayaConfig.fallGravity;
    verticalVelocity = min(
      verticalVelocity + gravity * dt,
      WarayaConfig.maxFallSpeed,
    );
  }

  void _steer(
    double dt,
    double axis, {
    required bool grounded,
    required double speedScale,
  }) {
    final target = axis * WarayaConfig.walkSpeed * speedScale;
    final double rate;
    if (target == 0) {
      rate = grounded ? WarayaConfig.groundFriction : WarayaConfig.airFriction;
    } else if (horizontalVelocity != 0 &&
        target.sign != horizontalVelocity.sign) {
      // Turning around, which has to be sharper than setting off or the
      // character feels like it is wading.
      rate =
          (grounded ? WarayaConfig.groundAccel : WarayaConfig.airAccel) *
          WarayaConfig.turnAccelFactor;
    } else {
      rate = grounded ? WarayaConfig.groundAccel : WarayaConfig.airAccel;
    }

    final delta = rate * dt;
    horizontalVelocity = (target - horizontalVelocity).abs() <= delta
        ? target
        : horizontalVelocity + delta * (target > horizontalVelocity ? 1 : -1);
  }

  /// Call when the collision pass stops the body horizontally, so speed does
  /// not pile up against a wall and fire the character sideways the moment
  /// they step away from it.
  void stopHorizontally() => horizontalVelocity = 0;

  /// Call on landing, with the speed the body arrived at. Returns that speed
  /// so the caller can shake the camera by it, and zeroes the fall.
  double land() {
    final impact = verticalVelocity;
    verticalVelocity = 0;
    return impact;
  }

  /// Call when the head hits something.
  void stopRising() => verticalVelocity = 0;

  void reset() {
    horizontalVelocity = 0;
    verticalVelocity = 0;
    jumped = false;
    _sinceGrounded = _never;
    _jumpBuffer = 0;
  }
}
