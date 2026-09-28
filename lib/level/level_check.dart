import 'dart:ui';

import 'package:flame/components.dart';

import '../game/config.dart';
import 'level.dart';
import 'level_game.dart';
import 'levels.dart';
import 'playthrough.dart';

/// Why a level was turned away. One per rule, so a test — or an author
/// reading the gate's answer — can tell *which* rule, not only that one broke.
enum Refusal {
  /// The data does not describe a level at all.
  malformed,

  /// It needs a mechanic this build does not have. Not the level's fault, but
  /// a build that cannot play it cannot vouch for it either.
  unsupported,

  /// It uses a mechanic its own `requires` does not name.
  ///
  /// This build would play it correctly, which is exactly why it has to be
  /// refused here: the build that would **not** is an older one, and that
  /// build only ever learns what a level needs from what the level says.
  understatesRequires,

  /// No recorded solution, or no recorded wrong idea. See [Level.canBeChecked].
  cannotBeChecked,

  /// A number outside what the game is built for — a door low enough to
  /// climb, a delay the slider cannot make, a spawn inside a wall, a run long
  /// enough to hang whatever is replaying it.
  outOfBounds,

  /// The recorded solution does not finish the level.
  solutionFails,

  /// A recorded wrong idea finishes the level.
  wrongIdeaFinishes,

  /// One of [cheapRuns] finishes the level.
  cheapRunFinishes,
}

/// One broken rule, with enough said to fix it.
class Finding {
  const Finding(this.refusal, this.detail);

  final Refusal refusal;
  final String detail;

  @override
  String toString() => '${refusal.name}: $detail';
}

/// Whether a level may be played by someone who did not write it, and if not,
/// every reason why.
class Verdict {
  const Verdict(this.levelId, this.findings);

  /// Null when the data was too broken to have one.
  final String? levelId;

  final List<Finding> findings;

  bool get accepted => findings.isEmpty;

  Set<Refusal> get refusals => {for (final f in findings) f.refusal};

  @override
  String toString() => accepted
      ? '${levelId ?? '?'}: accepted'
      : '${levelId ?? '?'}: refused — ${findings.join(' | ')}';
}

/// Runs that try to take a level with the least possible thought.
///
/// Every recorded wrong idea is somebody trying to solve the level *wrongly*.
/// These are somebody trying not to solve it at all — and they are the runs
/// that found every level in this project whose tests were green and whose
/// puzzle was broken. Level eleven fell to "touch the plate and run" with
/// three wrong ideas recorded, every one of which pressed the plate properly
/// and waited for its past.
///
/// Here rather than in a test because the campaign's sweep
/// (`test/level/miserly_test.dart`) and the gate in front of a level from
/// outside have to throw the **same** list at it. A gate with its own shorter
/// list would publish what the campaign would refuse.
Map<String, List<Move>> cheapRuns(Level level) {
  final toward = level.goal.center.dx > level.spawnX ? 1.0 : -1.0;
  final away = -toward;
  Move go(double s, {bool jump = false, bool crouch = false}) =>
      Move(s, axis: toward, jump: jump, crouch: crouch);
  Move back(double s, {bool crouch = false}) =>
      Move(s, axis: away, crouch: crouch);
  return {
    'hold toward the goal': [go(14)],
    'hold, crouching': [go(14, crouch: true)],
    'hold and jump': [
      for (var i = 0; i < 12; i++) ...[go(0.5, jump: true), go(0.5)],
    ],
    'touch what is behind you, then run': [back(2.2), const Move(0.1), go(12)],
    'touch what is behind you further back, then run': [
      back(3.6),
      const Move(0.1),
      go(12),
    ],
    'duck on the way past, then run': [back(2.2, crouch: true), go(12)],
    'wait for the shadow, then hold': [const Move(5), go(12)],
  };
}

