import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../game/character/figure.dart';
import '../game/character/locomotion.dart';
import '../game/config.dart';
import '../input/input.dart';
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
    this.color = Palette.bodyColor,
    this.leash,
    this.leashAnchors,
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

  /// How far this body can get from the pasts that hold it (`Level.leash`),
  /// or null for no leash. See [_holdToLeash].
  final double? leash;

  /// The middles of the pasts holding the body this frame: the ones that
  /// have arrived and are out of the light. Read fresh, like [solids].
  final List<Offset> Function()? leashAnchors;

  /// True while the leash is all that is holding the body up.
  bool get isHanging => _hanging;
  bool _hanging = false;

  /// What the body is drawn in. A level's look decides it: legibly dark on the
  /// bench, as black as the scene gets in the lit environment.
  final Color color;

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
  bool _warpedSinceCapture = false;

  /// How far above a one-way surface the previous frame's feet may have been
  /// and still count as landing on it, rather than passing through from below.
  static const double _landingTolerance = 6;

  late final Figure _figure = Figure(height: size.y, color: color);

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
      warped: _warpedSinceCapture,
    );
    _jumpedSinceCapture = false;
    _warpedSinceCapture = false;
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
    forcedIntent = null;
    speedBoost = 1;
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
    _warpedSinceCapture = false;
    _hanging = false;
  }

  /// Puts the body down at [feet], folded [crouch], with no speed — where a
  /// mirror sends it (`Level.mirrors`). Facing is kept: nothing turned you
  /// round.
  ///
  /// The fold comes with it because the place may be under a low ceiling
  /// your past ducked under; standing up there is the ordinary crouch's job,
  /// which only stands when there is room.
  void warpTo(Offset feet, {double crouch = 0}) {
    position.setValues(feet.dx, feet.dy);
    locomotion.reset();
    this.crouch = crouch;
    isGrounded = false;
    isOnShadow = false;
    carryX = 0;
    _hanging = false;
    _warpedSinceCapture = true;
  }

  /// What the body does instead of what the player asks, while set: a dog
  /// seeing you off runs you back the way you came (`LevelGame`). Null —
  /// nearly always — is the player's own input.
  InputIntent? forcedIntent;

  /// How much faster than walking, while [forcedIntent] is set.
  double speedBoost = 1;

  InputIntent get _intent => forcedIntent ?? input.intent;

  @override
  void update(double dt) {
    super.update(dt);
    final world = solids();

    _updateCrouch(dt, world);

    final wasGrounded = isGrounded;
    final before = bounds.center;
    locomotion.step(
      dt,
      intent: _intent,
      grounded: wasGrounded,
      speedScale:
          (1 - (1 - WarayaConfig.crouchSpeedFactor) * crouch) * speedBoost,
      // Not while folded up: a crouch that can be jumped out of at any moment
      // is a dodge, and the low corridor stops being a corridor.
      canJump: crouch < 0.2,
    );
    if (locomotion.jumped) {
      isGrounded = false;
      isOnShadow = false;
      _jumpedSinceCapture = true;
    }

    final pushed = locomotion.horizontalVelocity * dt;
    if (pushed.abs() > 0.01) facing = pushed.sign;

    final step = pushed + carryX;
    carryX = 0;
    if (step != 0) {
      position.x += step;
      _resolveHorizontal(world, step);
    }
    _hanging = false;
    // The legs go at the pace the leash lets the body go, not the pace the
    // stick asks for: full speed on the spot reads as a body skating.
    final walked = pushed * _holdStepToLeash(before);
    _walking = walked.abs() > 0.01;
    if (walked != 0) {
      _stridePhase =
          (_stridePhase +
              walked.abs() / Figure.strideLengthFor(size.y) * 2 * pi) %
          (2 * pi);
    }

    final previousFeet = y;
    final beforeFall = bounds.center;
    position.y += locomotion.verticalVelocity * dt;
    _resolveVertical(world, previousFeet, wasGrounded);
    _holdFallToLeash(beforeFall, world, dt);
  }

  /// Slows a step across as it nears the end of the leash, and stops it
  /// there (`Level.leash`). Gives back how much of the step was kept, 0 to 1.
  ///
  /// The leash is a wall that goes where your past goes, round it at the
  /// leash's length. A step into that wall stops at it, the way a step into
  /// a block does: it only ever takes back part of the step the body itself
  /// just made, so it can stop you and never moves you. And it allows
  /// whatever distance there already was — a past that walked away on its
  /// own leaves you where you are, until you walk back or it comes back.
  ///
  /// **Soft at the end.** Over the last [_easeShare] of the leash a step
  /// that takes you further from a past is cut down the closer you are, to
  /// nothing at the end. The first version let you run at full speed into
  /// the end and stop dead, and then stand there until your past caught up:
  /// in the dark that was a walk, a stop, a wait of most of D, and a walk —
  /// reported from playing as being stuck. Eased, the same rope turns that
  /// into one slow, steady walk behind your past with the line taut, and the
  /// furthest you can get is still the leash's length.
  ///
  /// Checked for the step across and the fall separately, like the walls
  /// are. Checked as one move, walking in and falling out cancelled each
  /// other and the body hung frozen with the way in an arm's length off.
  double _holdStepToLeash(Offset before) {
    final length = leash;
    final anchors = leashAnchors?.call();
    if (length == null || anchors == null || anchors.isEmpty) return 1;
    final after = bounds.center;
    final across = after.dx - before.dx;
    if (across == 0) return 1;

    var keep = 1.0;
    final ease = length * _easeShare;
    for (final anchor in anchors) {
      final from = (before - anchor).distance;
      // Towards it, or round it: nothing to hold.
      if ((after - anchor).distance <= from) continue;
      keep = min(keep, ((length - from) / ease).clamp(0.0, 1.0));
    }
    if (keep < 1) position.x -= across * (1 - keep);

    // And never past the end, whatever the easing left of the step.
    final cut = _cutToLeash(before);
    if (cut != null) {
      position.x -= cut.dx;
      locomotion.stopHorizontally();
      keep = across == 0 ? 0 : (bounds.center.dx - before.dx) / across;
    }
    return keep.clamp(0.0, 1.0);
  }

  /// How much of the leash, at its end, slows you down. See
  /// [_holdStepToLeash].
  static const double _easeShare = 1.0;

  /// The fall against the same wall: a body falling into it slides down it,
  /// the way it would down a slope, and comes to rest at the bottom of it —
  /// under its past, a leash's length down. That is hanging: no ground, so
  /// no jump, until it is standing on something again.
  ///
  /// Sliding and not stopping, because stopping is a floor. The first
  /// version stopped the fall dead, and a body held at the end of its leash
  /// just kept walking out over a pit at the height it left the edge: the
  /// step across filled the leash, so the fall had nowhere to go. A wall
  /// you are pressed against holds you up only as far as it is under you.
  ///
  /// The slide is along the wall, not into it, so the leash still never
  /// takes you closer to your past than you were going: it is the wall's
  /// shape, the same as the corner of a block turning a fall into a step.
  /// And never into a block: where the slide would put the body inside one,
  /// the fall is only stopped.
  void _holdFallToLeash(Offset before, Solids world, double dt) {
    final length = leash;
    final anchors = leashAnchors?.call();
    if (length == null || anchors == null || anchors.isEmpty) return;
    final after = bounds.center;
    final fall = after.dy - before.dy;
    if (fall == 0) return;

    if (fall < 0) {
      // Rising into it: the head meets the wall, like a ceiling.
      final cut = _cutToLeash(before);
      if (cut == null) return;
      position.y -= cut.dy;
      locomotion.stopRising();
      return;
    }

    // Only a leash that has you at its end, or inside it, holds a fall. One
    // already further out than its length is a past that walked off on its
    // own (or came out of the light far away), and it has never pulled, so
    // it does not hold you up either: held there, a body falling down a wall
    // stopped dead in mid-air the moment its past stepped out of a lamp, and
    // was let down the wall a little at a time — past a way in that a fall
    // is meant to be far too fast to turn into.
    final holding = [
      for (final anchor in anchors)
        if ((before - anchor).distance <= length + 0.5) anchor,
    ];
    if (holding.isEmpty) return;
    final cut = _cutToLeash(before, holding);
    if (cut == null) return;

    var to = after;
    for (final anchor in holding) {
      final allowed = max(length, (before - anchor).distance);
      final out = to - anchor;
      if (out.distance > allowed) to = anchor + out * (allowed / out.distance);
    }
    final shift = to - after;
    final slides =
        to.dy >= before.dy &&
        holding.every(
          (anchor) =>
              (to - anchor).distance <=
              max(length, (before - anchor).distance) + 1e-6,
        ) &&
        !world.blocking.any(bounds.shift(shift).overlaps);
    if (slides) {
      position.x += shift.dx;
      position.y += shift.dy;
    } else {
      position.y -= cut.dy;
    }
    final fell = bounds.center.dy - before.dy;
    locomotion.verticalVelocity = dt > 0 ? max(0, fell / dt) : 0;
    isGrounded = false;
    isOnShadow = false;
    _hanging = true;
  }

  /// How much of the move from [before] to where the body is now has to be
  /// taken back to keep it within the leash of every past holding it, or
  /// null if none.
  Offset? _cutToLeash(Offset before, [List<Offset>? only]) {
    final length = leash;
    final anchors = only ?? leashAnchors?.call();
    if (length == null || anchors == null || anchors.isEmpty) return null;
    final after = bounds.center;
    final move = after - before;
    if (move == Offset.zero) return null;

    var keep = 1.0;
    for (final anchor in anchors) {
      final allowed = max(length, (before - anchor).distance);
      if ((after - anchor).distance <= allowed) continue;
      keep = min(keep, _reach(before - anchor, move, allowed));
    }
    return keep >= 1 ? null : move * (1 - keep);
  }

  /// How much of [move], from [start] (both relative to the anchor), keeps
  /// within [radius]: the larger root of |start + t·move| = radius, in 0..1.
  /// [start] is inside or on the circle, so there is always one.
  static double _reach(Offset start, Offset move, double radius) {
    final a = move.dx * move.dx + move.dy * move.dy;
    final b = 2 * (start.dx * move.dx + start.dy * move.dy);
    final c = start.dx * start.dx + start.dy * start.dy - radius * radius;
    final root = sqrt(max(0, b * b - 4 * a * c));
    return ((-b + root) / (2 * a)).clamp(0.0, 1.0);
  }

  /// Folds and unfolds the body, and refuses to unfold into a ceiling.
  ///
  /// Growing is the direction that can put the body inside the world, so it is
  /// the direction that gets checked. Crouching under something and letting go
  /// of the key leaves you crouched until you walk out, which is what every
  /// game that has ever had a crouch does, and the only alternative is being
  /// shoved through the floor.
  void _updateCrouch(double dt, Solids world) {
    final wants = _intent.crouch && isGrounded;
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
