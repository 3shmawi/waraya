import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'player.dart';

/// The leash, drawn (`Level.leash`): a thin line from you to each past that
/// is holding you.
///
/// Paint only. It reads the same list the player's step is checked against,
/// so it can never show a past holding you that does not, and it says how
/// close to the end of it you are before you get there — faint and loose,
/// then brighter and straight as the distance comes up to the length. A
/// leash has to be seen before it stops you, not after
/// (`phase-7-hard-levels.md` §14).
class LeashLine extends Component {
  LeashLine({
    required this.length,
    required this.player,
    required this.ends,
    required this.color,
  }) : super(priority: 95);

  final double length;
  final Player Function() player;

  /// Where the pasts holding the player are drawn this frame.
  final Iterable<Offset> Function() ends;

  final Color color;

  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// How thick the line is drawn at [reach] — the distance over the
  /// leash's length.
  ///
  /// Thicker as it tightens, up to the end. Past the end, which only a past
  /// walking away on its own can do, it thins the way a stretched band does,
  /// until your past comes back. It does not drag you after it: you would be
  /// recorded being dragged, and your past would replay the dragging, and
  /// drag you again — turn round at the end of the leash and you could never
  /// walk back (`docs/phase-12-more.md` §3.1).
  static double widthAt(double reach) {
    final taut = reach.clamp(0.0, 1.0);
    final stretched = max(0.0, reach - 1);
    return (1.2 + 1.3 * taut) / (1 + 2.5 * stretched);
  }

  @override
  void render(Canvas canvas) {
    final from = player().bounds.center;
    for (final to in ends()) {
      final reach = (to - from).distance / length;
      final taut = reach.clamp(0.0, 1.0);
      _paint
        ..color = color.withValues(alpha: 0.12 + 0.6 * taut * taut)
        ..strokeWidth = widthAt(reach);
      // Slack sags: a leash that is not yet holding hangs below the line
      // between you, by less the tighter it gets.
      final sag = (1 - taut) * 40;
      final middle = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 + sag);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(middle.dx, middle.dy, to.dx, to.dy);
      canvas.drawPath(path, _paint);
    }
  }
}
