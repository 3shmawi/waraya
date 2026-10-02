import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// A small burst of dust, drawn and then gone (`docs/phase-11-feel.md` §5).
///
/// **Paint only.** Nothing collides with it, nothing reads it, and it is not
/// on the fixed tick: a puff is the game saying *that landing was hard* or
/// *you came apart there*, and neither changes where anybody is. The recorded
/// solutions pass through it without noticing, which `look_test.dart` holds
/// it to.
///
/// No `Random` either, even though a puff cannot change play: the clips are
/// rendered from the game frame by frame, and a clip that comes out different
/// every time it is rendered is a clip nobody can check against the last one.
/// The spread is a fixed scatter turned by [seed].
class Puff extends PositionComponent {
  Puff({
    required Vector2 at,
    required this.color,
    this.count = 10,
    this.spread = 60,
    this.lift = 40,
    this.life = 0.5,
    this.size0 = 4,
    this.seed = 0,
  }) : super(position: at, priority: 95);

  /// A landing: a low, wide spray at the feet.
  factory Puff.landing(
    Vector2 feet, {
    required Color color,
    double weight = 1,
  }) => Puff(
    at: feet,
    color: color,
    count: (6 + 8 * weight).round(),
    spread: 50 + 50 * weight,
    lift: 18 + 18 * weight,
    life: 0.45,
    size0: 3.5,
    seed: feet.x.round(),
  );

  /// A death: the body coming apart into dust where it stood.
  factory Puff.death(Vector2 feet, {required Color color}) => Puff(
    at: feet - Vector2(0, 48),
    color: color,
    count: 26,
    spread: 90,
    lift: 70,
    life: 0.8,
    size0: 6,
    seed: feet.x.round() ^ 0x5f,
  );

  final Color color;
  final int count;
  final double spread;
  final double lift;
  final double life;
  final double size0;

  /// Turns the scatter, so two puffs in a row are not the same shape.
  final int seed;

  double _age = 0;

  /// Gravity on the motes, in world units per second squared. Lighter than
  /// the body's: dust hangs.
  static const double _fall = 260;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / life).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: color.a * (1 - t) * (1 - t));
    for (var i = 0; i < count; i++) {
      // A fixed scatter: the golden angle walks round the circle without
      // bunching, and the seed turns the whole pattern so two puffs in a row
      // are not the same shape.
      final angle = (i * 2.399963 + seed * 0.37) % (2 * pi);
      final reach = 0.35 + 0.65 * ((i * 7 + seed) % 11) / 10;
      final vx = cos(angle) * spread * reach;
      // Upwards mostly; dust kicked into the floor goes nowhere.
      final vy = -(0.4 + 0.6 * sin(angle).abs()) * lift * reach;
      final x = vx * _age;
      final y = vy * _age + 0.5 * _fall * _age * _age;
      final r = size0 * (1 - 0.5 * t) * (0.6 + 0.4 * reach);
      canvas.drawCircle(Offset(x, min(y, 0)), r, paint);
    }
  }
}
