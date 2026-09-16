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
  const DoorSpec({
    required this.id,
    required this.closed,
    this.lingerSeconds = 0,
  });

  final String id;

  /// Where it sits when shut.
  final Rect closed;

  /// How long it stays open after the plate is let go, in seconds.
  ///
  /// Zero by default: a door that shuts the moment you step off is the first
  /// level's entire lesson, and your own past holding something open for you
  /// is the image the whole game is built on.
  ///
  /// It exists because a door with no linger makes a level a stopwatch. The
  /// window a plate holds a door open for is exactly as long as you happened
  /// to stand on it — which can be under a second — and it arrives one whole
  /// delay later, so a beat of hesitation puts you at a shut door that is
  /// never opening again. A door that drifts shut a few seconds after your
  /// past steps off the plate is forgiving in the way a person needs and is
  /// still visibly a door your past opened. The first attempt at this fix
  /// latched the door open forever, and that came straight back as a bug
  /// report: a door that never shuts is not a door anyone is holding.
  final double lingerSeconds;
}

/// How the level is drawn.
///
/// The bench and the game want opposite things from the same rectangles. On
/// the bench they should be legible slabs you can measure; in the game they
/// should be silhouettes against a bright sky, because that is the game.
enum LevelLook {
  /// Grey boxes on a light ground. Deliberately ugly: nice art flatters a
  /// mechanic, and the bench exists to find out whether one stands up without
  /// help.
  greyBox,

  /// Near-black shapes with a warm rim on every standable face, against the
  /// photographed environment. The rim is doing real work — it is the only
  /// thing separating one black shape from another, and it reads as the
  /// backlight the art direction is built on.
  silhouette,
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
  static const Color shadowColor = bodyColor;
  static const Color trailColor = Color(0xFF3C3C3C);
}

/// The same scene, lit from behind.
abstract final class SilhouettePalette {
  static const Color blockFill = Color(0xFF0E0A10);
  static const Color blockTop = Color(0xFFD9A25C);
  static const Color blockEdge = Color(0x00000000);
  static const Color plateUp = Color(0xFF241A16);
  static const Color plateDown = Color(0xFFD9A25C);
  static const Color doorColor = Color(0xFF0E0A10);
  static const Color goalIdle = Color(0xFF140E12);
  static const Color goalReached = Color(0xFFFFE7B0);

  /// The player is as black as the scene gets — the cut-out the backlight
  /// leaves.
  static const Color bodyColor = Color(0xFF07050A);

  /// The shadow is **not** a darker black, and not a warm one either.
  ///
  /// Black at half opacity over a near-black block is invisible, and that is
  /// fatal here — the thing you have to read at a glance is where your old
  /// body is, because you are about to stand on it. The first warm version was
  /// invisible too, just somewhere else: it matched the brown of the mid
  /// treeline exactly and vanished the moment it walked in front of it.
  ///
  /// Paler and slightly cold is the one colour nothing else in this scene has.
  /// It lightens against the blocks, and against the sunset it reads as the
  /// one thing in frame that is not warm.
  static const Color shadowColor = Color(0xFFDCE4EE);

  static const Color trailColor = Color(0x99FFE7B0);
}

/// Reading and writing a level as JSON.
///
/// This is the whole of what a backend needs. A level is already a value; this
/// makes it a value that survives a network hop, so a level served from
/// somewhere else runs through exactly the same code as a built-in one.
///
/// Rectangles are `[left, top, right, bottom]` rather than objects: a level is
/// mostly rectangles, and four numbers read better than four keys repeated
/// thirty times.
extension LevelJson on Level {
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'teaches': teaches,
    'delaySeconds': delaySeconds,
    'spawnX': spawnX,
    'floorTop': floorTop,
    'shadowIsSolid': shadowIsSolid,
    'shadowKills': shadowKills,
    'goal': _rectToJson(goal),
    'blocks': blocks.map(_rectToJson).toList(),
    'markers': markers.map(_rectToJson).toList(),
    'plates': [
      for (final plate in plates)
        {'area': _rectToJson(plate.area), 'opens': plate.opens},
    ],
    'doors': [
      for (final door in doors)
        {
          'id': door.id,
          'closed': _rectToJson(door.closed),
          'lingerSeconds': door.lingerSeconds,
        },
    ],
  };
}

