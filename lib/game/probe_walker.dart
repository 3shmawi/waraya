import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../input/input_controller.dart';
import 'character/figure.dart';
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

  /// Vertical speed, positive downward to match the world's y axis.
  double verticalVelocity = 0;

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

  /// World units covered per full stride. Tied to distance rather than time so
  /// the feet never slide.
  static const double _strideLength = 105;

  @override
  void update(double dt) {
    super.update(dt);

    final axis = input.intent.moveAxis;
    if (axis != 0) {
      facing = axis.sign;
      final step = axis * WarayaConfig.walkSpeed * dt;
      position.x += step;
      _stridePhase =
          (_stridePhase + step.abs() / _strideLength * 2 * pi) % (2 * pi);
    }

    // The jump is read before gravity is applied, so a jump requested on the
    // frame of landing still takes effect.
    if (input.intent.jump && isGrounded) {
      verticalVelocity = -WarayaConfig.jumpSpeed;
    }

    verticalVelocity += WarayaConfig.gravity * dt;
    position.y += verticalVelocity * dt;

    if (position.y >= WarayaConfig.horizonY) {
      position.y = WarayaConfig.horizonY;
      verticalVelocity = 0;
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
      moving: input.intent.moveAxis != 0,
      airborne: !isGrounded,
      facing: facing,
    );
    canvas.restore();
  }
}
