import 'dart:math';
import 'dart:ui';

import '../level/level.dart';
import '../level/level_check.dart';
import '../level/levels.dart';

/// A stretch of a surface's top that a body can stand on.
class Ledge {
  const Ledge(this.left, this.right, this.y);

  final double left;
  final double right;
  final double y;

  double get width => right - left;

  @override
  String toString() => 'Ledge(${left.round()}–${right.round()} @ ${y.round()})';
}

/// The rules the gate holds a level to, worked out as things to **draw**.
///
/// Every bug this project has fixed in a level was a geometric rule nobody
/// could see — a door one body too short, a ledge a crouch too low, a patch of
/// floor within a jump of a shelf nobody meant to be reachable. The gate says
/// so after the fact; the editor draws it while you are moving the thing
/// (`docs/phase-9-editor.md` §٤).
///
/// Nothing here has a number of its own. The reach is [ladderReachFor], the
/// door floor is [minDoorHeightFor], the spawn box is [spawnBoxOf] — the
/// gate's own functions — so what the editor draws red is exactly what the
/// gate would refuse, and a rule changed in one place changes in both.
class DrawnRules {
  DrawnRules.of(Level level)
    : reach = ladderReachFor(level),
      doorFloor = minDoorHeightFor(level),
      spawnInside = spawnsInside(level),
      ledges = openLedges(level.blocks),
      shortDoors = {
        for (final door in level.doors)
          if (door.closed.height < minDoorHeightFor(level)) door.id,
      },
      danglingLinks = {
        for (final plate in level.plates)
          if (!level.doors.any((d) => d.id == plate.opens)) plate.area,
        for (final toggle in level.toggles)
          if (!level.doors.any((d) => d.id == toggle.flips)) toggle.area,
      } {
    climbable = _climbable(ledges, reach);
  }

  /// How high a body standing on its own past can get its feet.
  final double reach;

  /// The shortest a door may be.
  final double doorFloor;

  final bool spawnInside;

  /// Every open stretch of every surface's top.
  final List<Ledge> ledges;

  /// The ones a body can get onto from some *lower* open ledge within
  /// [Levels.ladderCarry] of it, by standing on its own past — question 2b,
  /// drawn. Some of these are the level's intended route; any that are not
  /// are a second way in.
  late final List<Ledge> climbable;

  /// Names of doors shorter than [doorFloor].
  final Set<String> shortDoors;

  /// Plates and keys pointing at no door.
  final Set<Rect> danglingLinks;

  static List<Ledge> _climbable(List<Ledge> ledges, double reach) => [
    for (final high in ledges)
      if (ledges.any(
        (low) =>
            low.y > high.y &&
            low.y - high.y <= reach &&
            _gap(low, high) <= Levels.ladderCarry,
      ))
        high,
  ];

  static double _gap(Ledge a, Ledge b) =>
      max(0, max(a.left, b.left) - min(a.right, b.right));

  /// The parts of each block's top that nothing is sitting on and a body is
  /// wide enough to stand on.
  static List<Ledge> openLedges(List<Rect> blocks) {
    final ledges = <Ledge>[];
    for (final block in blocks) {
      var spans = [(block.left, block.right)];
      for (final other in blocks) {
        if (identical(other, block)) continue;
        // Covers the top if it reaches down to it and starts above it.
        if (!(other.top < block.top && other.bottom >= block.top)) continue;
        spans = [
          for (final (l, r) in spans) ...[
            if (other.left > l) (l, min(r, other.left)),
            if (other.right < r) (max(l, other.right), r),
          ],
        ].where((s) => s.$2 > s.$1).toList();
      }
      for (final (l, r) in spans) {
        if (r - l >= _body) ledges.add(Ledge(l, r, block.top));
      }
    }
    return ledges;
  }

  static const double _body = 44;
}
