import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'level.dart';

/// Something that might be moving, as a dog sees it: which body (the player
/// is -1, pasts by their place), where it is, and whether it is moving.
typedef Mover = ({int id, double x, bool moving});

/// A street dog keeping its stretch ([DogSpec]).
///
/// Moved only by [tick], on the level's fixed clock, from where the bodies
/// are — so it is in the same place every time the same run is played, and a
/// recorded solution that gets past it keeps getting past it.
class Dog extends PositionComponent {
  Dog(this.spec, {this.look = LevelLook.greyBox, super.priority = 85})
    : _x = spec.home;

  final DogSpec spec;
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

  static const double bodyWidth = 64;
  static const double bodyHeight = 40;

  /// Faster than you walk (220): you cannot outrun it on its own ground.
  static const double chaseSpeed = 320;

  /// Back to where it sits, unhurried.
  static const double homeSpeed = 140;

  /// How far outside its stretch it notices something moving.
  static const double sight = 150;

  /// A body has to move at least this far in a tick to count as moving.
  static const double _still = 0.3;

  double _x;
  double get along => _x;

  /// Which way it is facing, -1 or 1.
  double facing = -1;

  /// What it is running at, if anything.
  Mover? target;

  /// Whether it is after the player — the only thing it can see off.
  bool get afterYou => target?.id == -1;

  /// How far its legs have gone, for drawing the run. Distance, not time,
  /// so it is the same on any screen.
  double _stride = 0;

  /// From 1 when it has just seen somebody off, down to 0. Paint only.
  double _bark = 0;

  double get floor => spec.area.bottom;

  Rect get bounds => Rect.fromLTWH(
    _x - bodyWidth / 2,
    floor - bodyHeight,
    bodyWidth,
    bodyHeight,
  );

  double get _left => spec.area.left + bodyWidth / 2;
  double get _right => spec.area.right - bodyWidth / 2;

  /// Whether [x] is near enough its stretch for it to notice.
  bool _inSight(double x) =>
      x >= spec.area.left - sight && x <= spec.area.right + sight;

  /// One fixed tick: keep after whatever it is after, or pick something new
  /// — or, with nothing moving, go home.
  ///
  /// **It does not let go.** Once it is after something it stays after it
  /// for as long as that keeps moving in sight, however near anything else
  /// comes; only when it stops, or goes, does the dog pick again — the
  /// nearest thing moving, by how far along the ground, at any height (it
  /// runs underneath you on a ledge, barking, and cannot get at you there).
  /// Ties go to whatever comes first in [movers]: the game lists your pasts
  /// before you, so a tie is your past's.
  void tick(double dt, Iterable<Mover> movers) {
    Mover? still;
    Mover? nearest;
    for (final mover in movers) {
      if (!mover.moving || !_inSight(mover.x)) continue;
      if (mover.id == target?.id) still = mover;
      if (nearest == null || (mover.x - _x).abs() < (nearest.x - _x).abs()) {
        nearest = mover;
      }
    }
    nearest = still ?? nearest;
    target = nearest;
    final goal = (nearest?.x ?? spec.home).clamp(_left, _right).toDouble();
    final speed = nearest == null ? homeSpeed : chaseSpeed;
    final step = (goal - _x).clamp(-speed * dt, speed * dt).toDouble();
    _x += step;
    _stride += step.abs();
    if (step.abs() > 0.01) {
      facing = step.sign;
    } else if (nearest != null) {
      facing = (nearest.x - _x).sign == 0 ? facing : (nearest.x - _x).sign;
    }
    _bark = max(0, _bark - dt * 2.5);
  }

  /// Whether a body moved enough between two of its x positions to count.
  static bool moved(double from, double to) => (to - from).abs() > _still;

  /// It has just seen you off.
  void barked() => _bark = 1;

  void reset() {
    _x = spec.home;
    facing = -1;
    target = null;
    _stride = 0;
    _bark = 0;
  }

  @override
  void render(Canvas canvas) {
    final body = _lit ? SilhouettePalette.bodyColor : const Color(0xFF2A2420);
    final edge = _lit ? SilhouettePalette.blockTop : const Color(0xFF8C8C8C);
    final paint = Paint()..color = body;
    final legs = Paint()
      ..color = body
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Its ground: a worn strip of floor with a scuff at each end, so where
    // it stops is something you can see. Flat on the floor — anything
    // standing up here is something the player tries to climb.
    final worn = Paint()
      ..color = (_lit ? const Color(0xFF3A2C30) : const Color(0xFF5A5A5A))
          .withValues(alpha: 0.7);
    canvas.drawRect(
      Rect.fromLTRB(spec.area.left, floor - 2, spec.area.right, floor + 3),
      worn,
    );
    for (final end in [spec.area.left, spec.area.right]) {
      canvas.drawRect(Rect.fromLTRB(end - 2, floor - 6, end + 2, floor), worn);
    }

    canvas.save();
    canvas.translate(_x, floor);
    if (facing > 0) canvas.scale(-1, 1);
    // Drawn facing left, feet on y = 0.
    final running = target != null;
    final swing = running ? sin(_stride / 9) * 9 : 0.0;
    // Legs: front pair and back pair, swinging against each other.
    for (final (hip, phase) in [
      (-18.0, 1.0),
      (-12.0, -1.0),
      (16.0, -1.0),
      (22.0, 1.0),
    ]) {
      canvas.drawLine(Offset(hip, -16), Offset(hip + swing * phase, -1), legs);
    }
    // Body, a little arched.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-24, -30, 50, 16),
        const Radius.circular(8),
      ),
      paint,
    );
    // Neck and head, lower and further forward when it is running.
    final headY = running ? -30.0 : -38.0;
    canvas.drawPath(
      Path()
        ..moveTo(-20, -28)
        ..lineTo(-30, headY - 2)
        ..lineTo(-24, headY + 8)
        ..close(),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-42, headY - 6, 20, 12),
        const Radius.circular(5),
      ),
      paint,
    );
    // Snout and ear.
    canvas.drawRect(Rect.fromLTWH(-48, headY - 1, 8, 6), paint);
    canvas.drawPath(
      Path()
        ..moveTo(-30, headY - 5)
        ..lineTo(-26, headY - 14)
        ..lineTo(-23, headY - 4)
        ..close(),
      paint,
    );
    // Tail, up when running, down when it is not.
    canvas.drawLine(
      const Offset(25, -27),
      Offset(36, running ? -40 : -18),
      legs..strokeWidth = 4,
    );
    // The backlight along its back, so a black dog reads on a black floor.
    canvas.drawLine(
      const Offset(-20, -30),
      const Offset(22, -30),
      Paint()
        ..color = edge
        ..strokeWidth = 1.5,
    );
    // Barking: three short lines out of the mouth while it is after
    // something, louder for a moment after it has seen you off.
    if (running || _bark > 0) {
      final loud = 0.5 + 0.5 * _bark;
      final bark = Paint()
        ..color = edge.withValues(alpha: loud)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final dy in [-7.0, 0.0, 7.0]) {
        canvas.drawLine(
          Offset(-54, headY + 2 + dy * 0.6),
          Offset(-62 - 6 * _bark, headY + 2 + dy),
          bark,
        );
      }
    }
    canvas.restore();
  }
}