List<double> _rectToJson(Rect r) => [r.left, r.top, r.right, r.bottom];

/// Thrown when level data does not describe a level.
///
/// Anything coming from outside the app — a file, a server, a level somebody
/// else authored — is malformed until proven otherwise, and the useful failure
/// is one that names the field.
class LevelFormatException implements Exception {
  LevelFormatException(this.message);

  final String message;

  @override
  String toString() => 'LevelFormatException: $message';
}

/// Builds a [Level] from decoded JSON, or throws [LevelFormatException].
Level levelFromJson(Object? source) {
  final json = _asMap(source, 'level');
  final id = _asString(json['id'], 'id');
  try {
    return Level(
      id: id,
      name: _asString(json['name'], 'name'),
      teaches: _asString(json['teaches'], 'teaches'),
      delaySeconds: _asDouble(json['delaySeconds'], 'delaySeconds'),
      spawnX: _asDouble(json['spawnX'], 'spawnX'),
      floorTop: _asDouble(json['floorTop'] ?? 620, 'floorTop'),
      shadowIsSolid: _asBool(json['shadowIsSolid'] ?? true, 'shadowIsSolid'),
      shadowKills: _asBool(json['shadowKills'] ?? false, 'shadowKills'),
      goal: _rectFromJson(json['goal'], 'goal'),
      blocks: _rectList(json['blocks'], 'blocks'),
      markers: _rectList(json['markers'], 'markers'),
      plates: [
        for (final (i, entry) in _asList(json['plates'], 'plates').indexed)
          PlateSpec(
            area: _rectFromJson(
              _asMap(entry, 'plates[$i]')['area'],
              'plates[$i].area',
            ),
            opens: _asString(
              _asMap(entry, 'plates[$i]')['opens'],
              'plates[$i].opens',
            ),
          ),
      ],
      doors: [
        for (final (i, entry) in _asList(json['doors'], 'doors').indexed)
          DoorSpec(
            id: _asString(_asMap(entry, 'doors[$i]')['id'], 'doors[$i].id'),
            closed: _rectFromJson(
              _asMap(entry, 'doors[$i]')['closed'],
              'doors[$i].closed',
            ),
            lingerSeconds: _asDouble(
              _asMap(entry, 'doors[$i]')['lingerSeconds'] ?? 0,
              'doors[$i].lingerSeconds',
            ),
          ),
      ],
    );
  } on LevelFormatException catch (error) {
    // Say which level, not just which field: a campaign is a list, and "goal
    // is not a rectangle" is no use without knowing whose goal.
    throw LevelFormatException('level "$id": ${error.message}');
  }
}

/// Builds a whole campaign from decoded JSON.
List<Level> levelsFromJson(Object? source) => [
  for (final entry in _asList(source, 'levels')) levelFromJson(entry),
];

Map<String, Object?> _asMap(Object? value, String field) => value is Map
    ? value.cast<String, Object?>()
    : throw LevelFormatException('$field is not an object');

List<Object?> _asList(Object? value, String field) => switch (value) {
  null => const [],
  final List<Object?> list => list,
  _ => throw LevelFormatException('$field is not a list'),
};

String _asString(Object? value, String field) =>
    value is String && value.isNotEmpty
    ? value
    : throw LevelFormatException('$field is missing or not text');

double _asDouble(Object? value, String field) => value is num
    ? value.toDouble()
    : throw LevelFormatException('$field is not a number');

bool _asBool(Object? value, String field) => value is bool
    ? value
    : throw LevelFormatException('$field is not true or false');

Rect _rectFromJson(Object? value, String field) {
  final list = _asList(value, field);
  if (list.length != 4) {
    throw LevelFormatException('$field needs four numbers [l, t, r, b]');
  }
  final n = [for (final v in list) _asDouble(v, field)];
  if (n[2] <= n[0] || n[3] <= n[1]) {
    throw LevelFormatException('$field is inside out or empty');
  }
  return Rect.fromLTRB(n[0], n[1], n[2], n[3]);
}

List<Rect> _rectList(Object? value, String field) => [
  for (final (i, entry) in _asList(value, field).indexed)
    _rectFromJson(entry, '$field[$i]'),
];
