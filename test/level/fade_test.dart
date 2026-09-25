import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/ui/level_fade.dart';

import 'package:waraya/level/playthrough.dart';

/// The join between two levels.
///
/// Finishing used to be a cut — the goal filled in, and some frames later the
/// whole screen was a different place. Worse, `_build` empties the world
/// before it fills it, so there were frames of bare sky in between. What this
/// asks is only that the swap happens while the screen is black: everything
/// else about a transition is taste, but a level appearing out of nothing is
/// a bug you can see.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const double dt = 1 / 60;

  testWithGame<LevelGame>(
    'the swap between levels happens on a black frame',
    () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      final source = game.input.sources.first as ScriptedInput;
      final run = Playthrough(game, source);

      run.play(game.level.solution, stopWhenComplete: true);
      expect(game.completed, isTrue, reason: run.where);
      expect(
        game.fade.darkness,
        0,
        reason: 'nothing is covered while there is still a level to play',
      );

      // Forward one frame at a time, watching for the level to change under
      // us, and remember how black it was when it did.
      final startedOn = game.levelIndex;
      double? darknessAtSwap;
      for (var frame = 0; frame < 240 && darknessAtSwap == null; frame++) {
        source.next = InputIntent.none;
        game.update(dt);
        if (game.levelIndex != startedOn) darknessAtSwap = game.fade.darkness;
      }

      expect(darknessAtSwap, isNotNull, reason: 'the level never advanced');
      expect(
        darknessAtSwap,
        1,
        reason: 'the world is emptied and refilled on this frame',
      );

      // And then it lets go, or every level after the first is played in the
      // dark. The yield matters: `_build` is async, and the frame loop above
      // never turns the event loop, so nothing past its first `await` — the
      // reveal included — would ever run.
      for (var frame = 0; frame < 120; frame++) {
        source.next = InputIntent.none;
        game.update(dt);
        await Future<void>.value();
      }
      expect(game.fade.darkness, 0);
    },
  );

  testWithGame<LevelGame>(
    'finishing the last level does not leave the screen black',
    () => LevelGame(
      levels: Levels.campaign,
      startAt: Levels.campaign.length - 1,
      inputs: [ScriptedInput()],
    ),
    (game) async {
      await game.ready();
      final source = game.input.sources.first as ScriptedInput;
      final run = Playthrough(game, source);

      run.play(game.level.solution, stopWhenComplete: true);
      expect(game.completed, isTrue, reason: run.where);

      // Nothing gets built after the last level, so nothing would call
      // `reveal` — and whatever the campaign's ending puts up can be
      // dismissed, onto a screen that would have stayed black for good.
      for (var frame = 0; frame < 180; frame++) {
        source.next = InputIntent.none;
        game.update(dt);
        await Future<void>.value();
      }
      expect(game.fade.darkness, 0);
    },
  );

  testWithGame<LevelGame>(
    'a level picked from the menu arrives out of the dark too',
    () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      expect(game.fade.darkness, 0);

      final jump = game.goTo(3);
      expect(
        game.fade.darkness,
        1,
        reason: 'black before the new level is up, not after',
      );
      await jump;

      for (var frame = 0; frame < 120; frame++) {
        game.update(dt);
        await Future<void>.value();
      }
      expect(game.fade.darkness, 0);
      expect(game.levelIndex, 3);
    },
  );

  test('the dark fits inside the beat, with the goal seen first', () {
    // The goal is meant to have a moment to fill in before the dark starts,
    // and the dark is meant to have reached black before the swap rather than
    // still be on its way there.
    expect(LevelFade.startsAt, lessThan(LevelGame.advanceDelay));
    expect(LevelFade.coverSeconds, lessThan(LevelFade.startsAt));
  });
}
