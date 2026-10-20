import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'level.dart';
import 'props.dart';

/// A basket on a rope (`Level.baskets`, on the bench): up while somebody
/// pulls, down when they let go ([BasketSpec]).
///
/// It does not move itself. The game moves it, once a frame and before
/// anything else does ([lift]), so that it can carry whoever is standing in
/// it by exactly as far as it went — a floor that left its rider behind for
/// a frame would have them falling a few units onto it every frame on the
/// way down, which is a body that never quite lands.
///
/// Drawn as the woven basket on a rope that a flat lowers from its balcony
/// for the bread: the weave, the handle, and two ropes going up out of the
/// view. The ropes are lit, like a lamp's cord, for the reason every upright
/// in this game is: a dark vertical in reach is something to stand on.
class Basket extends PositionComponent {
  Basket(this.spec, {this.look = LevelLook.greyBox, super.priority = -6});

  final BasketSpec spec;
  final LevelLook look;

  String get id => spec.id;

  /// What its rope is asking of it, by the same rule a door's plates are.
  late final Held _held = Held(spec.lingerSeconds);

  /// How far up it is now, from 0 (resting) to [BasketSpec.rise].
  double get raised => _raised;
  double _raised = 0;

  /// Whether it is being pulled this frame.
  bool get pulled => _held.wanted;

  /// Where it is now: what you stand on, and what you bump into.
  Rect get bounds => spec.area.translate(0, -_raised);

  /// Which shape the plates and keys pulling it carry ([PairMark]).
  int? mark;

  /// Asks it again. See [Held.ask]; true if the answer changed.
  bool hold(bool pull, {bool forcedDown = false, bool lingers = true}) =>
      _held.ask(pull, forcedShut: forcedDown, lingers: lingers);

  /// Moves it for [dt] seconds towards where it is being asked to be, and
  /// says how far it went, up negative — so a rider can be moved with it.
  double lift(double dt) {
    _held.tick(dt);
    final target = pulled ? spec.rise : 0.0;
    final step = BasketSpec.speed * dt;
    final before = _raised;
    _raised = _raised < target
        ? min(target, _raised + step)
        : max(target, _raised - step);
    return before - _raised;
  }

  /// Whether a body with its feet at [feet] and its middle at [x] is
  /// standing in it. By the feet, the way standing on a past is
  /// (`LevelGame._carrier`), and with half a body's grace either side.
  bool carries({required double x, required double feet}) {
    final top = bounds;
    return (feet - top.top).abs() <= 2 &&
        x + 22 > top.left &&
        x - 22 < top.right;
  }

  void reset() {
    _raised = 0;
    _held.reset();
  }

  @override
  void render(Canvas canvas) {
    final box = bounds;
    if (look != LevelLook.silhouette) {
      // The bench measures. The slab, and the top of its rope drawn as an
      // outline so you can see how high it goes.
      canvas.drawRect(
        spec.up,
        Paint()
          ..color = const Color(0x40FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawRect(box, Paint()..color = Palette.blockFill);
      canvas.drawRect(
        Rect.fromLTWH(box.left, box.top, box.width, 2),
        Paint()..color = Palette.blockTop,
      );
      _rope(canvas, box, const Color(0x99FFFFFF));
      PairMark.draw(canvas, mark, box.center, lit: pulled, look: look, size: 8);
      return;
    }

    _rope(canvas, box, const Color(0x66FFE7B0));
    // The handle: an arch over the top, thin and lit like the rope it is
    // tied to.
    canvas.drawArc(
      Rect.fromLTRB(box.left + 8, box.top - 26, box.right - 8, box.top + 20),
      pi,
      pi,
      false,
      Paint()
        ..color = const Color(0x66FFE7B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // The basket, a little wider at the rim than at the bottom.
    final body = Path()
      ..moveTo(box.left, box.top)
      ..lineTo(box.right, box.top)
      ..lineTo(box.right - 6, box.bottom)
      ..lineTo(box.left + 6, box.bottom)
      ..close();
    canvas.drawPath(body, Paint()..color = SilhouettePalette.blockFill);
    // The weave, in the dark of the basket itself: just enough to say wicker.
    canvas.save();
    canvas.clipPath(body);
    final weave = Paint()
      ..color = const Color(0xFF2A1E18)
      ..strokeWidth = 1.2;
    for (var x = box.left - box.height; x < box.right; x += 9) {
      canvas.drawLine(
        Offset(x, box.bottom),
        Offset(x + box.height, box.top),
        weave,
      );
      canvas.drawLine(
        Offset(x, box.top),
        Offset(x + box.height, box.bottom),
        weave,
      );
    }
    canvas.restore();
    // The rim you stand on, in the warm line every floor in the game has.
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top, box.width, 2),
      Paint()..color = SilhouettePalette.blockTop,
    );
    PairMark.draw(
      canvas,
      mark,
      Offset(box.center.dx, box.top + box.height * 0.55),
      lit: pulled,
      look: look,
      size: 8,
    );
  }

  /// Two ropes from the rim up out of the view, to the balcony.
  void _rope(Canvas canvas, Rect box, Color color) {
    final paint = Paint()..color = color;
    for (final x in [box.left + 10, box.right - 10]) {
      canvas.drawRect(
        Rect.fromLTRB(x - 1, box.top - 900, x + 1, box.top),
        paint,
      );
    }
  }
}
