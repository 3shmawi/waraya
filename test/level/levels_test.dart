import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';

import 'package:waraya/game/config.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'solution.dart';

/// Every level ships with a recorded solution, and a recording of the obvious
/// wrong idea.
///
/// The solution proves the puzzle can still be finished; the wrong idea proves
/// it still has to be thought about. Both matter, and the second one matters
/// more: a level that can be beaten by holding one key is not a level, and the
/// first draft of `pressItEarly` was exactly that — the plate sat on the way
/// to the door, so walking left crossed it, and three seconds later the shadow
/// crossed it too and opened the door for a player who had done nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  LevelGame Function() build(Level level) =>
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]);

  group('press it early', () {
    testWithGame<LevelGame>(
      'stand on the plate, walk away, and your past opens the door',
      build(Levels.pressItEarly),
      (game) async {
        await game.ready();
        final run = start(game)..play(walkthroughs['press-it-early']!);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'walking straight at the door gets you a closed door',
      build(Levels.pressItEarly),
      (game) async {
        await game.ready();
        final run = start(game)..play(const [Move.left(8)]);

        expect(run.finishedAt, isNull, reason: run.where);
        expect(game.doors.first.openFraction, 0);
      },
    );
  });

  group('stand on yourself', () {
    testWithGame<LevelGame>(
      'stand still somewhere useless, then jump on what you left behind',
      build(Levels.standOnYourself),
      (game) async {
        await game.ready();
        final run = start(game)..play(walkthroughs['stand-on-yourself']!);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'the ledge is out of reach on your own legs',
      build(Levels.standOnYourself),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(3),
            Move.left(0.8, jump: true),
            Move.left(2),
            Move.left(0.8, jump: true),
            Move.left(2),
          ]);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );
  });

  group('not the same way back', () {
    testWithGame<LevelGame>(
      'in along the floor, home along the lane above it',
      build(Levels.notTheSameWayBack),
      (game) async {
        await game.ready();
        final run = start(game)..play(walkthroughs['not-the-same-way-back']!);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'going back the way you came walks you into yourself',
      build(Levels.notTheSameWayBack),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(1.9),
            Move(1.0),
            Move.right(2.5), // straight back out along the floor
            Move(4), // and wait by the door like a sitting duck
          ]);

        expect(game.reloads, greaterThan(0), reason: run.where);
        expect(run.finishedAt, isNull);
      },
    );
  });

  group('take it with you', () {
    testWithGame<LevelGame>(
      'press it on the shelf, then jump into a hole you cannot climb out of',
      build(Levels.takeItWithYou),
      (game) async {
        await game.ready();
        final run = start(game)..play(walkthroughs['take-it-with-you']!);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'jumping in without pressing it first leaves you in the hole',
      build(Levels.takeItWithYou),
      (game) async {
        await game.ready();
        final run = start(game)..play(const [Move.left(9)]);

        expect(run.finishedAt, isNull, reason: run.where);
        expect(game.doors.first.openFraction, 0);
        expect(
          game.player.y,
          greaterThan(Levels.takeItWithYou.floorTop),
          reason: 'and down in the pit, with only R to get out',
        );
      },
    );
  });

  group('both at once', () {
    testWithGame<LevelGame>(
      'one shadow, two jobs, in the order you laid them down',
      build(Levels.bothAtOnce),
      (game) async {
        await game.ready();
        final run = start(game)..play(walkthroughs['both-at-once']!);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'the door still will not open for someone who skipped the plate',
      build(Levels.bothAtOnce),
      (game) async {
        await game.ready();
        final run = start(game)..play(const [Move.right(8)]);

        expect(run.finishedAt, isNull, reason: run.where);
        expect(game.doors.first.openFraction, 0);
      },
    );

    testWithGame<LevelGame>(
      'and the ledge past it is still out of reach on your own legs',
      build(Levels.bothAtOnce),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            // The plate half, played properly, to get through the door.
            Move.left(1.1),
            Move(1.2),
            Move.right(2.0),
            Move.right(1.2),
            // Then the honest attempt: run at the ledge and jump.
            Move.right(1.2),
            Move.right(0.8, jump: true),
            Move.right(1.5),
            Move.right(0.8, jump: true),
            Move.right(1.5),
          ]);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );
  });

  group('the campaign holds together', () {
    test('teaches one thing at a time, in order', () {
      expect(Levels.campaign.first.id, 'press-it-early');
      expect(Levels.campaign.map((l) => l.id).toSet(), hasLength(5));
      // Exactly one level can kill you, and it is not one of the first two:
      // the opening levels are for working the mechanic out without being
      // punished for it.
      expect(Levels.campaign.where((l) => l.shadowKills), hasLength(1));
      expect(Levels.campaign.take(2).any((l) => l.shadowKills), isFalse);
    });

    test('every level is winnable at a delay the panel can produce', () {
      for (final level in [...Levels.campaign, Levels.lab]) {
        expect(
          level.delaySeconds,
          inInclusiveRange(0.5, 6),
          reason: '${level.id} asks for a delay outside the slider',
        );
      }
    });

    test('nobody spawns inside the scenery', () {
      const bodyHeight = 96.0;
      for (final level in [...Levels.campaign, Levels.lab]) {
        final spawn = Rect.fromLTWH(
          level.spawnX - 22,
          level.floorTop - bodyHeight,
          44,
          bodyHeight,
        );
        for (final block in level.blocks) {
          expect(
            spawn.overlaps(block),
            isFalse,
            reason: '${level.id} spawns inside a block',
          );
        }
        for (final door in level.doors) {
          expect(
            spawn.overlaps(door.closed),
            isFalse,
            reason: '${level.id} spawns inside its own door',
          );
        }
      }
    });

    test('the goal is never somewhere a jump could not land', () {
      // Not a solvability proof — the playthroughs above are that. This only
      // catches a goal left floating in the sky by a bad edit.
      const jumpHeight =
          WarayaConfig.jumpSpeed *
          WarayaConfig.jumpSpeed /
          (2 * WarayaConfig.gravity);
      for (final level in Levels.campaign) {
        final standable = [for (final block in level.blocks) block.top]..sort();
        final reachable = standable.any(
          (top) => (top - level.goal.bottom).abs() < jumpHeight + 96,
        );
        expect(reachable, isTrue, reason: '${level.id} goal is unreachable');
      }
    });
  });
}
