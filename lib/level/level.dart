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
  Level({
    required this.id,
    required this.name,
    required this.teaches,
    double? delaySeconds,
    List<double>? delays,
    required this.spawnX,
    required this.goal,
    this.blocks = const [],
    this.plates = const [],
    this.toggles = const [],
    this.doors = const [],
    this.lights = const [],
    this.markers = const [],
    this.shadowIsSolid = true,
    this.shadowKills = false,
    this.floorTop = 620,
  }) : assert(
         (delaySeconds == null) != (delays == null),
         'a level sets either delaySeconds or delays, never both',
       ),
       assert(
         delays == null || delays.isNotEmpty,
         'a level with no delay has no shadow, which is not a level',
       ),
       delays = delays ?? [delaySeconds!];

  /// Stable key, used by save files later and by test names now.
  final String id;

  /// Shown in the corner while the level is on screen.
  final String name;

  /// One line, shown under the name. Not a tutorial — the plan's whole point
  /// is that the player works the mechanic out. This is the nudge that stops
  /// a first-time player thinking the game is broken.
  final String teaches;

  /// How far behind each shadow runs, nearest first. One entry is one shadow.
  ///
  /// Per level rather than global because the delay *is* a design parameter:
  /// the same layout at 2 seconds and at 5 seconds is two different puzzles,
  /// and the plan lists varying it as one of the mechanic's uses.
  ///
  /// Two entries is not a new rule, it is the rule twice — and what it buys is
  /// the one thing a single shadow cannot do at any delay: **be in two places
  /// at the same moment**. One shadow covers exactly one spot at a time, the
  /// spot you were standing in D ago. Two cover two, and the gap between them
  /// is the gap between the two things you did.
  final List<double> delays;

  /// The nearest shadow's delay, which is what everything that says "the
  /// delay" means — the readout, the bench's slider, and every level written
  /// before there could be more than one.
  double get delaySeconds => delays.first;

  final double spawnX;

  /// Touch this and the level is done.
  final Rect goal;

  /// Everything solid. The floor is one of these like anything else.
  final List<Rect> blocks;

  final List<PlateSpec> plates;
  final List<ToggleSpec> toggles;
  final List<DoorSpec> doors;

  /// Where the light falls, and where the shadow therefore is not.
  ///
  /// **Inside one of these the shadow is nothing.** It is drawn faint, it is
  /// not solid, it presses no plate and throws no key, and it cannot kill.
  /// The shadow needs dark to be a thing at all.
  ///
  /// That is the whole of it, and the restraint is the point. Light that
  /// erases the shadow, or drags it about, or switches on and off on a timer,
  /// was all considered and refused: the first two need a shader, the third is
  /// a stopwatch, and every one of them turns a mechanic the player holds in
  /// one sentence — *that is me, four seconds ago* — into two systems to model
  /// at once. A rectangle the shadow does not exist in keeps the sentence.
  ///
  /// The test is the centre of the shadow's body, not an overlap: a body half
  /// in the light is somewhere a player can see is half in the light, and
  /// deciding it by its middle is the version they can predict.
  final List<Rect> lights;

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

  /// The names of the mechanics **this build knows how to play**.
  ///
  /// Everything a level could hold when this set was written — blocks, plates,
  /// doors, markers, one delay — is the baseline and is not named here. The
  /// set is for what comes *after*: a mechanic gets its name added in the same
  /// commit that implements it, never before.
  ///
  /// It exists for one failure that has no other cure. A level served from
  /// somewhere else can reach a client older than the mechanic it uses, and
  /// the old parser does the worst possible thing with a field it has never
  /// heard of: it **ignores it in silence** and puts up a level that is either
  /// unsolvable or solvable without ever touching the thing the puzzle is
  /// about. Neither says anything is wrong. A level that names what it needs
  /// can be refused instead, which is the only honest answer.
  static const Set<String> knownMechanics = <String>{
    // Both landed in the commit that made them play, which is the only order
    // that is safe: a name in here before the code behind it means a level is
    // accepted and then played wrong, which is the exact failure this set
    // exists to prevent.
    'toggles',
    'inverted-plates',
    'lights',
    'delays',
  };

  /// What this level needs beyond the baseline, worked out from its contents.
  ///
  /// Derived rather than stored, so it cannot be forgotten: the level says
  /// what it needs because the code that can see what it holds says it, not
  /// because whoever wrote the file remembered to.
  ///
  /// A plate that inverts is named as well as a key, and for the more
  /// dangerous of the two reasons. An older build that drops `toggles` puts up
  /// a level with no way to open the door, which is at least obviously broken;
  /// one that drops `inverts` puts up a level whose door simply opens when it
  /// should have been held shut, and that plays like a level — a slightly easy
  /// one — with nothing anywhere saying it is the wrong puzzle.
  Set<String> get requires => {
    if (toggles.isNotEmpty) 'toggles',
    if (plates.any((plate) => plate.inverts)) 'inverted-plates',
    if (lights.isNotEmpty) 'lights',
    // One delay is the baseline and says nothing. More than one is the
    // dangerous kind of new field: an older build reading `delaySeconds`
    // alone puts up a level with one shadow, which is a level that looks
    // right, plays, and cannot be finished.
    if (delays.length > 1) 'delays',
  };
}