/// The limits a level from outside is held to. The campaign sits well inside
/// every one of them; they exist to catch a mistake, or a file written to
/// make whatever replays it fall over.
abstract final class CheckLimits {
  /// Longest any one recorded run may be, in seconds. The campaign's longest
  /// is under 25. A gate that replays a run of an hour is a gate that stops.
  static const double longestRun = 90;

  /// Most wrong ideas one level may carry. Each is a full replay.
  static const int mostWrongIdeas = 8;

  /// Most of any one kind of thing — blocks, plates, doors, lights.
  static const int mostPieces = 64;

  /// How wide and how deep a level may be, in world units. The widest in the
  /// campaign is about 5000 including its offstage ground.
  static const double widest = 12000;
  static const double deepest = 4000;

  /// The range the bench's slider covers, for the nearest shadow; and the
  /// range any shadow may use. Same numbers `levels_test.dart` holds the
  /// campaign to.
  static const double nearestDelayMin = 0.5;
  static const double nearestDelayMax = 6;
  static const double anyDelayMax = 12;

  /// Two. Every height rule in the game is measured for at most two stacked
  /// shadows ([Levels.minDoorHeightTwoShadows]); a third is one more step on
  /// a staircase nothing has measured.
  static const int mostShadows = 2;

  /// A door that lingers longer than this is a door nobody is holding.
  static const double longestLinger = 10;
}

/// The whole check, starting from decoded JSON — what a gate or a client
/// actually has in hand.
///
/// A level that does not parse, or that this build cannot play, is refused
/// here rather than thrown: a gate going through a queue of submissions wants
/// an answer for every one of them.
Future<Verdict> checkLevelJson(Object? json) async {
  final Level level;
  try {
    level = levelFromJson(json);
  } on LevelUnsupportedException catch (error) {
    return Verdict(error.levelId, [
      Finding(
        Refusal.unsupported,
        'needs ${error.missing.join(', ')}, which this build does not have',
      ),
    ]);
  } on LevelFormatException catch (error) {
    return Verdict(_idOf(json), [Finding(Refusal.malformed, error.message)]);
  }

  // Parsed fine — and parsing trusts `requires` to be *at least* complete.
  // Check it is: what the level says it needs has to cover what it holds.
  final declared = <Object?>{
    if (json is Map && json['requires'] is List) ...json['requires'] as List,
  };
  final unnamed = level.requires.where((name) => !declared.contains(name));
  final understated = [
    if (unnamed.isNotEmpty)
      Finding(
        Refusal.understatesRequires,
        'uses ${unnamed.join(', ')} without naming it in "requires" — '
        'an older build would play it without',
      ),
  ];

  final verdict = await checkLevel(level);
  return Verdict(level.id, [...understated, ...verdict.findings]);
}

/// Decides whether [level] may be published.
///
/// Every rule a level in this project is held to, in one place, in the order
/// cheapest first: the shape of the data, then the numbers, then the replays.
/// The replays only run once the numbers are sane, so a level built to hang
/// the gate is refused before it gets the chance.
///
/// [cheapIsTheLesson] is for the campaign and nothing else: three built-in
/// levels are *meant* to fall to a terse run (`miserly_test.dart` lists them
/// and holds them to it). Nothing from outside sets it — a cheap run that
/// finishes a submitted level is a refusal.
Future<Verdict> checkLevel(Level level, {bool cheapIsTheLesson = false}) async {
  final findings = <Finding>[
    ..._requires(level),
    ..._recordings(level),
    ..._bounds(level),
  ];
  // Nothing to replay, or numbers nobody should replay.
  if (findings.isNotEmpty) return Verdict(level.id, findings);

  final game = LevelGame(levels: [level], inputs: [ScriptedInput()]);
  await _boot(game);
  try {
    findings.addAll(_replays(game, level, cheapIsTheLesson));
  } finally {
    game.onRemove();
  }
  return Verdict(level.id, findings);
}

Iterable<Finding> _requires(Level level) sync* {
  final missing = level.requires.difference(Level.knownMechanics);
  if (missing.isNotEmpty) {
    yield Finding(
      Refusal.unsupported,
      'needs ${missing.join(', ')}, which this build does not have',
    );
  }
}

