// A small controller for the level tests that are easier to say as places
// than as times: walk to here, duck there, climb what is in front of you.
import 'package:waraya/input/input.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/playthrough.dart';

/// A small controller for runs that are easier to say as places than as
/// times: walk to here, duck there, climb what is in front of you.
class Run {
  Run(this.game) : _source = game.input.sources.first as ScriptedInput;

  final LevelGame game;
  final ScriptedInput _source;

  double t = 0;
  double? finishedAt;

  /// The highest the feet have been while standing on something.
  double highest = double.infinity;

  void _frame(InputIntent intent) {
    _source.next = intent;
    game.update(Playthrough.dt);
    t += Playthrough.dt;
    if (game.completed) finishedAt ??= t;
    if (game.player.isGrounded && game.player.y < highest) {
      highest = game.player.y;
    }
  }

  void hold(
    double seconds, {
    double axis = 0,
    bool jump = false,
    bool crouch = false,
    void Function()? each,
  }) {
    final frames = (seconds / Playthrough.dt).round();
    for (var i = 0; i < frames; i++) {
      _frame(
        InputIntent(
          moveAxis: axis,
          jump: jump && i == 0,
          jumpHeld: jump,
          crouch: crouch,
        ),
      );
      each?.call();
    }
  }

  void play(Iterable<Move> moves) {
    for (final move in moves) {
      hold(move.seconds, axis: move.axis, jump: move.jump, crouch: move.crouch);
    }
  }

  /// Walks to [x] and stops there, braking in time not to overshoot.
  void walkTo(double x, {bool crouch = false}) {
    var last = game.player.x;
    for (var guard = 0; guard < 1200; guard++) {
      final gap = x - game.player.x;
      if (gap.abs() <= 4) break;
      final speed = (game.player.x - last).abs() / Playthrough.dt;
      last = game.player.x;
      // Stopping distance under the game's ground friction.
      final brake = speed * speed / 6000 >= gap.abs() - 2;
      _frame(InputIntent(moveAxis: brake ? 0 : gap.sign, crouch: crouch));
    }
    hold(0.15, crouch: crouch);
  }

  void waitUntil(double time) {
    while (t < time) {
      _frame(InputIntent.none);
    }
  }

  /// Onto the step ahead, and off it onto whatever is beyond it.
  void climb(double direction) {
    hold(0.55, axis: direction, jump: true);
    hold(0.1);
    hold(0.7, axis: direction, jump: true);
  }

  String get where =>
      't=${t.toStringAsFixed(2)} '
      'x=${game.player.x.toStringAsFixed(0)} '
      'y=${game.player.y.toStringAsFixed(0)} '
      'reloads=${game.reloads}';
}

/// The highest a body gets its feet, standing, by climbing a step it ducks
/// for at [x] — searched, not scripted.
///
/// A recorded climb only proves the climb somebody wrote. The question a
/// level asks is whether *any* climb from here reaches, and the best ones are
/// not obvious: get onto your own head in place, shuffle toward the edge of
/// it for a moment, and jump from there with what momentum there is. This
/// tries every shuffle from none to over half a second, and gives back the
/// best. Ducks long, so the step is still there for every try.
double highestClimbFrom(
  LevelGame game,
  double x, {
  required double delay,
  double toward = 1,
}) {
  var best = double.infinity;
  for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
    game.reload();
    final run = Run(game)..walkTo(x);
    final ducked = run.t;
    run
      ..hold(3, crouch: true)
      ..waitUntil(ducked + delay + 0.1)
      ..hold(0.7, jump: true)
      ..hold(0.1)
      ..hold(shuffle * Playthrough.dt, axis: toward)
      ..hold(1.0, axis: toward, jump: true);
    if (run.highest < best) best = run.highest;
  }
  return best;
}

/// The highest a body gets its feet by building a stair of both pasts at [x]
/// (`Levels.stairOfYourself`'s way) and jumping off the top of it — searched
/// like [highestClimbFrom]: every shuffle toward the edge of the top step
/// before the jump.
///
/// [first] is played before anything, to get wherever the stair is going.
/// The delays are the levels' own two and five.
double highestStairClimbFrom(
  LevelGame game,
  double x, {
  List<Move> first = const [],
  double toward = 1,
}) {
  var best = double.infinity;
  for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
    game.reload();
    final run = Run(game)
      ..play(first)
      ..walkTo(x)
      ..hold(3.5, crouch: true) // the bottom step
      ..hold(1.6)
      ..hold(0.5, jump: true) // onto it
      ..hold(1.0, crouch: true) // the second step
      ..hold(1.0)
      ..hold(0.7, jump: true) // onto that
      ..hold(shuffle * Playthrough.dt, axis: toward)
      ..hold(1.0, axis: toward, jump: true);
    if (run.highest < best) best = run.highest;
  }
  return best;
}