/// A pressure plate, and the door it holds open while something stands on it.
class PlateSpec {
  const PlateSpec({
    required this.area,
    required this.opens,
    this.inverts = false,
  });

  /// The slab itself, as drawn.
  final Rect area;

  /// Id of the [DoorSpec] this plate holds open — or, with [inverts], holds
  /// shut.
  final String opens;

  /// Holds the door **shut** while a body rests on it, instead of open.
  ///
  /// It beats everything else, which is what makes it worth having: a door
  /// with an inverted plate held down cannot be opened by any plate, any key
  /// or any linger. The point is not the extra rule, it is what it does to
  /// the shadow. Every mechanic up to here makes your past an *asset* —
  /// something that presses what you cannot reach. This one makes it a
  /// liability: a place you must not have been standing, D seconds ago.
  final bool inverts;

  /// Slightly taller than the slab, so a body resting on it counts as on it.
  Rect get trigger =>
      Rect.fromLTRB(area.left, area.top - 28, area.right, area.bottom + 2);
}

/// A key: step on it and the door it names flips, once, whoever stepped.
///
/// Not a plate. A plate is a question the door asks every frame — *is anyone
/// standing here?* — and a key is an event: the door changes state on the edge
/// and stays changed after you walk off. How long you stand on it makes no
/// difference at all.
///
/// The whole of its value is what that means for the shadow. Your past walks
/// the same path you did, so it steps on the same key D seconds later and
/// flips it **back**. A key opens a door for exactly D seconds, no matter what
/// you do, and the thing it teaches is the one sentence six levels of plates
/// cannot: what you open, you close.
class ToggleSpec {
  const ToggleSpec({required this.area, required this.flips});

  /// The slab itself, as drawn.
  final Rect area;

  /// Id of the [DoorSpec] this flips.
  final String flips;

