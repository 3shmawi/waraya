// Every level, swept for the cheapest run that finishes it.
//
// Three bugs reported from playing in one afternoon were all the same shape:
// the tests were green and the level was broken, because every recorded run
// solved it the way it was meant to be solved. What breaks a level is the run
// nobody wrote down — the one that tries to take it with the least possible
// effort rather than to solve it wrongly.
//
// So this plays a handful of thoughtless runs into every level and asks which
// ones finish. The runs are `cheapRuns` in `lib/level/level_check.dart`, the
// same list the gate throws at a level from outside.
//
// It found a walk-past that beat "two, not one" in 9.4 seconds, faster than
// its own solution: out and back crosses each plate twice, which
// is four presses from one walk, and with the turn as a free dial two of them
// slide exactly four seconds apart — the gap between the two shadows, handed
// over without the player ever working out what it was for.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cheaplyBeatable = Levels.cheapByDesign;

  for (final level in [...Levels.campaign]) {
    testWithGame<LevelGame>(
      'nothing cheap finishes ${level.id}',
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        final beaten = <String>[];
        final source = game.input.sources.first as ScriptedInput;
        for (final entry in cheapRuns(level).entries) {
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
