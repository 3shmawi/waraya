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

  // Gait, as fractions of [height]. These say "running", not "walking": at
  // [WarayaConfig.walkSpeed] the character covers 2.3 of its own heights every
  // second, which is a run, and a walk cycle at running speed is what made the
  // figure look like it was being dragged along the ground.
  //
  /// Half the distance the foot travels along the ground, measured from the
  /// hip. Paired with `ProbeWalker._strideLength`: the grounded foot must
  /// travel backward exactly as fast as the body travels forward, or the feet
  /// slide.
  static const double _stride = 0.20;

  /// How high the swing foot lifts. A walk skims the ground; a run picks the
  /// knee up.
  static const double _lift = 0.15;

  /// Biases the lift early in the swing, so the heel snaps up behind the body
  /// before the leg reaches forward, instead of the foot floating through a
  /// symmetrical arc.
  static const double _tuck = 0.3;

  /// How far the shoulders sit ahead of the hips while moving. A runner leans
  /// into it; a figure that stays vertical reads as strolling however fast its
  /// legs move.
  static const double _lean = 0.085;

  /// How far the body rises at the moment both feet are off the ground.
  ///
  /// This is what makes it a run rather than a fast walk: in a walk one foot
  /// is always down. Here the whole body — feet included — lifts at the two
  /// points in the cycle where neither leg is bearing weight, and sinks to its
  /// lowest as it passes over the planted leg.
  static const double _flightRise = 0.065;

  /// Arm swing, in radians. Wider than a walk's, and the elbows stay folded.
  static const double _armSwing = 0.95;

  /// World units the body must cover for one full stride, i.e. one 2π of
  /// [phase], if the planted foot is not to slide.
  ///
  /// Derived rather than guessed: at mid-stance the grounded foot sweeps
  /// backward at `_stride · height` per radian, so the body has to advance at
  /// the same rate. Anything else is a moonwalk at the one moment in the cycle
  /// carrying the character's whole weight. Callers that move the body must
  /// advance [phase] against this, never against a number of their own.
  static double strideLengthFor(double height) => 2 * pi * _stride * height;

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
    // Lean while running, and keep leaning through a jump — snapping upright
    // in mid-air looks like a different character.
    final lean = moving || airborne ? _lean * h : 0.0;
    final hip = Offset(0, _hipY * h);
    final shoulder = Offset(lean, _shoulderY * h);

    // Twice per stride the body is thrown clear of the ground; twice it sinks
    // over a planted leg. Translating the whole figure lifts the feet with it,
    // which is the point — the flight phase is what separates a run from a
    // walk — and leaves the leg geometry untouched.
    final bob = moving && !airborne
        ? -_flightRise * h * (1 + cos(2 * phase)) / 2
        : 0.0;
    canvas.translate(0, bob);

    // Far limbs first, then the torso, then near limbs on top. Drawing both
    // arms before the body hid them behind it, which left the figure looking
    // one-armed.
    if (airborne) {
      _leg(canvas, paint, h, hip, -0.12, 0.55, front: false);
      _arm(canvas, paint, h, shoulder, -0.55, 0.8);
    } else if (moving) {
      _gaitLeg(canvas, paint, h, hip, phase + pi, front: false);
      _arm(
        canvas,
        paint,
        h,
        shoulder,
        _armSwing * sin(phase),
        _armSwing,
        elbowBase: 0.95,
        elbowRange: 0.65,
      );
    } else {
      _leg(canvas, paint, h, hip, -0.03, 0.02, front: false);
      _arm(canvas, paint, h, shoulder, -0.08, 0.6);
    }

    // Torso: a tapered trunk rather than a stick, so the body has mass.
    // The trunk slants: planted at the hips, carried forward at the shoulders.
    final torso = Path()
      ..moveTo(-0.070 * h, hip.dy)
      ..quadraticBezierTo(
        -0.088 * h + lean * 0.5,
        (hip.dy + shoulder.dy) / 2,
        -0.098 * h + lean,
        shoulder.dy,
      )
      ..lineTo(0.098 * h + lean, shoulder.dy)
      ..quadraticBezierTo(
        0.088 * h + lean * 0.5,
        (hip.dy + shoulder.dy) / 2,
        0.070 * h,
        hip.dy,
      )
      ..close();
    canvas.drawPath(torso, fill);
    canvas.drawPath(torso, paint..strokeWidth = 0.05 * h);

    // Neck and head.
    canvas.drawLine(
      Offset(lean, shoulder.dy),
      Offset(lean * 1.15, _neckY * h),
      paint..strokeWidth = 0.055 * h,
    );
    canvas.drawCircle(
      Offset(lean * 1.25 + 0.012 * h, _headY * h),
      _headR * h,
      fill,
    );

    // Near limbs, in front of the body.
    if (airborne) {
      _leg(canvas, paint, h, hip, 0.30, 1.35, front: true);
      _arm(canvas, paint, h, shoulder, -1.25, 0.8);
    } else if (moving) {
      _gaitLeg(canvas, paint, h, hip, phase, front: true);
      _arm(
        canvas,
        paint,
        h,
        shoulder,
        _armSwing * sin(phase + pi),
        _armSwing,
        elbowBase: 0.95,
        elbowRange: 0.65,
      );
    } else {
      _leg(canvas, paint, h, hip, 0.03, 0.02, front: true);
      _arm(canvas, paint, h, shoulder, 0.10, 0.6);
    }

    canvas.restore();
  }

  /// Where the foot is at this point in the stride, relative to the hip, for a
  /// figure of height [height] facing +x.
  ///
  /// The foot traces a flattened ellipse. The half of the cycle where it is
  /// lifted is the half where it travels **forward**; the half where it is on
  /// the ground is the half where it travels **backward**, because a planted
  /// foot stays put while the body passes over it.
  ///
  /// Getting that backwards is not subtle to look at and is invisible in the
  /// code: the legs simply moonwalk. `figure_test.dart` pins it.
  static Offset footOffset(double phase, double height) {
    // The (1 + tuck·cos) factor pushes the peak of the lift earlier in the
    // swing without ever going negative, so the heel comes up behind the body
    // first and the leg reaches forward after. It is the difference between a
    // knee that drives and a foot that wafts.
    final swing = max(0.0, sin(phase)) * (1 + _tuck * cos(phase));
    return Offset(-_stride * height * cos(phase), -_lift * height * swing);
  }

  void _gaitLeg(
    Canvas canvas,
    Paint paint,
    double h,
    Offset hip,
    double phase, {
    required bool front,
  }) {
    _legToFoot(canvas, paint, h, hip, footOffset(phase, h), front: front);
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

    // At the ends of the stride the ideal foot is further from the hip than
    // the leg is long. The old code solved the knee against a clamped reach
    // but still drew the shin all the way out to the ankle, so the leg
    // visibly stretched twice per stride. Pull the ankle in to where the leg
    // can actually put it instead: a couple of units of slide at the extremes
    // -- where the foot is off the ground anyway -- costs nothing, and a
    // rubber leg costs the whole silhouette.
    final limit = thigh + shin - 0.012 * h;
    final distance = delta.distance;
    final ankle = distance > limit ? hip + delta * (limit / distance) : foot;
    final reach = distance.clamp(0.001, limit);

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
      ..drawLine(knee, ankle, paint)
      // Foot: a short stub forward of the ankle.
      ..drawLine(
        ankle,
        ankle + Offset(0.06 * h, 0),
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

  /// One arm. [shoulderAngle] is positive swinging backward.
  ///
  /// The elbow flexes toward the front of the body, which is the opposite
  /// rotation to the one the first version used — that one curled the leading
  /// arm's forearm back inside the torso, where a silhouette swallows it, and
  /// left the figure looking one-armed however wide the shoulders swung. The
  /// leading arm also bends much more than the trailing one, as a real arm
  /// does.
  void _arm(
    Canvas canvas,
    Paint paint,
    double h,
    Offset shoulder,
    double shoulderAngle,
    double swingAmplitude, {

    /// How folded the elbow is at mid-swing. A run holds it near a right
    /// angle throughout; a standing arm hangs nearly straight.
    double elbowBase = 0.5,

    /// How much the fold opens and closes across the swing.
    double elbowRange = 0.45,
  }) {
    final upper = _upperArm * h;
    final fore = _foreArm * h;
    final elbowBend = swingAmplitude <= 0
        ? elbowBase
        : (elbowBase - elbowRange * (shoulderAngle / swingAmplitude)).clamp(
            0.05,
            1.8,
          );
    final a = pi / 2 + shoulderAngle;
    final elbow = shoulder + Offset(cos(a), sin(a)) * upper;
    final b = a - elbowBend;
    final hand = elbow + Offset(cos(b), sin(b)) * fore;

    paint.strokeWidth = 0.048 * h;
    canvas
      ..drawLine(shoulder, elbow, paint)
      ..drawLine(elbow, hand, paint);
  }
}
