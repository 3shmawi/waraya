import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/progress/progress.dart';

import 'package:waraya/level/playthrough.dart';

Level _level(String id) => Level(
  id: id,
  name: id,
  teaches: '',
  delaySeconds: 3,
  spawnX: 0,
  goal: const Rect.fromLTRB(100, 548, 180, 620),
  blocks: [const Rect.fromLTRB(-600, 620, 600, 1200)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('what is unlocked', () {
    final campaign = [_level('a'), _level('b'), _level('c')];

    test('a first-time player is offered exactly one thing', () {
      expect(unlockedCount(campaign, {}), 1);
      expect(resumeIndex(campaign, {}), 0);
    });

    test('beating one opens the next', () {
      expect(unlockedCount(campaign, {'a'}), 2);
      expect(resumeIndex(campaign, {'a'}), 1);
    });

    test('beating everything leaves you on the last one', () {
      expect(unlockedCount(campaign, {'a', 'b', 'c'}), 3);
      expect(resumeIndex(campaign, {'a', 'b', 'c'}), 2);
    });

    // The whole reason progress is kept by id: the campaign is a list that is
    // meant to grow, and `LevelsThenExtras` exists so a server can append to
    // it. A remembered position would quietly mean a different level.
    test('a level inserted in the middle does not hand out the ones after it', () {
      final grown = [_level('a'), _level('new'), _level('b'), _level('c')];
      expect(unlockedCount(grown, {'a', 'b'}), 2);
      expect(resumeIndex(grown, {'a', 'b'}), 1);
    });

    test('ids that are no longer in the campaign are ignored', () {
      expect(unlockedCount(campaign, {'a', 'deleted-level'}), 2);
    });

    test('an empty campaign asks for nothing', () {
      expect(unlockedCount(const [], {}), 0);
      expect(resumeIndex(const [], {}), 0);
    });
  });

  group('MemoryProgress', () {
    test('remembers, ignores repeats, and forgets on request', () async {
      final progress = MemoryProgress();
      expect(await progress.beaten(), isEmpty);

      await progress.record('a');
      await progress.record('a');
      await progress.record('b');
      expect(await progress.beaten(), {'a', 'b'});

      await progress.clear();
      expect(await progress.beaten(), isEmpty);
    });

    test('hands out a copy, so a caller cannot edit the record', () async {
      final progress = MemoryProgress(['a']);
      (await progress.beaten()).add('b');
      expect(await progress.beaten(), {'a'});
    });
  });

  group('the game reports what it finished', () {
    testWithGame<LevelGame>(
      'beating a level names it, and the last one ends the campaign',
      () {
        return LevelGame(
          levels: [Levels.pressItEarly, Levels.standOnYourself],
          inputs: [ScriptedInput()],
          onBeaten: (level) => _beaten.add(level.id),
          onCampaignFinished: () => _finished++,
        );
      },
      (game) async {
        _beaten.clear();
        _finished = 0;
        await game.ready();
        final run = Playthrough(game, game.input.sources.first as ScriptedInput);

        run.play(Levels.pressItEarly.solution, stopWhenComplete: true);
        expect(_beaten, ['press-it-early']);
        expect(_finished, 0, reason: 'there is another level to go to');

        run.play(const [Move(1.2)]);
        expect(game.levelIndex, 1);

        run.play(Levels.standOnYourself.solution, stopWhenComplete: true);
        run.play(const [Move(1.5)]);
        expect(_beaten, ['press-it-early', 'stand-on-yourself']);
        expect(_finished, 1, reason: 'nothing left to advance to');
      },
    );

    testWithGame<LevelGame>(
      'startAt drops you into a level in the middle',
      () => LevelGame(
        levels: Levels.campaign,
        inputs: [ScriptedInput()],
        startAt: 3,
      ),
      (game) async {
        await game.ready();
        expect(game.level.id, Levels.campaign[3].id);
      },
    );

    testWithGame<LevelGame>(
      'startAt past the end lands on the last level rather than crashing',
      () => LevelGame(
        levels: Levels.campaign,
        inputs: [ScriptedInput()],
        startAt: 99,
      ),
      (game) async {
        await game.ready();
        expect(game.level.id, Levels.campaign.last.id);
      },
    );

    testWithGame<LevelGame>(
      'goTo puts a fresh level up, with nothing left over from the old one',
      () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        final run = Playthrough(game, game.input.sources.first as ScriptedInput)
          ..play(const [Move.right(1.9), Move(1.2)]);
        expect(game.plates.first.isPressed, isTrue);

        await game.goTo(4);

        expect(game.level.id, Levels.campaign[4].id);
        expect(game.completed, isFalse);
        expect(game.reloads, 0);
        expect(
          game.recorder.pending,
          isEmpty,
          reason: 'a new level must not inherit the old one\'s history',
        );
        expect(game.plates.first.isPressed, isFalse);

        // And the body is at the new level's spawn, not wherever the old one
        // left it.
        run.play(const [Move(1 / 60)]);
        expect(game.player.x, closeTo(Levels.campaign[4].spawnX, 1));
      },
    );
  });
}

final List<String> _beaten = [];
int _finished = 0;