Iterable<Finding> _recordings(Level level) sync* {
  if (level.solution.isEmpty) {
    yield const Finding(Refusal.cannotBeChecked, 'no recorded solution');
  }
  if (level.wrongIdeas.isEmpty) {
    yield const Finding(Refusal.cannotBeChecked, 'no recorded wrong idea');
  }
}

Iterable<Finding> _bounds(Level level) sync* {
  Finding out(String detail) => Finding(Refusal.outOfBounds, detail);

  // The shadows.
  final delays = level.delays;
  if (delays.length > CheckLimits.mostShadows) {
    yield out('${delays.length} shadows; at most ${CheckLimits.mostShadows}');
  }
  if (level.delaySeconds < CheckLimits.nearestDelayMin ||
      level.delaySeconds > CheckLimits.nearestDelayMax) {
    yield out(
      'nearest delay ${level.delaySeconds}s is outside '
      '${CheckLimits.nearestDelayMin}–${CheckLimits.nearestDelayMax}s',
    );
  }
  if (delays.any((d) => d < CheckLimits.nearestDelayMin) ||
      delays.any((d) => d > CheckLimits.anyDelayMax)) {
    yield out(
      'a delay is outside ${CheckLimits.nearestDelayMin}–'
      '${CheckLimits.anyDelayMax}s: $delays',
    );
  }
  for (var i = 1; i < delays.length; i++) {
    if (delays[i] < delays[i - 1]) {
      yield out('delays are not nearest first: $delays');
      break;
    }
  }

  // How much of it there is.
  for (final (name, count) in [
    ('blocks', level.blocks.length),
    ('plates', level.plates.length),
    ('toggles', level.toggles.length),
    ('doors', level.doors.length),
    ('lights', level.lights.length),
    ('markers', level.markers.length),
  ]) {
    if (count > CheckLimits.mostPieces) {
      yield out('$count $name; at most ${CheckLimits.mostPieces}');
    }
  }
  var extent = Rect.fromLTRB(
    level.spawnX,
    level.floorTop,
    level.spawnX,
    level.floorTop,
  ).expandToInclude(level.goal);
  for (final rect in [
    ...level.blocks,
    ...level.lights,
    ...level.markers,
    for (final plate in level.plates) plate.area,
    for (final toggle in level.toggles) toggle.area,
    for (final door in level.doors) door.closed,
  ]) {
    extent = extent.expandToInclude(rect);
  }
  if (extent.width > CheckLimits.widest ||
      extent.height > CheckLimits.deepest) {
    yield out(
      '${extent.width.round()} × ${extent.height.round()} is bigger than '
      '${CheckLimits.widest.round()} × ${CheckLimits.deepest.round()}',
    );
  }
  if (!_finite(extent)) yield out('a coordinate is not a number');

  // The runs, before anything replays them.
  final runs = [level.solution, ...level.wrongIdeas];
  if (level.wrongIdeas.length > CheckLimits.mostWrongIdeas) {
    yield out(
      '${level.wrongIdeas.length} wrong ideas; '
      'at most ${CheckLimits.mostWrongIdeas}',
    );
  }
  for (final run in runs) {
    final seconds = run.fold<double>(0, (sum, move) => sum + move.seconds);
    if (!(seconds <= CheckLimits.longestRun)) {
      yield out(
        'a recorded run lasts ${seconds.toStringAsFixed(1)}s; '
        'at most ${CheckLimits.longestRun.round()}s',
      );
    }
    if (run.any((m) => !(m.seconds > 0) || !(m.axis.abs() <= 1))) {
      yield out('a recorded move has no length, or an axis outside -1…1');
    }
  }

  // The doors: named once, pointed at, and too tall to climb.
  final doorIds = <String>{};
  for (final door in level.doors) {
    if (!doorIds.add(door.id)) yield out('two doors are called "${door.id}"');
    if (!(door.lingerSeconds >= 0 &&
        door.lingerSeconds <= CheckLimits.longestLinger)) {
      yield out(
        'door "${door.id}" lingers ${door.lingerSeconds}s; '
        '0–${CheckLimits.longestLinger.round()}s',
      );
    }
    // Two shadows stack, so a level with two has one more step under every
    // door. Same floor `levels_test.dart` holds the campaign to.
    final floor = delays.length > 1
        ? Levels.minDoorHeightTwoShadows
        : Levels.minDoorHeight;
    if (door.closed.height < floor) {
      yield out(
        'door "${door.id}" is ${door.closed.height.round()} tall; a body on '
        'a shadow at its foot clears anything under ${floor.round()}',
      );
    }
  }
  for (final plate in level.plates) {
    if (!doorIds.contains(plate.opens)) {
      yield out('a plate opens "${plate.opens}", which is not a door');
    }
  }
  for (final toggle in level.toggles) {
    if (!doorIds.contains(toggle.flips)) {
      yield out('a key flips "${toggle.flips}", which is not a door');
    }
  }

  // Where you start, and where you are going.
  final spawn = Rect.fromLTWH(
    level.spawnX - 22,
    level.floorTop - _bodyHeight,
    44,
    _bodyHeight,
  );
  if (level.blocks.any(spawn.overlaps) ||
      level.doors.any((door) => spawn.overlaps(door.closed))) {
    yield out('the player spawns inside the scenery');
  }
  // Not a proof it can be reached — the solution is that. This catches a goal
  // left floating where no surface is within a jump of it.
  const jump =
      WarayaConfig.jumpSpeed *
      WarayaConfig.jumpSpeed /
      (2 * WarayaConfig.gravity);
  if (!level.blocks.any(
    (block) => (block.top - level.goal.bottom).abs() < jump + _bodyHeight,
  )) {
    yield out('the goal is nowhere a jump could land');
  }
}

