import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../input/input_controller.dart';
import 'character/figure.dart';
import 'character/locomotion.dart';
import 'config.dart';

/// The character: a silhouette that walks, jumps and falls where the input
/// abstraction tells it to.
///
/// The physics live here and the pose lives in [Figure], which is solved from a
/// stride phase rather than played back from a sprite sheet. The phase advances
/// with distance covered, not with time, so the feet stay planted at any walk
/// speed and any frame rate.
class ProbeWalker extends PositionComponent {
  ProbeWalker({required this.input})
    : super(
        size: Vector2(44, 96),
        anchor: Anchor.bottomCenter,
        position: Vector2(0, WarayaConfig.horizonY),
        priority: 100,
      );

  final InputController input;

  /// Facing direction, kept so Friday 3 can flip the sprite.
  double facing = 1;

  /// Speed, jump timing and gravity — shared with the lab so the two scenes
  /// cannot drift apart as Phase 3 tunes them.
  final Locomotion locomotion = Locomotion();

  /// Vertical speed, positive downward to match the world's y axis.
  double get verticalVelocity => locomotion.verticalVelocity;

  /// Speed the body last hit the ground at, for the camera to react to. Zero
  /// once read.
  double takeLandingImpact() {
    final impact = _landingImpact;
    _landingImpact = 0;
    return impact;
  }

  double _landingImpact = 0;

  /// How folded up the body is, 0 standing to 1 fully crouched. Nothing in
  /// this scene has a ceiling to duck under, so unlike the lab there is
  /// nothing to check before standing back up.
  double crouch = 0;

  /// True while standing on the ground, which is also the only time a jump is
  /// allowed -- otherwise a held jump key climbs the sky.
  bool get isGrounded =>
      y >= WarayaConfig.horizonY - 0.001 && verticalVelocity >= 0;

  late final Figure _figure = Figure(
    height: size.y,
    color: const Color(0xFF0A070E),
  );

  /// How far through the current stride the legs are, in radians.
  double _stridePhase = 0;

  @override
  void update(double dt) {
    super.update(dt);

    final wantsCrouch = input.intent.crouch && isGrounded;
    crouch = (crouch + (wantsCrouch ? 1 : -1) * WarayaConfig.crouchRate * dt)
        .clamp(0.0, 1.0);

    final wasGrounded = isGrounded;
    locomotion.step(
      dt,
      intent: input.intent,
      grounded: wasGrounded,
      speedScale: 1 - (1 - WarayaConfig.crouchSpeedFactor) * crouch,
      canJump: crouch < 0.2,
    );

    final step = locomotion.horizontalVelocity * dt;
    if (step != 0) {
      position.x += step;
      facing = step.sign;
      _stridePhase =
          (_stridePhase +
              step.abs() / Figure.strideLengthFor(size.y) * 2 * pi) %
          (2 * pi);
    }

    position.y += locomotion.verticalVelocity * dt;

    if (position.y >= WarayaConfig.horizonY) {
      position.y = WarayaConfig.horizonY;
      final impact = locomotion.land();
      if (!wasGrounded) _landingImpact = impact;
    }
  }

  @override
  void render(Canvas canvas) {
    // The component is anchored bottom-centre, so the figure's origin -- its
    // soles -- is at the bottom middle of the local box.
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    _figure.render(
      canvas,
      phase: _stridePhase,
      // Driven by speed, not by the key: the legs keep running for the moment
      // it takes to slide to a stop, instead of freezing under a body that is
      // still travelling.
      moving: locomotion.horizontalVelocity.abs() > 1,
      airborne: !isGrounded,
      facing: facing,
      crouch: crouch,
    );
    canvas.restore();
  }
}
