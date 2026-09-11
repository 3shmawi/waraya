import 'dart:math';

import 'package:flutter/material.dart';

/// A human silhouette, posed from a walk phase rather than drawn frame by
/// frame.
///
/// The game is a silhouette game, so there is no texture or shading for a
/// sprite sheet to carry that this cannot — and a pose solved from a phase
/// gives a gait that stays in step with the character's real speed instead of
/// sliding against it, at any frame rate and any walk speed.
///
/// Proportions are in units of body height, so the whole figure scales from one
/// number. Feet sit at y = 0 and the head is at negative y, matching the
/// bottom-centre anchor the walker uses.
class Figure {
  const Figure({required this.height, required this.color});

  /// Total standing height in world units.
  final double height;

  final Color color;

  // Skeleton, as fractions of [height], measured up from the soles.
  static const double _hipY = -0.46;
  static const double _shoulderY = -0.79;
  static const double _neckY = -0.83;
  static const double _headY = -0.90;
  static const double _headR = 0.072;
  static const double _thigh = 0.235;
  static const double _shin = 0.225;
  static const double _upperArm = 0.175;
  static const double _foreArm = 0.165;

  /// Draws the figure at the origin, feet on y = 0.
  ///
  /// [phase] advances one full stride per 2π. [airborne] overrides the gait
  /// with a tucked jump pose, and [moving] with false gives a standing pose.
  void render(
    Canvas canvas, {
    required double phase,
    required bool moving,
    required bool airborne,
    required double facing,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    canvas.save();
    if (facing < 0) canvas.scale(-1, 1);

    final h = height;
    final hip = Offset(0, _hipY * h);
    final shoulder = Offset(0, _shoulderY * h);

    // A body rises and falls twice per stride, highest as it passes over the
    // planted leg.
    final bob = moving && !airborne
        ? -0.012 * h * (1 - cos(2 * phase)) / 2
        : 0.0;
    canvas.translate(0, bob);

    // Far limbs first, then the torso, then near limbs on top. Drawing both
    // arms before the body hid them behind it, which left the figure looking
    // one-armed.
    if (airborne) {
      _leg(canvas, paint, h, hip, -0.12, 0.55, front: false);
      _arm(canvas, paint, h, shoulder, -0.55, 0.9);
    } else if (moving) {
      _gaitLeg(canvas, paint, h, hip, phase + pi, front: false);
      _arm(canvas, paint, h, shoulder, 0.72 * sin(phase), 0.75);
    } else {
      _leg(canvas, paint, h, hip, -0.03, 0.02, front: false);
      _arm(canvas, paint, h, shoulder, -0.08, 0.14);
    }

    // Torso: a tapered trunk rather than a stick, so the body has mass.
    final torso = Path()
      ..moveTo(-0.070 * h, hip.dy)
      ..quadraticBezierTo(
        -0.088 * h,
        (hip.dy + shoulder.dy) / 2,
        -0.098 * h,
        shoulder.dy,
      )
      ..lineTo(0.098 * h, shoulder.dy)
      ..quadraticBezierTo(
        0.088 * h,
        (hip.dy + shoulder.dy) / 2,
        0.070 * h,
        hip.dy,
      )
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, paint..strokeWidth = 0.05 * h);

    // Neck and head.
    canvas.drawLine(
      Offset(0, shoulder.dy),
      Offset(0, _neckY * h),
      paint..strokeWidth = 0.055 * h,
    );
    canvas.drawCircle(Offset(0.012 * h, _headY * h), _headR * h, fill);

    // Near limbs, in front of the body.
    if (airborne) {
      _leg(canvas, paint, h, hip, 0.30, 1.35, front: true);
      _arm(canvas, paint, h, shoulder, -1.25, 0.5);
    } else if (moving) {
      _gaitLeg(canvas, paint, h, hip, phase, front: true);
      _arm(canvas, paint, h, shoulder, 0.72 * sin(phase + pi), 0.75);
    } else {
      _leg(canvas, paint, h, hip, 0.03, 0.02, front: true);
      _arm(canvas, paint, h, shoulder, 0.10, 0.18);
    }

    canvas.restore();
  }

  /// Solves the leg for the foot position this phase calls for.
  ///
  /// The foot traces a flattened ellipse: back along the ground through the
  /// stance, lifted and swung forward through the swing. The knee then follows
  /// from two-bone inverse kinematics, which is what keeps the gait from
  /// looking like two sticks rotating.
  void _gaitLeg(
    Canvas canvas,
    Paint paint,
    double h,
    Offset hip,
    double phase, {
    required bool front,
  }) {
    const stride = 0.20;
    const lift = 0.085;

    final footX = stride * h * cos(phase);
    final swing = sin(phase);
    final footY = -lift * h * max(0.0, swing);
    _legToFoot(canvas, paint, h, hip, Offset(footX, footY), front: front);
  }

  void _legToFoot(
    Canvas canvas,
    Paint paint,
    double h,
    Offset hip,
    Offset foot, {
    required bool front,
  }) {
    final thigh = _thigh * h;
    final shin = _shin * h;
    final delta = foot - hip;
    final reach = delta.distance.clamp(0.001, thigh + shin - 0.001);

    // Law of cosines for the hip-to-knee angle off the hip-to-foot line.
    final cosA =
        ((thigh * thigh + reach * reach - shin * shin) / (2 * thigh * reach))
            .clamp(-1.0, 1.0);
    final base = atan2(delta.dy, delta.dx);
    // Knees bend forward, so the solution is always on the same side.
    final kneeAngle = base - acos(cosA);
    final knee = hip + Offset(cos(kneeAngle), sin(kneeAngle)) * thigh;

    paint.strokeWidth = (front ? 0.062 : 0.055) * h;
    canvas
      ..drawLine(hip, knee, paint)
      ..drawLine(knee, foot, paint)
      // Foot: a short stub forward of the ankle.
      ..drawLine(
        foot,
        foot + Offset(0.06 * h, 0),
        paint..strokeWidth = 0.042 * h,
      );
  }

  void _leg(
    Canvas canvas,
    Paint paint,
    double h,
    Offset hip,
    double hipAngle,
    double kneeBend, {
    required bool front,
  }) {
    final thigh = _thigh * h;
    final shin = _shin * h;
    final a = pi / 2 + hipAngle;
    final knee = hip + Offset(cos(a), sin(a)) * thigh;
    final b = a + kneeBend;
    final foot = knee + Offset(cos(b), sin(b)) * shin;

    paint.strokeWidth = (front ? 0.062 : 0.055) * h;
    canvas
      ..drawLine(hip, knee, paint)
      ..drawLine(knee, foot, paint)
      ..drawLine(
        foot,
        foot + Offset(0.06 * h, 0),
        paint..strokeWidth = 0.042 * h,
      );
  }

  void _arm(
    Canvas canvas,
    Paint paint,
    double h,
    Offset shoulder,
    double shoulderAngle,
    double elbowBend,
  ) {
    final upper = _upperArm * h;
    final fore = _foreArm * h;
    final a = pi / 2 + shoulderAngle;
    final elbow = shoulder + Offset(cos(a), sin(a)) * upper;
    final b = a + elbowBend;
    final hand = elbow + Offset(cos(b), sin(b)) * fore;

    paint.strokeWidth = 0.048 * h;
    canvas
      ..drawLine(shoulder, elbow, paint)
      ..drawLine(elbow, hand, paint);
  }
}
