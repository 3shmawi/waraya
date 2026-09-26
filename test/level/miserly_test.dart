// Every level, swept for the cheapest run that finishes it.
//
// Three bugs reported from playing in one afternoon were all the same shape:
// the tests were green and the level was broken, because every recorded run
// solved it the way it was meant to be solved. What breaks a level is the run
// nobody wrote down — the one that tries to take it with the least possible
// effort rather than to solve it wrongly.
//
// So this plays a handful of thoughtless runs into every level and asks which
// ones finish. It found a walk-past that beat "two, not one" in 9.4 seconds,
// faster than its own solution: out and back crosses each plate twice, which
// is four presses from one walk, and with the turn as a free dial two of them
// slide exactly four seconds apart — the gap between the two shadows, handed
// over without the player ever working out what it was for.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs that try to take a level with the least possible thought.
  Map<String, List<Move>> misers(Level level) {
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
      'touch what is behind you, then run': [back(2.2), Move(0.1), go(12)],
      'touch what is behind you further back, then run': [
        back(3.6),
        Move(0.1),
        go(12),
      ],
      'duck on the way past, then run': [back(2.2, crouch: true), go(12)],
      'wait for the shadow, then hold': [Move(5), go(12)],
    };
  }

  /// The levels whose intended solution **is** one of these runs, and which
  /// are therefore expected to fall to it.
  ///
  /// Not a list of things to fix. Each of these is a level whose lesson is
  /// that a small deliberate act, done early, is enough — pressing a plate on
  /// your way past and walking on (`press-it-early`), stepping onto one and
  /// throwing yourself off a ledge (`take-it-with-you`), brushing a key and
  /// leaving before your past shuts it (`close-what-you-opened`). A sweep
  /// that finishes them is the sweep agreeing with the design.
  ///
  /// It is a list that should only ever get shorter. Adding to it means
  /// deciding a level is meant to be finishable without thought, which is a
  /// thing to argue about rather than to do while fixing something else.
  const cheaplyBeatable = {
    'press-it-early',
    'take-it-with-you',
    'close-what-you-opened',
  };

  for (final level in [...Levels.campaign]) {
    testWithGame<LevelGame>(
      'nothing cheap finishes ${level.id}',
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        final beaten = <String>[];
        final source = game.input.sources.first as ScriptedInput;
        for (final entry in misers(level).entries) {
          // The game's own retry puts everything back, buffer included, which
          // is exactly a fresh attempt.
          game.reload();
          final run = Playthrough(game, source)
            ..play(entry.value, stopWhenComplete: true);
          if (run.finishedAt != null) {
            beaten.add('${entry.key} (${run.finishedAt!.toStringAsFixed(1)}s)');
          }
        }
        expect(
          beaten,
          cheaplyBeatable.contains(level.id) ? isNotEmpty : isEmpty,
          reason: cheaplyBeatable.contains(level.id)
              ? '${level.id} is listed as one a terse run finishes, and no '
                    'longer is — take it off the list'
              : '${level.id} can be finished without being played: '
                    '${beaten.join(" | ")}',
        );
      },
    );
  }
}
