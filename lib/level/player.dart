import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game/character/figure.dart';
import '../game/character/locomotion.dart';
import '../game/config.dart';
import '../input/input_controller.dart';
import '../shadow/snapshot.dart';
import 'level.dart';

/// The surfaces the player can stand on this frame.
///
/// [oneWay] is landable from above only. The shadow goes in there rather than
/// in [blocking] for a reason worth keeping: the shadow *teleports* — it is
/// placed from a buffer, not moved by physics — so a fully solid shadow can
/// materialise inside the player and wedge them into the geometry with no way
/// out. Landing on it from above is the use the plan actually wants tested
/// ("الظل كمنصة"); the shadow as a blocking wall is a later phase.
class Solids {
  const Solids({this.blocking = const [], this.oneWay = const []});

  final List<Rect> blocking;
  final List<Rect> oneWay;

  static const empty = Solids();
}

/// The player in the grey-box scene.
///
/// Same numbers as `ProbeWalker` — [WarayaConfig.walkSpeed], [jumpSpeed],
/// [gravity] — so what the lab proves is true of the real character. The one
/// thing it adds is box collision against the test geometry, which the Phase 1
/// walker did not need on a flat horizon.
///
/// Nothing here is game feel. No coyote time, no jump buffering, no
/// acceleration curve: that is Phase 3, and adding it now would mean tuning
/// the feel of a mechanic we have not yet decided to keep.
class Player extends PositionComponent {
  Player({
    required this.input,
    required this.solids,
    required double spawnX,
    required double floorTop,
  }) : _spawn = Vector2(spawnX, floorTop),
       super(
         size: Vector2(44, 96),
         anchor: Anchor.bottomCenter,
         position: Vector2(spawnX, floorTop),
         priority: 100,
       );

  /// Where a reload puts the body back. A level's, not a constant: the same
  /// player runs every level.
  final Vector2 _spawn;

  final InputController input;

  /// Read fresh every frame: the shadow's rect changes and may vanish.
  final Solids Function() solids;

  /// Speed, jump timing and gravity — the same object the Phase 1 scene uses.
  final Locomotion locomotion = Locomotion();

  double facing = 1;
  bool isGrounded = false;

  double get verticalVelocity => locomotion.verticalVelocity;

  /// How folded up the body is, 0 standing to 1 fully crouched. Drives the
  /// pose, the collision height and the walking speed together, so the body
  /// on screen is the body the physics uses.
  double crouch = 0;

  /// True while the thing under the feet is the shadow. The scene uses it to
  /// carry the player along when the shadow walks out from under them.
  bool isOnShadow = false;

  /// World units to shift this frame on top of the player's own walking,
  /// applied and cleared by [update]. Set by the scene when the shadow the
  /// player is standing on moves.
  double carryX = 0;

  double _stridePhase = 0;

  /// How far through the current stride the legs are, in radians. Read by the
  /// step-sound detector, which needs the exact moment a foot lands and can
  /// get it from here rather than from a timer.
  double get stridePhase => _stridePhase;

  bool _walking = false;
  bool _jumpedSinceCapture = false;

  /// How far above a one-way surface the previous frame's feet may have been
  /// and still count as landing on it, rather than passing through from below.
  static const double _landingTolerance = 6;

  late final Figure _figure = Figure(height: size.y, color: Palette.bodyColor);

  /// Current standing height, shrinking as the body folds up.
  double get bodyHeight => boxFor(crouch).height;

  Rect get bounds => boxFor(crouch);

  /// The box this body would occupy at a given fold. Used to ask whether
  /// there is room to stand up before standing up.
  Rect boxFor(double fold) {
    final height = size.y * (1 - (1 - WarayaConfig.crouchHeightFactor) * fold);
    return Rect.fromLTWH(x - size.x / 2, y - height, size.x, height);
  }

  PoseState get pose {
    if (!isGrounded) {
      return verticalVelocity < 0 ? PoseState.jump : PoseState.fall;
    }
    return _walking ? PoseState.walk : PoseState.idle;
  }

  /// The pose to hand the recorder, consuming the edge-triggered jump flag.
  PoseSnapshot capture() {
    final snapshot = PoseSnapshot(
      x: x,
      y: y,
      facing: facing,
      state: pose,
      stridePhase: _stridePhase,
      crouch: crouch,
      jumpPressed: _jumpedSinceCapture,
    );
    _jumpedSinceCapture = false;
    return snapshot;
  }

  /// Speed the body last hit the ground at, zeroed once read.
  double takeLandingImpact() {
    final impact = _landingImpact;
    _landingImpact = 0;
    return impact;
  }

  double _landingImpact = 0;

