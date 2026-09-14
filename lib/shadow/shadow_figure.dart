import 'dart:ui';

import 'package:flame/components.dart';

import '../game/character/figure.dart';
import '../game/config.dart';
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

  PoseSnapshot? _previous;

  /// How far the game is into the current fixed tick, 0 to 1.
  ///
  /// The buffer only produces a new position 60 times a second; on a 120Hz
  /// screen that is every other frame, and the shadow visibly steps. Blending
  /// from the previous snapshot to the current one over the tick smooths it
  /// out — the plan says to look first and only smooth if the stepping shows,
  /// and it shows.
  ///
  /// Rendering only. [position] and [bounds] stay on the tick, so what the
  /// shadow stands on and what it kills are still exactly what was recorded.
  double alpha = 0;

  /// How far the shadow moved horizontally on its last placement. The scene
  /// uses it to carry a player who is standing on it.
  double lastStepX = 0;

  /// Until the buffer has filled, the shadow does not exist — it is not drawn,
  /// it is not solid, and it cannot kill.
  bool get isActive => _snapshot != null;

  late final Figure _figure = Figure(height: size.y, color: color);

  /// Sized from the recorded pose: a shadow that was crouching is a shorter
  /// thing to stand on and a shorter thing to walk into.
  Rect get bounds {
    final fold = _snapshot?.crouch ?? 0;
    final height = size.y * (1 - (1 - WarayaConfig.crouchHeightFactor) * fold);
    return Rect.fromLTWH(x - size.x / 2, y - height, size.x, height);
  }

  void apply(PoseSnapshot next) {
    final previous = _snapshot;
    lastStepX = previous == null ? 0 : next.x - previous.x;
    _previous = previous ?? next;
    _snapshot = next;
    position.setValues(next.x, next.y);
  }

  void clear() {
    _snapshot = null;
    _previous = null;
    lastStepX = 0;
    alpha = 0;
  }

  /// Where the body should be drawn this frame, relative to [position].
  ///
  /// Behind by up to one tick — 16ms — which is the price of interpolating
  /// between two known positions rather than guessing at a third.
  Offset get renderOffset {
    final previous = _previous;
    final current = _snapshot;
    if (previous == null || current == null) return Offset.zero;
    final back = 1 - alpha.clamp(0.0, 1.0);
    return Offset(
      (previous.x - current.x) * back,
      (previous.y - current.y) * back,
    );
  }

  @override
  void render(Canvas canvas) {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    // One translucent layer for the whole body, not a translucent paint per
    // limb: the figure's arms, legs and torso overlap, and per-stroke alpha
    // makes the overlaps darker than the rest, so the silhouette stops
    // reading as one shape.
    final smoothing = renderOffset;
    canvas.translate(smoothing.dx, smoothing.dy);
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
      crouch: snapshot.crouch,
    );
    canvas.restore();
  }
}
