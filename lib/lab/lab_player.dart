import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game/character/figure.dart';
import '../game/config.dart';
import '../input/input_controller.dart';
import '../shadow/snapshot.dart';
import 'lab_scene.dart';

/// The surfaces the player can stand on this frame.
///
/// [oneWay] is landable from above only. The shadow goes in there rather than
/// in [blocking] for a reason worth keeping: the shadow *teleports* — it is
/// placed from a buffer, not moved by physics — so a fully solid shadow can
/// materialise inside the player and wedge them into the geometry with no way
/// out. Landing on it from above is the use the plan actually wants tested
/// ("الظل كمنصة"); the shadow as a blocking wall is a later phase.
class LabSolids {
  const LabSolids({this.blocking = const [], this.oneWay = const []});

  final List<Rect> blocking;
  final List<Rect> oneWay;

  static const empty = LabSolids();
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
class LabPlayer extends PositionComponent {
  LabPlayer({required this.input, required this.solids})
    : super(
        size: Vector2(44, 96),
        anchor: Anchor.bottomCenter,
        position: Vector2(LabScene.spawnX, LabScene.floorTop),
        priority: 100,
      );

  final InputController input;

  /// Read fresh every frame: the shadow's rect changes and may vanish.
  final LabSolids Function() solids;

  double facing = 1;
  double verticalVelocity = 0;
  bool isGrounded = false;

  /// True while the thing under the feet is the shadow. The scene uses it to
  /// carry the player along when the shadow walks out from under them.
  bool isOnShadow = false;

  /// World units to shift this frame on top of the player's own walking,
  /// applied and cleared by [update]. Set by the scene when the shadow the
  /// player is standing on moves.
  double carryX = 0;

  double _stridePhase = 0;
  bool _walking = false;
  bool _jumpedSinceCapture = false;

  /// How far above a one-way surface the previous frame's feet may have been
  /// and still count as landing on it, rather than passing through from below.
  static const double _landingTolerance = 6;

  late final Figure _figure = Figure(height: size.y, color: LabScene.bodyColor);

  Rect get bounds => Rect.fromLTWH(x - size.x / 2, y - size.y, size.x, size.y);

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
      jumpPressed: _jumpedSinceCapture,
    );
    _jumpedSinceCapture = false;
    return snapshot;
  }

  void resetToSpawn() {
    position.setValues(LabScene.spawnX, LabScene.floorTop);
    verticalVelocity = 0;
    facing = 1;
    isGrounded = false;
    isOnShadow = false;
    carryX = 0;
    _stridePhase = 0;
    _walking = false;
    _jumpedSinceCapture = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final world = solids();

    final axis = input.intent.moveAxis;
    _walking = axis != 0;
    if (_walking) facing = axis.sign;

    final walked = axis * WarayaConfig.walkSpeed * dt;
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

    // Read before gravity, so a jump asked for on the landing frame still
    // fires.
    if (input.intent.jump && isGrounded) {
      verticalVelocity = -WarayaConfig.jumpSpeed;
      isGrounded = false;
      isOnShadow = false;
      _jumpedSinceCapture = true;
    }

    verticalVelocity += WarayaConfig.gravity * dt;
    final previousFeet = y;
    position.y += verticalVelocity * dt;
    _resolveVertical(world, previousFeet);
  }

  void _resolveHorizontal(LabSolids world, double step) {
    for (final rect in world.blocking) {
      if (!bounds.overlaps(rect)) continue;
      position.x = step > 0 ? rect.left - size.x / 2 : rect.right + size.x / 2;
    }
  }

  void _resolveVertical(LabSolids world, double previousFeet) {
    isGrounded = false;
    isOnShadow = false;

    for (final rect in world.blocking) {
      if (!bounds.overlaps(rect)) continue;
      if (verticalVelocity >= 0) {
        position.y = rect.top;
        isGrounded = true;
      } else {
        position.y = rect.bottom + size.y;
      }
      verticalVelocity = 0;
    }

    if (verticalVelocity < 0) return;
    for (final rect in world.oneWay) {
      if (!bounds.overlaps(rect)) continue;
      // Only from above: coming up through it, or walking into its side, must
      // not snap the player onto its roof.
      if (previousFeet > rect.top + _landingTolerance) continue;
      position.y = rect.top;
      verticalVelocity = 0;
      isGrounded = true;
      isOnShadow = true;
    }
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
    );
    canvas.restore();
  }
}