  void resetToSpawn() {
    position.setValues(_spawn.x, _spawn.y);
    locomotion.reset();
    _landingImpact = 0;
    facing = 1;
    isGrounded = false;
    isOnShadow = false;
    carryX = 0;
    crouch = 0;
    _stridePhase = 0;
    _walking = false;
    _jumpedSinceCapture = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final world = solids();

    _updateCrouch(dt, world);

    final wasGrounded = isGrounded;
    locomotion.step(
      dt,
      intent: input.intent,
      grounded: wasGrounded,
      speedScale: 1 - (1 - WarayaConfig.crouchSpeedFactor) * crouch,
      // Not while folded up: a crouch that can be jumped out of at any moment
      // is a dodge, and the low corridor stops being a corridor.
      canJump: crouch < 0.2,
    );
    if (locomotion.jumped) {
      isGrounded = false;
      isOnShadow = false;
      _jumpedSinceCapture = true;
    }

    final walked = locomotion.horizontalVelocity * dt;
    _walking = walked.abs() > 0.01;
    if (_walking) facing = walked.sign;

    final step = walked + carryX;
    carryX = 0;
    if (step != 0) {
      position.x += step;
      _resolveHorizontal(world, step);
    }
    if (walked != 0) {
      _stridePhase =
          (_stridePhase +
              walked.abs() / Figure.strideLengthFor(size.y) * 2 * pi) %
          (2 * pi);
    }

    final previousFeet = y;
    position.y += locomotion.verticalVelocity * dt;
    _resolveVertical(world, previousFeet, wasGrounded);
  }

  /// Folds and unfolds the body, and refuses to unfold into a ceiling.
  ///
  /// Growing is the direction that can put the body inside the world, so it is
  /// the direction that gets checked. Crouching under something and letting go
  /// of the key leaves you crouched until you walk out, which is what every
  /// game that has ever had a crouch does, and the only alternative is being
  /// shoved through the floor.
  void _updateCrouch(double dt, Solids world) {
    final wants = input.intent.crouch && isGrounded;
    final step = WarayaConfig.crouchRate * dt;
    if (wants) {
      crouch = (crouch + step).clamp(0.0, 1.0);
      return;
    }
    final next = (crouch - step).clamp(0.0, 1.0);
    if (next == crouch) return;
    final wouldFit = !world.blocking.any(boxFor(next).overlaps);
    if (wouldFit) crouch = next;
  }

  void _resolveHorizontal(Solids world, double step) {
    for (final rect in world.blocking) {
      if (!bounds.overlaps(rect)) continue;
      position.x = step > 0 ? rect.left - size.x / 2 : rect.right + size.x / 2;
      // Otherwise speed piles up against the wall and the body fires sideways
      // the moment it steps clear of it.
      locomotion.stopHorizontally();
    }
  }

  void _resolveVertical(Solids world, double previousFeet, bool wasGrounded) {
    isGrounded = false;
    isOnShadow = false;

    for (final rect in world.blocking) {
      if (!bounds.overlaps(rect)) continue;
      if (verticalVelocity < 0) {
        position.y = rect.bottom + bodyHeight;
        locomotion.stopRising();
        continue;
      }
      if (previousFeet <= rect.top + _landingTolerance) {
        position.y = rect.top;
        isGrounded = true;
        _recordLanding(wasGrounded);
        continue;
      }
      // We did not fall onto this: it arrived at us. A door coming down on a
      // body used to teleport that body onto its roof, 190 units up, because
      // "overlapping and falling" was taken to mean "landed on it". Being
      // shoved out of the doorway is what a closing door does.
      _pushOutOf(rect);
    }

    if (verticalVelocity < 0) return;
    for (final rect in world.oneWay) {
      if (!bounds.overlaps(rect)) continue;
      // Only from above: coming up through it, or walking into its side, must
      // not snap the player onto its roof.
      if (previousFeet > rect.top + _landingTolerance) continue;
      position.y = rect.top;
      isGrounded = true;
      isOnShadow = true;
      _recordLanding(wasGrounded);
    }
  }

  /// Shifts the body to whichever side of [rect] is nearer, and kills the
  /// speed it had. Used when a solid moves into the body rather than the
  /// other way round.
  void _pushOutOf(Rect rect) {
    final box = bounds;
    final leftwards = box.right - rect.left;
    final rightwards = rect.right - box.left;
    position.x += leftwards < rightwards ? -leftwards : rightwards;
    locomotion.stopHorizontally();
  }

  /// Zeroes the fall and remembers how hard it was, but only for a fall that
  /// actually ended — resting on the ground calls this every frame.
  void _recordLanding(bool wasGrounded) {
    final impact = locomotion.land();
    if (!wasGrounded && impact > _landingImpact) _landingImpact = impact;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    _figure.render(
      canvas,
      phase: _stridePhase,
      moving: pose.isMoving,
      airborne: pose.isAirborne,
      facing: facing,
      crouch: crouch,
    );
    canvas.restore();
  }
}