Iterable<Finding> _replays(
  LevelGame game,
  Level level,
  bool cheapIsTheLesson,
) sync* {
  final source = game.input.sources.first as ScriptedInput;
  double? play(List<Move> moves) {
    // The game's own retry puts everything back, buffer included, which is
    // exactly a fresh attempt.
    game.reload();
    return (Playthrough(
      game,
      source,
    )..play(moves, stopWhenComplete: true)).finishedAt;
  }

  if (play(level.solution) == null) {
    yield const Finding(
      Refusal.solutionFails,
      'the recorded solution does not finish the level',
    );
  }
  for (final (i, idea) in level.wrongIdeas.indexed) {
    final at = play(idea);
    if (at != null) {
      yield Finding(
        Refusal.wrongIdeaFinishes,
        'wrong idea ${i + 1} finishes it in ${at.toStringAsFixed(1)}s',
      );
    }
  }
  // A level whose lesson *is* the terse run is not swept: the campaign's own
  // sweep holds those three to still falling to it, by name.
  if (cheapIsTheLesson) return;
  final cheap = <String>[
    for (final MapEntry(key: name, value: run) in cheapRuns(level).entries)
      if (play(run) case final at?) '$name (${at.toStringAsFixed(1)}s)',
  ];
  if (cheap.isNotEmpty) {
    yield Finding(
      Refusal.cheapRunFinishes,
      'finished without being played: ${cheap.join(' | ')}',
    );
  }
}

/// What `flame_test` does before handing a test its game, done here so the
/// gate and the client can check a level without a test framework.
Future<void> _boot(LevelGame game) async {
  game.onGameResize(Vector2(800, 600));
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  game.update(0);
  await game.ready();
}

const double _bodyHeight = 96;

bool _finite(Rect r) =>
    r.left.isFinite && r.top.isFinite && r.right.isFinite && r.bottom.isFinite;

String? _idOf(Object? json) =>
    json is Map && json['id'] is String ? json['id'] as String : null;
