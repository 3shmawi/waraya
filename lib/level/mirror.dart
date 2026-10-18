import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flame/components.dart';

import '../game/character/figure.dart';
import 'level.dart';

/// A mirror (`Level.mirrors`, on the bench): when your past arrives on it,
/// you are put where it is.
///
/// Drawn as what it is called, a full-length standing mirror like the one on
/// a wardrobe door: an arched pane of pale glass on two short feet, with your
/// past standing in it. Pale and not dark on purpose — a dark upright in
/// this game is something the player tries to stand on, and this is not
/// solid. It is drawn behind the bodies, so you walk in front of it.
class Mirror extends PositionComponent {
  Mirror(this.area, {this.look = LevelLook.greyBox, super.priority = -7});

  /// The slab on the floor, as in the level's data. The glass stands on it.
  final Rect area;
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

  /// What a body has to be standing on to be on the mirror: the slab, and a
  /// little above it, the same shape a plate's and a key's are.
  Rect get trigger =>
      Rect.fromLTRB(area.left, area.top - 28, area.right, area.bottom + 2);

  /// How tall the glass stands above the slab.
  static const double glassHeight = 112;

  /// Which pasts were on it last frame, by their place in the level's list.
  final Set<int> _on = {};

  /// From 1 the moment it sends you, down to 0 a moment later. Paint only.
  double _flash = 0;
  static const double _flashSeconds = 0.4;

  /// Feeds whether past [past] is on the mirror this frame, and says whether
  /// it just **arrived** — on now, not on last frame, and not put here by a
  /// mirror itself ([warped]).
  bool arrived(int past, {required bool on, required bool warped}) {
    final was = _on.contains(past);
    if (on) {
      _on.add(past);
    } else {
      _on.remove(past);
    }
    return on && !was && !warped;
  }

  /// It just sent somebody.
  void flash() => _flash = 1;

  void reset() {
    _on.clear();
    _flash = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flash = max(0, _flash - dt / _flashSeconds);
  }

  /// The pane, arched at the top.
  Rect get _pane {
    final width = max(area.width - 8, 30.0);
    return Rect.fromLTWH(
      area.center.dx - width / 2,
      area.top - glassHeight,
      width,
      glassHeight - 8,
    );
  }

  @override
  void render(Canvas canvas) {
    final pane = _pane;
    final arch = RRect.fromRectAndCorners(
      pane,
      topLeft: Radius.circular(pane.width / 2),
      topRight: Radius.circular(pane.width / 2),
    );
    final frame = _lit ? SilhouettePalette.blockTop : const Color(0xFF4A4A4A);
    final cold = _lit ? SilhouettePalette.shadowColor : const Color(0xFFD6E2EE);

    // Its feet, on the slab.
    final feet = Paint()
      ..color = frame
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final dx in [pane.width * 0.3, -pane.width * 0.3]) {
      canvas.drawLine(
        Offset(pane.center.dx + dx * 0.8, pane.bottom),
        Offset(pane.center.dx + dx, area.top),
        feet,
      );
    }

    // The glass: cold and pale, lighter at the top where the light hits it.
    canvas.drawRRect(
      arch,
      Paint()
        ..shader = ui.Gradient.linear(pane.topCenter, pane.bottomCenter, [
          cold.withValues(alpha: _lit ? 0.75 : 0.95),
          cold.withValues(alpha: _lit ? 0.35 : 0.7),
        ]),
    );

    canvas.save();
    canvas.clipRRect(arch);
    // Your past, standing in it, turned to face out. The one thing in the
    // game that is cold and pale is your past, so a pane with it inside says
    // which side of the glass this is about.
    canvas.save();
    canvas.translate(pane.center.dx, pane.bottom - 4);
    Figure(
      height: pane.height * 0.62,
      color: (_lit ? const Color(0xFF8C9AAD) : const Color(0xFF8D9AA8))
          .withValues(alpha: 0.8),
    ).render(canvas, phase: 0, moving: false, airborne: false, facing: -1);
    canvas.restore();
    // Two streaks of sheen across the glass: what makes a pale shape glass.
    final sheen = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(pane.left + pane.width * 0.15, pane.top + pane.height * 0.55),
      Offset(pane.left + pane.width * 0.7, pane.top + pane.height * 0.2),
      sheen,
    );
    canvas.drawLine(
      Offset(pane.left + pane.width * 0.35, pane.top + pane.height * 0.62),
      Offset(pane.left + pane.width * 0.75, pane.top + pane.height * 0.39),
      sheen..strokeWidth = 2.5,
    );
    if (_flash > 0) {
      canvas.drawRRect(
        arch,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: _flash),
      );
    }
    canvas.restore();

    canvas.drawRRect(
      arch,
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // The slab it stands on.
    canvas.drawRect(
      area,
      Paint()..color = _lit ? const Color(0xFF1C1418) : const Color(0xFF3E3E3E),
    );
    canvas.drawRect(
      Rect.fromLTWH(area.left, area.top, area.width, 2),
      Paint()..color = _lit ? SilhouettePalette.blockTop : Palette.blockTop,
    );
  }
}

/// A ring opening out and fading where a body was taken from or put down by
/// a mirror, so a body vanishing from one place and appearing in another
/// reads as that rather than as a frame skipping. Paint only, no `Random`.
class MirrorRing extends PositionComponent {
  MirrorRing(Offset at, {required this.color})
    : super(position: Vector2(at.dx, at.dy), priority: 95);

  final Color color;
  double _age = 0;
  static const double _seconds = 0.45;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _seconds) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_age / _seconds).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: 40 + 70 * t,
        height: 110 + 50 * t,
      ),
      Paint()
        ..color = color.withValues(alpha: 1 - t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t) + 1,
    );
  }
}
