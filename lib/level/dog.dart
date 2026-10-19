import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'level.dart';

/// Something that might be moving, as a dog sees it: which body (the player
/// is -1, pasts by their place), where it is, and whether it is moving.
typedef Mover = ({int id, double x, bool moving});

/// A bark the game should make heard: at you, or at your past.
enum Bark { atYou, atPast }

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

  /// Seconds since it last barked, and the bark the game has not played yet.
  double _sinceBark = 99;
  Bark? _due;

  /// How often it barks while it is after you, and after your past.
  static const double _barkEvery = 0.75;
  static const double _barkAtPastEvery = 1.3;

  /// From 1 when it has just bitten, down to 0: the lunge. Paint only.
  double _lunge = 0;
  static const double _lungeSeconds = 0.4;

  /// Seconds it has been drawn, for the wag and the jaw. Paint only: it
  /// never moves anything, so it runs on the frame clock.
  double _clock = 0;

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
    final was = target?.id;
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

    // The barks: the moment it turns on something, and every so often for as
    // long as it is after it. On the tick, so a run always sounds the same.
    _sinceBark += dt;
    final turned = nearest != null && nearest.id != was;
    if (afterYou && (turned || _sinceBark >= _barkEvery)) {
      _due = Bark.atYou;
      _sinceBark = 0;
    } else if (nearest != null &&
        !afterYou &&
        (turned || _sinceBark >= _barkAtPastEvery)) {
      _due = Bark.atPast;
      _sinceBark = 0;
    }
  }

  /// Whether a body moved enough between two of its x positions to count.
  static bool moved(double from, double to) => (to - from).abs() > _still;

  /// The bark the game has not played yet, once.
  Bark? takeBark() {
    final bark = _due;
    _due = null;
    return bark;
  }

  /// It has got you.
  void bite() {
    _lunge = 1;
    _sinceBark = 0;
  }

  void reset() {
    _x = spec.home;
    facing = -1;
    target = null;
    _stride = 0;
    _sinceBark = 99;
    _due = null;
    _lunge = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    _lunge = max(0, _lunge - dt / _lungeSeconds);
  }

  @override
  void render(Canvas canvas) {
    final body = _lit ? SilhouettePalette.bodyColor : const Color(0xFF2A2420);
    final edge = _lit ? SilhouettePalette.blockTop : const Color(0xFF9A9A9A);

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
    _drawDog(canvas, body, edge);
    canvas.restore();
  }

  /// The dog itself, facing left, feet on y = 0.
  ///
  /// Four ways of standing, all from state the game already has: sitting at
  /// home with its tail going; trotting home; running at something, low,
  /// neck out, ears back, barking; and the lunge when it has got you —
  /// stretched out, front feet off the ground, jaws wide.
  void _drawDog(Canvas canvas, Color body, Color edge) {
    final running = target != null;
    final homeward = !running && (spec.home - _x).abs() > 1;
    final sitting = !running && !homeward;
    final lunge = _Lunge.of(_lunge);

    // The gait, from distance run: a gallop when running, a trot going home.
    final phase = _stride / (running ? 16 : 11);
    final bob = running
        ? -3 * sin(phase).abs()
        : (homeward ? -1.5 * sin(phase * 2).abs() : 0.0);

    final fill = Paint()..color = body;
    final limb = Paint()
      ..color = body
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(-6 * lunge, bob - 4 * lunge);

    // Legs first, behind the body: two pairs, each leg a thigh and a shin.
    void leg(Offset hip, double swing, {double thigh = 11, double shin = 11}) {
      final knee = hip + Offset(sin(swing) * thigh, cos(swing) * thigh);
      final paw =
          knee + Offset(sin(swing * 1.3 - 0.2) * shin, cos(swing * 0.6) * shin);
      canvas.drawLine(hip, knee, limb..strokeWidth = 5);
      canvas.drawLine(knee, paw, limb..strokeWidth = 3.5);
    }

    final rumpY = sitting ? -14.0 : -24.0;
    if (sitting) {
      // Haunches down, front legs straight.
      canvas.drawOval(const Rect.fromLTWH(6, -20, 22, 20), fill);
      leg(const Offset(-14, -20), 0.05, thigh: 10, shin: 10);
      leg(const Offset(-9, -20), -0.05, thigh: 10, shin: 10);
    } else {
      final amp = running ? 0.75 : 0.4;
      final reach = lunge * 1.1;
      leg(const Offset(-16, -20), amp * sin(phase) - reach);
      leg(const Offset(-11, -20), amp * sin(phase + 0.6) - reach);
      leg(const Offset(14, -20), amp * sin(phase + pi) + reach * 0.5);
      leg(const Offset(19, -20), amp * sin(phase + pi + 0.6) + reach * 0.5);
    }

    // The body: deep chest at the front, tucked belly, rump behind.
    final back = Path()
      ..moveTo(-20, -33)
      ..quadraticBezierTo(
        2,
        -36 - (running ? 2 * sin(phase) : 0),
        24,
        rumpY - 6,
      )
      ..quadraticBezierTo(30, rumpY + 2, 22, rumpY + 8)
      ..quadraticBezierTo(8, -17, -6, -16)
      ..quadraticBezierTo(-22, -14, -24, -24)
      ..close();
    canvas.drawPath(back, fill);

    // The tail: out behind when running, wagging when it sits.
    final wag = sitting ? sin(_clock * 11) * 0.5 : 0.0;
    final tailUp = running ? -0.9 : (sitting ? -0.4 : -0.2);
    final tailBase = Offset(24, rumpY - 4);
    final tailMid =
        tailBase + Offset(cos(tailUp + wag) * 9, sin(tailUp + wag) * 9);
    final tailTip =
        tailMid +
        Offset(cos(tailUp * 1.4 + wag) * 9, sin(tailUp * 1.4 + wag) * 9);
    canvas.drawPath(
      Path()
        ..moveTo(tailBase.dx, tailBase.dy)
        ..quadraticBezierTo(tailMid.dx, tailMid.dy, tailTip.dx, tailTip.dy),
      limb..strokeWidth = 3.5,
    );

    // The neck: thick, from the shoulders to the head, and where the head
    // goes says what the dog is doing — up and still at home, out and low
    // after something, all the way out when it has got you.
    final headAt = Offset.lerp(
      sitting
          ? const Offset(-24, -50)
          : running
          ? Offset(-38, -36 + 2 * sin(phase * 2))
          : const Offset(-34, -42),
      const Offset(-48, -32),
      lunge,
    )!;
    final shoulder = const Offset(-14, -30);
    canvas.drawLine(
      shoulder,
      headAt + const Offset(4, 3),
      limb..strokeWidth = 11,
    );

    // The head: skull, muzzle, and a jaw that opens on every bark.
    canvas.drawCircle(headAt, 7.5, fill);
    final barking = running ? max(0.0, sin(_clock * 14)) : 0.0;
    final jaw = max(barking * 0.45, lunge * 0.8);
    canvas.drawPath(
      Path()
        ..moveTo(headAt.dx - 2, headAt.dy - 5)
        ..lineTo(headAt.dx - 15, headAt.dy - 2)
        ..lineTo(headAt.dx - 15, headAt.dy + 2)
        ..lineTo(headAt.dx - 2, headAt.dy + 2)
        ..close(),
      fill,
    );
    canvas.save();
    canvas.translate(headAt.dx - 2, headAt.dy + 2);
    canvas.rotate(-jaw);
    canvas.drawRect(const Rect.fromLTWH(-12, 0, 12, 3.5), fill);
    canvas.restore();

    // An ear: pricked when it sits, laid back when it runs.
    final earBack = running ? 0.9 : (sitting ? 0.0 : 0.4);
    final earBase = headAt + const Offset(2, -5);
    canvas.drawPath(
      Path()
        ..moveTo(earBase.dx - 3, earBase.dy)
        ..lineTo(earBase.dx + sin(earBack) * 9, earBase.dy - cos(earBack) * 9)
        ..lineTo(earBase.dx + 4, earBase.dy + 1)
        ..close(),
      fill,
    );

    // The backlight along its back, so a black dog reads on a black floor.
    canvas.drawPath(
      Path()
        ..moveTo(-18, -34)
        ..quadraticBezierTo(
          2,
          -37 - (running ? 2 * sin(phase) : 0),
          22,
          rumpY - 7,
        ),
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // The bark itself, out of the open mouth.
    if (jaw > 0.25) {
      final loud = ((jaw - 0.25) / 0.55).clamp(0.0, 1.0);
      final lines = Paint()
        ..color = edge.withValues(alpha: 0.4 + 0.6 * loud)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final mouth = headAt + const Offset(-17, 1);
      for (final dy in [-7.0, 0.0, 7.0]) {
        canvas.drawLine(
          mouth + Offset(-3, dy * 0.5),
          mouth + Offset(-9 - 5 * loud, dy),
          lines,
        );
      }
    }
    canvas.restore();
  }
}

/// The lunge's shape over its short life: out fast, back slowly.
abstract final class _Lunge {
  static double of(double left) {
    if (left <= 0) return 0;
    final t = 1 - left;
    return t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
  }
}
