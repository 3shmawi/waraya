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

    // Reported from a real playthrough: stuck on the end of the lane, shut
    // door, level restarting over and over.
    //
    // The door used to be held open only for as long as the player had stood
    // on the plate — under a second — and that window arrived exactly five
    // seconds later. Pausing to look around cost more than the window was
    // wide, and then there was a shut door in front, a sixteen-unit shelf
    // underfoot and your own past walking up it behind you: no door, no room
    // to dodge, nothing to do. Latching the door fixed it. This pins that
    // hesitating is survivable, because a player who is thinking is the
    // normal case and not a mistake.
    for (final pause in const [1.0, 2.0, 3.0]) {
      testWithGame<LevelGame>(
        'stopping to think for ${pause}s on the lane is not fatal',
        build(Levels.notTheSameWayBack),
        (game) async {
          await game.ready();
          final run = start(game)
            ..play([
              ...walkthroughs['not-the-same-way-back']!.take(7),
              Move(pause),
              ...walkthroughs['not-the-same-way-back']!.skip(7),
            ], stopWhenComplete: true);

          expect(run.finishedAt, isNotNull, reason: run.where);
          expect(game.reloads, 0, reason: run.where);
        },
      );
    }
  });

  group('go in low', () {
    testWithGame<LevelGame>(
      'build the ladder in the one place you are allowed to stand up',
      build(Levels.goInLow),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(walkthroughs['go-in-low']!, stopWhenComplete: true);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'the same moves, with a shadow that is not a surface, go nowhere',
      () => LevelGame(
        levels: [
          Level(
            id: 'go-in-low-soft',
            name: Levels.goInLow.name,
            teaches: Levels.goInLow.teaches,
            delaySeconds: Levels.goInLow.delaySeconds,
            spawnX: Levels.goInLow.spawnX,
            floorTop: Levels.goInLow.floorTop,
            shadowIsSolid: false,
            blocks: Levels.goInLow.blocks,
            goal: Levels.goInLow.goal,
          ),
        ],
        inputs: [ScriptedInput()],
      ),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(walkthroughs['go-in-low']!, stopWhenComplete: true);

        // Not a corridor: take the thing to climb away and the identical run
        // ends on the floor.
        expect(run.finishedAt, isNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'walking in upright never gets under the roof at all',
      build(Levels.goInLow),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(0.5),
            Move.left(3.5), // straight at it, standing: the roof says no
            Move(1.0),
            Move.right(0.6, jump: true),
            Move.right(0.6, jump: true),
            Move(2.0),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'jumping at the way out from underneath it does not reach',
      build(Levels.goInLow),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(0.9), // in under the roof, below the goal
            Move(0.3),
            Move(0.6, jump: true), // and up at it, repeatedly
            Move(0.6, jump: true),
            Move.left(0.4, crouch: true),
            Move(0.6, jump: true),
            Move(2.0),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
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

  group('hold your own door', () {
    testWithGame<LevelGame>(
      'climb the body that is holding the door, while it is holding it',
      build(Levels.holdYourOwnDoor),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(walkthroughs['hold-your-own-door']!, stopWhenComplete: true);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    // The lesson, stated as a test: the press is the timer. A short one gets
    // you all the way onto the shelf and no further, which is a failure the
    // player can read off the screen without being told anything.
    testWithGame<LevelGame>(
      'a one-second press leaves you on the shelf at a shut door',
      build(Levels.holdYourOwnDoor),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(2.1),
            Move(1.0), // barely stood on it at all
            Move.left(0.6),
            Move(3.6), // wait the same amount, so only the press differs
            Move.right(0.75, jump: true),
            Move(0.2),
            Move.right(0.75, jump: true),
            Move.right(1.6),
            Move.right(1.5),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
        // On the shelf, which is the point: the climb worked and the door is
        // what stopped you.
        expect(game.player.y, Levels.holdYourOwnDoor.blocks.last.top);
      },
    );

    testWithGame<LevelGame>(
      'the shut door cannot be hopped over from the shelf',
      build(Levels.holdYourOwnDoor),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(2.1),
            Move(3.0),
            Move.left(0.6),
            Move(1.6),
            Move.right(0.75, jump: true),
            Move(0.2),
            Move.right(0.75, jump: true),
            Move.right(0.7),
            Move(3.0), // stand on the shelf and let it shut again
            Move.right(0.6, jump: true), // then try to jump it
            Move.right(0.8, jump: true),
            Move.right(1.5),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'never touching the plate never gets you off the floor',
      build(Levels.holdYourOwnDoor),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(1.0),
            Move(0.5),
            Move.left(0.6, jump: true),
            Move.right(0.8, jump: true),
            Move.right(1.2, jump: true),
            Move(2.0),
            Move.right(1.5, jump: true),
            Move(3.0),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );
  });

  group('a door is something your past is holding', () {
    // The exploit above, played out in the level it broke worst.
    testWithGame<LevelGame>(
      'leaving a body at the door and climbing it does not get you through',
      build(Levels.pressItEarly),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(0.9), // up to the door, the direct way
            Move(1.6), // stand there long enough to leave a ladder
            Move.right(0.5), // out of your own way
            Move(1.6), // wait for it to arrive at the door
            Move.left(0.45, jump: true), // onto your own head
            Move(0.15),
            Move.left(0.7, jump: true), // and over the door, in theory
            Move.left(1.6),
            Move(1.5),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
        expect(game.doors.first.openFraction, 0);
      },
    );

    // Reported from playing: "the door stays open". It did — the first fix for
    // level three latched it open forever, which reads as a broken door rather
    // than as a door somebody is holding. A linger is a grace period, not a
    // latch, and the proof is that it ends.
    testWithGame<LevelGame>(
      'level three opens when your past arrives and shuts again after it goes',
      build(Levels.notTheSameWayBack),
      (game) async {
        await game.ready();
        final run = start(game);
        final door = game.doors.first;

        var everOpened = false;
        var shutAgainAfterOpening = false;
        // Onto the plate, off it, and then well out of the way, watching the
        // door for the whole of the shadow's visit and long after it.
        for (final move in const [
          Move.left(1.9),
          Move(1.0),
          Move.left(0.6),
          Move(18.0),
        ]) {
          final frames = (move.seconds / Playthrough.dt).round();
          for (var i = 0; i < frames; i++) {
            run.play([Move(Playthrough.dt, axis: move.axis)]);
            if (door.openFraction > 0.9) everOpened = true;
            if (everOpened && door.openFraction == 0) {
              shutAgainAfterOpening = true;
            }
          }
        }

        expect(everOpened, isTrue, reason: 'never opened at all: ${run.where}');
        expect(
          shutAgainAfterOpening,
          isTrue,
          reason: 'opened and stayed open forever: ${run.where}',
        );
      },
    );

    // Reported from playing level seven: "I am a bit away from the plate and
    // it still opens the door as if I were standing on it."
    testWithGame<LevelGame>(
      'standing beside a plate with one edge over it does not press it',
      () => LevelGame(
        levels: [
          Level(
            id: 'footprint',
            name: 'footprint',
            teaches: '',
            delaySeconds: 3,
            // A body is 44 wide, so a body centred 21 to the right of the
            // plate's edge is touching it by a single unit and standing
            // entirely off it.
            spawnX: 21,
            floorTop: 620,
            blocks: [const Rect.fromLTRB(-600, 620, 600, 1200)],
            plates: const [
              PlateSpec(area: Rect.fromLTRB(-100, 608, 0, 620), opens: 'gate'),
            ],
            doors: const [
              DoorSpec(id: 'gate', closed: Rect.fromLTRB(300, 430, 326, 620)),
            ],
            goal: const Rect.fromLTRB(400, 548, 480, 620),
          ),
        ],
        inputs: [ScriptedInput()],
      ),
      (game) async {
        await game.ready();
        start(game).play(const [Move(0.5)]);

        expect(game.plates.first.isPressed, isFalse);
        expect(game.doors.first.openFraction, 0);
      },
    );
  });

  group('the campaign holds together', () {
    test('teaches one thing at a time, in order', () {
      expect(Levels.campaign.first.id, 'press-it-early');
      // Unique ids, not a count: the campaign is meant to grow, and a magic
      // number here only ever fails for the wrong reason. Duplicates would be
      // a real problem — a server-sent level is matched to a built-in one by
      // id, so two of anything means one of them silently never loads.
      expect(
        Levels.campaign.map((l) => l.id).toSet(),
        hasLength(Levels.campaign.length),
      );
      // Exactly one level can kill you, and it is not one of the first two:
      // the opening levels are for working the mechanic out without being
      // punished for it.
      expect(Levels.campaign.where((l) => l.shadowKills), hasLength(1));
      expect(Levels.campaign.take(2).any((l) => l.shadowKills), isFalse);
    });

    // Reported from playing: "I can climb the wall if I stand on the shadow,
    // so there are two ways past a wall." There were. A jump lifts about 136
    // and a body is 96 tall, so a player standing on a shadow that is standing
    // at a door's foot gets their feet 232 above that door's sill — and every
    // door in the game was 190 tall. Leave a body by the door, climb it, step
    // over: a second solution to every door in the campaign, and the only
    // thing the first level is about.
    test('no door can be climbed by standing on a shadow at its foot', () {
      final reach =
          WarayaConfig.jumpSpeed *
              WarayaConfig.jumpSpeed /
              (2 * WarayaConfig.gravity) +
          96;
      expect(
        Levels.minDoorHeight,
        greaterThan(reach),
        reason: 'the rule itself has to clear the boost',
      );
      for (final level in [...Levels.campaign, Levels.lab]) {
        for (final door in level.doors) {
          expect(
            door.closed.height,
            greaterThanOrEqualTo(Levels.minDoorHeight),
            reason:
                '${level.id}: a body on a shadow at this door\'s foot reaches '
                '${reach.toStringAsFixed(0)} above its sill',
          );
        }
      }
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