  /// Slightly taller than the slab, so a body resting on it counts as on it.
  /// The same shape as a plate's, deliberately: these two are read at a glance
  /// by what they do, not by how closely you have to stand on them.
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

/// How solid each body in a line of pasts is drawn, **nearest first**: the
/// one you are now at 1, then each past further back.
///
/// One ladder in one place, because it gets drawn twice — the game fades its
/// shadows with it and the ending screen draws the game's own mark with it —
/// and two copies of a number like this drift the first time one of them is
/// nudged.
///
/// Stronger than the app icon's 0.30 and 0.55 on purpose. The shadow reads in
/// the game because it is *cold* against a warm sky, and thinning it down
/// towards the sky's own brightness is exactly what takes that away.
const List<double> pastFades = [1, 0.72, 0.45];

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
    'requires': requires.toList()..sort(),
    'teaches': teaches,
    // Both, always. `delaySeconds` is what a build older than two shadows
    // reads, and it gets the nearest one — which is the right answer for a
    // level with one and the wrong level entirely for a level with two, which
    // is why such a level also declares `delays` in `requires` and is refused
    // outright rather than quietly thinned.
    'delaySeconds': delaySeconds,
    'delays': delays,
    'spawnX': spawnX,
    'floorTop': floorTop,
    'shadowIsSolid': shadowIsSolid,
    'shadowKills': shadowKills,
    'goal': _rectToJson(goal),
    'blocks': blocks.map(_rectToJson).toList(),
    'lights': lights.map(_rectToJson).toList(),
    'markers': markers.map(_rectToJson).toList(),
    'plates': [
      for (final plate in plates)
        {
          'area': _rectToJson(plate.area),
          'opens': plate.opens,
          'inverts': plate.inverts,
        },
    ],
    'toggles': [
      for (final toggle in toggles)
        {'area': _rectToJson(toggle.area), 'flips': toggle.flips},
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

/// Thrown when a level is well-formed but asks for a mechanic this build does
/// not have.
///
/// Separate from [LevelFormatException] because it is not a mistake: the level
/// is fine, this copy of the game is simply older than it. The right response
/// is to leave that one level out, not to throw the batch away.
class LevelUnsupportedException implements Exception {
  LevelUnsupportedException(this.levelId, this.missing);

  final String levelId;

  /// The names this build does not know. See [Level.knownMechanics].
  final Set<String> missing;

  @override
  String toString() =>
      'LevelUnsupportedException: level "$levelId" needs '
      '${missing.join(', ')}, which this build does not have';
}

/// Builds a [Level] from decoded JSON.
///
/// Throws [LevelFormatException] if the data does not describe a level, and
/// [LevelUnsupportedException] if it describes one this build cannot play.
Level levelFromJson(Object? source) {
  final json = _asMap(source, 'level');
  final id = _asString(json['id'], 'id');

  // Before anything else is read. A level that needs a mechanic this build
  // has never heard of cannot be parsed into a *smaller* level and played
  // anyway — that is the whole failure this guards.
  final missing = _stringList(json['requires'], 'requires')
      .toSet()
      .difference(Level.knownMechanics);
  if (missing.isNotEmpty) throw LevelUnsupportedException(id, missing);

  try {
    return Level(
      id: id,
      name: _asString(json['name'], 'name'),
      teaches: _asString(json['teaches'], 'teaches'),
      delays: json['delays'] == null
          ? [_asDouble(json['delaySeconds'], 'delaySeconds')]
          : _doubleList(json['delays'], 'delays'),
      spawnX: _asDouble(json['spawnX'], 'spawnX'),
      floorTop: _asDouble(json['floorTop'] ?? 620, 'floorTop'),
      shadowIsSolid: _asBool(json['shadowIsSolid'] ?? true, 'shadowIsSolid'),
      shadowKills: _asBool(json['shadowKills'] ?? false, 'shadowKills'),
      goal: _rectFromJson(json['goal'], 'goal'),
      blocks: _rectList(json['blocks'], 'blocks'),
      lights: _rectList(json['lights'], 'lights'),
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
            // Absent means a plate that opens, which is every plate written
            // before this field existed.
            inverts: _asBool(
              _asMap(entry, 'plates[$i]')['inverts'] ?? false,
              'plates[$i].inverts',
            ),
          ),
      ],
      toggles: [
        for (final (i, entry) in _asList(json['toggles'], 'toggles').indexed)
          ToggleSpec(
            area: _rectFromJson(
              _asMap(entry, 'toggles[$i]')['area'],
              'toggles[$i].area',
            ),
            flips: _asString(
              _asMap(entry, 'toggles[$i]')['flips'],
              'toggles[$i].flips',
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

/// Builds a whole campaign from decoded JSON — a list of levels, or one on
/// its own, which is what a file somebody is authoring usually holds.
///
/// A level this build cannot play is **left out**, and [onSkipped] is told.
/// Dropping one level is safe; dropping the batch it arrived in would lose
/// nineteen good levels because the twentieth was ahead of this build, and
/// silently dropping a *field* — the thing [Level.knownMechanics] exists to
/// prevent — is the only version of this that is actually dangerous.
List<Level> levelsFromJson(
  Object? source, {
  void Function(LevelUnsupportedException skipped)? onSkipped,
}) {
  final entries = source is Map ? [source] : _asList(source, 'levels');
  final levels = <Level>[];
  for (final entry in entries) {
    try {
      levels.add(levelFromJson(entry));
    } on LevelUnsupportedException catch (error) {
      onSkipped?.call(error);
    }
  }
  return levels;
}

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

List<double> _doubleList(Object? value, String field) {
  final list = [
    for (final (i, entry) in _asList(value, field).indexed)
      _asDouble(entry, '$field[$i]'),
  ];
  if (list.isEmpty) throw LevelFormatException('$field is empty');
  return list;
}

List<String> _stringList(Object? value, String field) => [
  for (final (i, entry) in _asList(value, field).indexed)
    _asString(entry, '$field[$i]'),
];

List<Rect> _rectList(Object? value, String field) => [
  for (final (i, entry) in _asList(value, field).indexed)
    _rectFromJson(entry, '$field[$i]'),
];
