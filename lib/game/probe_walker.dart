import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../input/input_controller.dart';
import 'config.dart';

/// A featureless block that walks where the input abstraction tells it to.
///
/// PLACEHOLDER for Friday 3's animated silhouette character. Its only job in
/// Friday 1 is to prove, on each target device, that keyboard and touch both
/// arrive as the same [InputIntent] and that camera-follow tracks it.
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

  final Paint _fill = Paint()..color = const Color(0xFF0A070E);

  /// A warm hairline so the probe stays legible against the dark
  /// foreground bands. Friday 3's real silhouette drops this.
  final Paint _outline = Paint()
    ..color = const Color(0xFFF0C27B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    super.update(dt);

    final axis = input.intent.moveAxis;
    if (axis != 0) {
      facing = axis.sign;
      position.x += axis * WarayaConfig.walkSpeed * dt;
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
    canvas.drawRect(size.toRect(), _fill);
    canvas.drawRect(size.toRect(), _outline);
  }
}
