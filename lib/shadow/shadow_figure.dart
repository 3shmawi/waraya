import 'dart:ui';

import 'package:flame/components.dart';

import '../game/character/figure.dart';
import 'snapshot.dart';

/// The shadow: the player's own body, replayed.
///
/// It has **no movement logic at all** — no velocity, no gravity, no input. It
/// is handed a [PoseSnapshot] and puts itself there. That is the whole reason the
/// plan records transforms instead of inputs: there is nothing here that can
/// disagree with what the player actually did.
class ShadowFigure extends PositionComponent {
  ShadowFigure({required this.color, this.opacity = 0.5, super.priority = 90})
    : super(size: Vector2(44, 96), anchor: Anchor.bottomCenter);

  final Color color;

  /// Live-tuned from the debug panel, which is also what clamps it.
  double opacity;

  PoseSnapshot? _snapshot;
  PoseSnapshot? get snapshot => _snapshot;

  /// How far the shadow moved horizontally on its last placement. The scene
  /// uses it to carry a player who is standing on it.
  double lastStepX = 0;

  /// Until the buffer has filled, the shadow does not exist — it is not drawn,
  /// it is not solid, and it cannot kill.
  bool get isActive => _snapshot != null;

  late final Figure _figure = Figure(height: size.y, color: color);

  Rect get bounds =>
      Rect.fromLTWH(x - size.x / 2, y - size.y, size.x, size.y);

  void apply(PoseSnapshot next) {
    final previous = _snapshot;
    lastStepX = previous == null ? 0 : next.x - previous.x;
    _snapshot = next;
    position.setValues(next.x, next.y);
  }

  void clear() {
    _snapshot = null;
    lastStepX = 0;
  }

  @override
  void render(Canvas canvas) {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    // One translucent layer for the whole body, not a translucent paint per
    // limb: the figure's arms, legs and torso overlap, and per-stroke alpha
    // makes the overlaps darker than the rest, so the silhouette stops
    // reading as one shape.
    canvas.saveLayer(
      Rect.fromLTWH(-size.x, -size.y * 0.4, size.x * 3, size.y * 1.6),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
    canvas.translate(size.x / 2, size.y);
    _figure.render(
      canvas,
      phase: snapshot.stridePhase,
      moving: snapshot.state.isMoving,
      airborne: snapshot.state.isAirborne,
      facing: snapshot.facing,
    );
    canvas.restore();
  }
}
