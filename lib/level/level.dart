import 'dart:ui';

/// A puzzle, as data.
///
/// Phase 4 is about designing puzzles, and a puzzle you can only read by
/// reading the code that draws it is a puzzle nobody will tune. So a level is
/// a value: rectangles, a spawn, a goal, and the three numbers that change how
/// the shadow behaves. It can be diffed, printed, and — the part that matters
/// — replayed in a test to prove it is still solvable.
///
/// Everything is in world units, y down, with 0 at the top of the screen and
/// [Level.floorTop] wherever the level puts its ground.
class Level {
  const Level({
    required this.id,
    required this.name,
    required this.teaches,
    required this.delaySeconds,
    required this.spawnX,
    required this.goal,
    this.blocks = const [],
    this.plates = const [],
    this.doors = const [],
    this.markers = const [],
    this.shadowIsSolid = true,
    this.shadowKills = false,
    this.floorTop = 620,
  });

  /// Stable key, used by save files later and by test names now.
  final String id;

  /// Shown in the corner while the level is on screen.
  final String name;

  /// One line, shown under the name. Not a tutorial — the plan's whole point
  /// is that the player works the mechanic out. This is the nudge that stops
  /// a first-time player thinking the game is broken.
  final String teaches;

  /// How far behind the shadow runs, for this level only.
  ///
  /// Per level rather than global because the delay *is* a design parameter:
  /// the same layout at 2 seconds and at 5 seconds is two different puzzles,
  /// and the plan lists varying it as one of the mechanic's uses.
  final double delaySeconds;

  final double spawnX;

  /// Touch this and the level is done.
  final Rect goal;

  /// Everything solid. The floor is one of these like anything else.
  final List<Rect> blocks;

  final List<PlateSpec> plates;
  final List<DoorSpec> doors;

  /// Squares that fill in when touched but end nothing. Scenery with feedback:
  /// the lab uses them to mark the two things worth reaching without turning
  /// itself into a level to be won.
  final List<Rect> markers;

  /// Can the player stand on the shadow in this level?
  final bool shadowIsSolid;

  /// Does touching the shadow restart the level?
  final bool shadowKills;

  /// Where the ground is, for spawning and for falling out of the world.
  final double floorTop;
}

/// A pressure plate, and the door it holds open while something stands on it.
class PlateSpec {
  const PlateSpec({required this.area, required this.opens});

  /// The slab itself, as drawn.
  final Rect area;

  /// Id of the [DoorSpec] this plate holds open.
  final String opens;

  /// Slightly taller than the slab, so a body resting on it counts as on it.
  Rect get trigger =>
      Rect.fromLTRB(area.left, area.top - 28, area.right, area.bottom + 2);
}

/// A door. Solid while shut, slides up out of the way while a plate is held.
class DoorSpec {
  const DoorSpec({required this.id, required this.closed});

  final String id;

  /// Where it sits when shut.
  final Rect closed;
}

/// The grey-box palette. Light ground, dark bodies: this is a silhouette game,
/// and a black character on a dark test scene would tell us nothing about the
/// shadow's opacity.
abstract final class Palette {
  static const Color background = Color(0xFFB4B4B4);
  static const Color blockFill = Color(0xFF6E6E6E);
  static const Color blockTop = Color(0xFF8C8C8C);
  static const Color blockEdge = Color(0xFF4A4A4A);
  static const Color plateUp = Color(0xFF8C8C8C);
  static const Color plateDown = Color(0xFF3A3A3A);
  static const Color doorColor = Color(0xFF5A5A5A);
  static const Color goalIdle = Color(0xFF9A9A9A);
  static const Color goalReached = Color(0xFF2B2B2B);
  static const Color bodyColor = Color(0xFF141414);
  static const Color trailColor = Color(0xFF3C3C3C);
}
