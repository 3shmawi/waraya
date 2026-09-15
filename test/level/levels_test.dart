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
        final run = start(game)
          ..play(const [
            Move.right(1.8), // out to the plate, the wrong way from the door
            Move(1.2), // stand on it
            Move.left(4.8), // all the way to the door, and wait there
          ]);

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
        final run = start(game)
          ..play(const [
            Move.left(3.3), // out to the mark, under the ledge
            Move(2.5), // stand there long enough to leave a solid shadow
            Move.right(0.9), // get out of your own way
            Move(0.8), // wait for it to appear
            Move.left(0.45), // run at it
            Move.left(0.55, jump: true), // up onto its head
            Move.left(0.6, jump: true), // and off the head onto the ledge
            Move.left(1.5), // along to the way out
          ]);

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
        final run = start(game)
          ..play(const [
            Move.left(1.9), // into the corridor, onto the plate
            Move(1.0), // hold it down
            Move.left(0.5), // on to the dead end
            Move.left(0.5, jump: true), // up onto the step
            Move(0.25),
            Move.right(0.3), // a run at the gap
            Move.right(0.75, jump: true), // across onto the upper lane
            Move.right(1.7), // home, above your own footprints
            Move.right(2.5), // down off the end and through the door
          ]);

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

  group('the campaign holds together', () {
    test('teaches one thing at a time, in order', () {
      expect(Levels.campaign.first.id, 'press-it-early');
      expect(Levels.campaign.map((l) => l.id).toSet(), hasLength(3));
      // Only the third level can kill you: the first two are for working the
      // mechanic out without being punished for it.
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
