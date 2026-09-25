import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'package:waraya/level/playthrough.dart';

/// The whole campaign, start to finish, in one game.
///
/// The per-level tests each build a game around one level. This one plays the
/// real list in the real order, so it also covers the thing those cannot: that
/// finishing a level actually hands over to the next one with everything —
/// the buffer, the shadow, the doors, the plates — put back the way a fresh
/// level expects to find it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<LevelGame>(
    'five levels, one sitting, no reloads needed',
    () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      final run = Playthrough(game, game.input.sources.first as ScriptedInput);

      for (var i = 0; i < Levels.campaign.length; i++) {
        final level = Levels.campaign[i];
        expect(
          game.level.id,
          level.id,
          reason: 'expected to be on ${level.id} by now (${run.where})',
        );

        run.play(level.solution, stopWhenComplete: true);
        expect(
          game.completed,
          isTrue,
          reason: '${level.id} was not finished (${run.where})',
        );

        // The beat between touching the goal and the next level appearing.
        run.play(const [Move(1.2)]);
      }

      expect(run.finishes, hasLength(Levels.campaign.length));
      expect(game.levelIndex, Levels.campaign.length - 1);
      expect(
        game.reloads,
        0,
        reason: 'the recorded run should never need to restart a level',
      );
    },
  );
}
