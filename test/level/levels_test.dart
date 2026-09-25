import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';

import 'package:waraya/game/config.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'package:waraya/level/playthrough.dart';

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
        final run = start(game)..play(Levels.pressItEarly.solution);

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
        final run = start(game)..play(Levels.standOnYourself.solution);

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
        final run = start(game)..play(Levels.notTheSameWayBack.solution);

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
              ...Levels.notTheSameWayBack.solution.take(7),
              Move(pause),
              ...Levels.notTheSameWayBack.solution.skip(7),
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
          ..play(Levels.goInLow.solution, stopWhenComplete: true);

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
          ..play(Levels.goInLow.solution, stopWhenComplete: true);

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
        final run = start(game)..play(Levels.takeItWithYou.solution);

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
        final run = start(game)..play(Levels.bothAtOnce.solution);

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
          ..play(Levels.holdYourOwnDoor.solution, stopWhenComplete: true);

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

  group('close what you opened', () {
    testWithGame<LevelGame>(
      'touch the key and leave, because the door is already counting down',
      build(Levels.closeWhatYouOpened),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(
            Levels.closeWhatYouOpened.solution,
            stopWhenComplete: true,
          );

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    // The wrong idea, and the reason this level exists. Six levels have taught
    // one move — leave a body somewhere and let it press what you cannot reach
    // — so the instinct on finding a key is to stand on it and wait for
    // yourself to arrive and hold it down. On a key that arrival is the flip
    // that shuts the door, and it shuts it for good: the shadow is standing on
    // the key now, and a body already standing on one is not an arrival.
    testWithGame<LevelGame>(
      'waiting on the key for your past to hold it shuts the door instead',
      build(Levels.closeWhatYouOpened),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(1.7), // out to the key
            Move(5.2), // and wait there, the way a plate would want
            Move.right(3.2), // then go — to a door that shut behind you
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
        expect(
          game.toggles.first.flipped,
          isFalse,
          reason: 'your own arrival put the key back',
        );
        expect(game.doors.first.openFraction, 0);
      },
    );

    testWithGame<LevelGame>(
      'and holding one direction gets you a shut door either way',
      build(Levels.closeWhatYouOpened),
      (game) async {
        await game.ready();
        // Right is the way out, and the door is shut because nothing has been
        // touched. Left is the key, and the key is at a wall with nothing
        // behind it. Neither is a level you can hold one arrow through — the
        // failure the first draft of `pressItEarly` had.
        final run = start(game)..play(const [Move.right(8)]);
        expect(run.finishedAt, isNull, reason: run.where);
        expect(game.doors.first.openFraction, 0);
      },
    );

    testWithGame<LevelGame>(
      'crossing the key twice puts it back where it was',
      build(Levels.closeWhatYouOpened),
      (game) async {
        await game.ready();
        // The arithmetic the level is built on, and the reason there is a wall
        // past the key: a flip is a flip, so two of them are none. Standing on
        // the key here and stepping off and on again is the same undoing your
        // shadow does, only sooner.
        final run = start(game)..play(const [Move.left(1.2)]);
        expect(game.toggles.first.flipped, isTrue, reason: run.where);

        run
          ..play(const [Move.right(1.0)]) // off it, back towards the door
          ..play(const [Move.left(1.0)]); // and onto it a second time
        expect(game.toggles.first.flipped, isFalse, reason: run.where);
      },
    );
  });

  // The other half of the same vocabulary, and the half with no campaign level
  // of its own yet: a plate that holds its door **shut**. Proved here on a
  // level built for the purpose, because what has to be true of it is a rule
  // rather than a puzzle — and because the two readings of it differ by one
  // flag, which is exactly what a test can hold still.
  group('a plate that inverts', () {
    /// A plate at the spawn that opens the gate, an inverted plate three
    /// hundred units to the right, and a delay long enough that the shadow
    /// arrives at the first one while the player is standing on the second.
    LevelGame Function() bench({bool inverts = true, double linger = 0}) =>
        () => LevelGame(
          levels: [
            Level(
              id: 'inverted',
              name: 'inverted',
              teaches: '',
              delaySeconds: 3,
              spawnX: -450,
              floorTop: 620,
              blocks: [const Rect.fromLTRB(-900, 620, 900, 1200)],
              plates: [
                const PlateSpec(
                  area: Rect.fromLTRB(-500, 608, -400, 620),
                  opens: 'gate',
                ),
                PlateSpec(
                  area: const Rect.fromLTRB(-160, 608, -40, 620),
                  opens: 'gate',
                  inverts: inverts,
                ),
              ],
              doors: [
                DoorSpec(
                  id: 'gate',
                  closed: const Rect.fromLTRB(300, 360, 326, 620),
                  lingerSeconds: linger,
                ),
              ],
              goal: const Rect.fromLTRB(400, 548, 480, 620),
            ),
          ],
          inputs: [ScriptedInput()],
        );

    /// Stand on the first plate for three seconds, then walk right onto the
    /// second one and stay there. Three seconds is the delay, so from then on
    /// the shadow is standing on the opening plate for as long as the player
    /// stood on it — and the player is on the inverted one throughout.
    void walkOntoIt(Playthrough run) =>
        run.play(const [Move(3.0), Move.right(1.6), Move(0.4)]);

    testWithGame<LevelGame>(
      'a body on it beats the past holding the plate that opens the door',
      bench(),
      (game) async {
        await game.ready();
        final run = start(game);
        walkOntoIt(run);

        expect(
          game.plates.first.pressedByShadow,
          isTrue,
          reason: 'the shadow should be on the opening plate by now',
        );
        expect(game.plates.last.pressedByPlayer, isTrue, reason: run.where);
        expect(
          game.doors.first.openFraction,
          0,
          reason: 'held shut while a body is on the inverted plate',
        );
      },
    );

    testWithGame<LevelGame>(
      'and the same level with the flag off opens exactly as it used to',
      bench(inverts: false),
      (game) async {
        await game.ready();
        final run = start(game);
        walkOntoIt(run);

        expect(
          game.doors.first.openFraction,
          greaterThan(0.9),
          reason: 'two plates, neither inverted, one open door: ${run.where}',
        );
      },
    );

    testWithGame<LevelGame>(
      'it beats the linger too, which is the point of it beating anything',
      bench(linger: 6),
      (game) async {
        await game.ready();
        final run = start(game)
          // A second on the opening plate arms six seconds of grace, and then
          // the player walks onto the inverted one. A door that drifted open
          // again because something stood on a plate six seconds ago is not a
          // door anybody is holding.
          ..play(const [Move(1.0), Move.right(1.6), Move(0.6)]);

        expect(game.doors.first.openFraction, 0, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'and lets go the moment the body steps off it',
      bench(),
      (game) async {
        await game.ready();
        final run = start(game);
        walkOntoIt(run);
        // Off it, and still inside the window where the shadow is holding the
        // opening plate down.
        run.play(const [Move.right(0.6)]);

        expect(
          game.doors.first.openFraction,
          greaterThan(0),
          reason: run.where,
        );
      },
    );
  });

  group('your shadow is not here', () {
    testWithGame<LevelGame>(
      'leave the body in the dark, and it is something to climb',
      build(Levels.yourShadowIsNotHere),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(
            Levels.yourShadowIsNotHere.solution,
            stopWhenComplete: true,
          );

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    // The wrong idea, and the only one worth recording: leave it in the
    // obvious place. The obvious place is hard against the shelf, where the
    // climb is shortest — and it is lit, so what you come back to is a shape
    // you fall straight through.
    testWithGame<LevelGame>(
      'leave it in the beam and you go through it',
      build(Levels.yourShadowIsNotHere),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(1.3), // out to the mark under the light this time
            Move(2.2),
            Move.left(0.6),
            Move(1.3),
          ]);

        expect(
          game.shadowInLight,
          isTrue,
          reason: 'the body was left in the beam: ${run.where}',
        );

        run.play(const [
          Move.right(0.12),
          Move.right(0.55, jump: true), // at your own head, in theory
          Move(0.1),
          Move.right(0.6, jump: true),
          Move.right(1.6),
        ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'and the shelf is out of reach on your own legs',
      build(Levels.yourShadowIsNotHere),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(1.0),
            Move.left(0.8, jump: true),
            Move(0.6),
            Move.right(0.8, jump: true),
            Move(0.6),
            Move.right(0.8, jump: true),
            Move(1.0),
          ]);

        expect(
          game.player.y,
          Levels.yourShadowIsNotHere.floorTop,
          reason: 'got onto something without a body to stand on: ${run.where}',
        );
        expect(run.finishedAt, isNull, reason: run.where);
      },
    );
  });

  // The rule itself, on levels built for it. What the campaign level proves is
  // that a lit shadow is nothing to stand on; these are the other three halves
  // of the same sentence, and each is the same level twice with the light
  // moved out of it.
  group('a shadow in the light', () {
    LevelGame Function() plateBench({required bool lit}) =>
        () => LevelGame(
          levels: [
            Level(
              id: 'lit-plate',
              name: 'lit-plate',
              teaches: '',
              delaySeconds: 2,
              spawnX: 0,
              floorTop: 620,
              blocks: [const Rect.fromLTRB(-900, 620, 900, 1200)],
              plates: const [
                PlateSpec(area: Rect.fromLTRB(-50, 608, 50, 620), opens: 'gate'),
              ],
              doors: const [
                DoorSpec(id: 'gate', closed: Rect.fromLTRB(400, 360, 426, 620)),
              ],
              lights: lit
                  ? const [Rect.fromLTRB(-70, 200, 70, 620)]
                  : const [],
              goal: const Rect.fromLTRB(600, 548, 680, 620),
            ),
          ],
          inputs: [ScriptedInput()],
        );

    /// Stand on the plate for a second, walk off it, and wait for the shadow
    /// to arrive back on it two seconds later.
    void standThenLeave(Playthrough run) =>
        run.play(const [Move(1.0), Move.right(1.0), Move(1.0)]);

    testWithGame<LevelGame>(
      'presses no plate, so the door it would have opened stays shut',
      plateBench(lit: true),
      (game) async {
        await game.ready();
        final run = start(game);
        standThenLeave(run);

        expect(game.shadowInLight, isTrue, reason: run.where);
        expect(game.plates.first.pressedByShadow, isFalse);
        expect(game.doors.first.openFraction, 0, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'and with the beam taken away the same body opens it',
      plateBench(lit: false),
      (game) async {
        await game.ready();
        final run = start(game);
        standThenLeave(run);

        expect(game.shadowInLight, isFalse);
        expect(game.plates.first.pressedByShadow, isTrue, reason: run.where);
        expect(game.doors.first.openFraction, greaterThan(0.9));
      },
    );

    LevelGame Function() keyBench({required bool lit}) =>
        () => LevelGame(
          levels: [
            Level(
              id: 'lit-key',
              name: 'lit-key',
              teaches: '',
              delaySeconds: 2,
              spawnX: 0,
              floorTop: 620,
              blocks: [const Rect.fromLTRB(-900, 620, 900, 1200)],
              toggles: const [
                ToggleSpec(
                  area: Rect.fromLTRB(-50, 608, 50, 620),
                  flips: 'gate',
                ),
              ],
              doors: const [
                DoorSpec(id: 'gate', closed: Rect.fromLTRB(400, 360, 426, 620)),
              ],
              lights: lit
                  ? const [Rect.fromLTRB(-70, 200, 70, 620)]
                  : const [],
              goal: const Rect.fromLTRB(600, 548, 680, 620),
            ),
          ],
          inputs: [ScriptedInput()],
        );

    testWithGame<LevelGame>(
      'throws no key, so what you opened stays open',
      keyBench(lit: true),
      (game) async {
        await game.ready();
        final run = start(game);
        // The player's own arrival threw it on the first frame; the shadow's
        // arrival is the one that would throw it back.
        standThenLeave(run);

        expect(game.shadowInLight, isTrue, reason: run.where);
        expect(game.toggles.first.flipped, isTrue, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'and out of the beam it throws it back, as a key does',
      keyBench(lit: false),
      (game) async {
        await game.ready();
        final run = start(game);
        standThenLeave(run);

        expect(game.toggles.first.flipped, isFalse, reason: run.where);
      },
    );

    LevelGame Function() killBench({required bool lit}) =>
        () => LevelGame(
          levels: [
            Level(
              id: 'lit-kill',
              name: 'lit-kill',
              teaches: '',
              delaySeconds: 2,
              spawnX: 0,
              floorTop: 620,
              shadowKills: true,
              blocks: [const Rect.fromLTRB(-900, 620, 900, 1200)],
              lights: lit
                  ? const [Rect.fromLTRB(-70, 200, 70, 620)]
                  : const [],
              goal: const Rect.fromLTRB(600, 548, 680, 620),
            ),
          ],
          inputs: [ScriptedInput()],
        );

    testWithGame<LevelGame>(
      'catches nobody: stand still and your past walks into you harmlessly',
      killBench(lit: true),
      (game) async {
        await game.ready();
        // Standing still means the shadow arrives exactly where the player is.
        final run = start(game)..play(const [Move(3.0)]);

        expect(game.shadowInLight, isTrue, reason: run.where);
        expect(game.reloads, 0, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'and in the dark the same standing still is a death',
      killBench(lit: false),
      (game) async {
        await game.ready();
        final run = start(game)..play(const [Move(3.0)]);

        expect(game.reloads, greaterThan(0), reason: run.where);
      },
    );
  });

  group('two, not one', () {
    testWithGame<LevelGame>(
      'two plates at once, held by the two of you that are four apart',
      build(Levels.twoNotOne),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(Levels.twoNotOne.solution, stopWhenComplete: true);

        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    // The proof that the second delay is load-bearing rather than decoration:
    // the same level, the same recorded run, one shadow instead of two. A gate
    // that wants both of its plates at the same moment is a gate one shadow
    // can never open, because one shadow is in exactly one place — the place
    // you were standing three seconds ago.
    testWithGame<LevelGame>(
      'and with one shadow the same run never opens the gate at all',
      () => LevelGame(
        levels: [
          levelFromJson(
            Levels.twoNotOne.toJson()..['delays'] = <double>[3],
          ),
        ],
        inputs: [ScriptedInput()],
      ),
      (game) async {
        await game.ready();
        expect(game.shadows, hasLength(1));

        final run = start(game)
          ..play(Levels.twoNotOne.solution, stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
        expect(
          game.doors.map((door) => door.openFraction),
          everyElement(lessThan(1)),
          reason: 'both open at once is the one thing it cannot do',
        );
      },
    );

    // The wrong idea, and the number the whole level is about: your two pasts
    // are four seconds apart and nothing you do changes that, so the walk
    // between the two plates has to fit inside four seconds. Step off the far
    // one, stop to look around, and by the time the near plate is pressed the
    // far shadow has been and gone.
    //
    // Note what is *not* the wrong idea: standing on a plate longer. That
    // widens the window, here as everywhere else in this game. What costs you
    // is the gap between leaving one and reaching the other.
    testWithGame<LevelGame>(
      'linger on the way between them and the two of you never overlap',
      build(Levels.twoNotOne),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(3.1),
            Move(1.8), // the same stand as the solution
            Move.right(0.8), // off the plate...
            Move(2.5), // ...and a look around on the way
            Move.right(1.7),
            Move(1.8),
            Move.right(1.3),
            Move(1.6),
            Move.right(1.6),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );

    // The real cost of a second shadow is not the buffer, it is telling them
    // apart: two pale cold figures of the same weight is noise, and the
    // question the player is actually asking is *which* past am I looking at.
    testWithGame<LevelGame>(
      "the older of the two is drawn fainter, on the mark's own ladder",
      build(Levels.twoNotOne),
      (game) async {
        await game.ready();
        start(game).play(const [Move(8.0)]);

        expect(game.shadows, hasLength(2));
        expect(game.shadows.map((s) => s.fade), pastFades.take(2));
        expect(
          game.shadows[1].opacity,
          lessThan(game.shadows[0].opacity),
          reason: 'the seven-second one has to read as the older one',
        );
        expect(game.shadows.every((s) => s.isActive), isTrue);
      },
    );
    testWithGame<LevelGame>(
      'the near plate on its own opens half a gate, which is a wall',
      build(Levels.twoNotOne),
      (game) async {
        await game.ready();
        final run = start(game)
          ..play(const [
            Move.left(0.8), // onto the near plate, the one you can see
            Move(2.0),
            Move.right(1.4), // and off to the gate with it
            Move(4.0),
            Move.right(1.6),
          ], stopWhenComplete: true);

        expect(run.finishedAt, isNull, reason: run.where);
      },
    );
  });

  // The rule every level in this project is held to, as a test rather than as
  // a paragraph: a level ships with a run that finishes it and a run that does
  // not. The second is the one that matters — the first draft of the first
  // level could be beaten by holding one arrow, and only a recording of that
  // idea failing said so.
  //
  // Both live in the level now, which means both travel in the JSON, which is
  // what lets the gate in front of a level from somewhere else replay them
  // through this same harness and take the level's word for nothing.
  group('every level comes with its own proof', () {
    test('nothing ships without both recordings', () {
      for (final level in [...Levels.campaign, Levels.lab]) {
        if (level.id == Levels.lab.id) {
          // The bench is not a level to be won and has nothing to record.
          expect(level.canBeChecked, isFalse);
          continue;
        }
        expect(level.canBeChecked, isTrue, reason: level.id);
        expect(
          level.solution,
          isNotEmpty,
          reason: '${level.id} has no recorded solution',
        );
        expect(
          level.wrongIdeas,
          isNotEmpty,
          reason: '${level.id} has no recorded wrong idea, which is the half '
              'that keeps it a puzzle',
        );
      }
    });

    for (final level in Levels.campaign) {
      for (final (i, idea) in level.wrongIdeas.indexed) {
        testWithGame<LevelGame>(
          '${level.id}: recorded wrong idea ${i + 1} does not finish it',
          build(level),
          (game) async {
            await game.ready();
            final run = start(game)..play(idea, stopWhenComplete: true);

            expect(run.finishedAt, isNull, reason: run.where);
          },
        );
      }
    }
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
        // Two shadows stack — stand on the near one's head and the far one
        // arrives there four seconds later — so a level with two of them has
        // one more step under every door.
        final floor = level.delays.length > 1
            ? Levels.minDoorHeightTwoShadows
            : Levels.minDoorHeight;
        for (final door in level.doors) {
          expect(
            door.closed.height,
            greaterThanOrEqualTo(floor),
            reason:
                '${level.id}: a body on a shadow at this door\'s foot reaches '
                '${reach.toStringAsFixed(0)} above its sill',
          );
        }
      }
      expect(
        Levels.minDoorHeightTwoShadows,
        greaterThan(reach + 96),
        reason: 'the two-shadow rule has to clear the extra body too',
      );
    });

    test('every level is winnable at a delay the panel can produce', () {
      for (final level in [...Levels.campaign, Levels.lab]) {
        // The nearest shadow is the one the bench's slider drives; the rest
        // keep the delays their level gave them, because the gap between two
        // shadows is the puzzle and a slider that closed it would delete the
        // level rather than tune it.
        expect(
          level.delaySeconds,
          inInclusiveRange(0.5, 6),
          reason: '${level.id} asks for a delay outside the slider',
        );
        expect(
          level.delays,
          everyElement(inInclusiveRange(0.5, 12)),
          reason: '${level.id} asks for a shadow nobody could keep track of',
        );
        expect(
          level.delays,
          orderedEquals([...level.delays]..sort()),
          reason: '${level.id} lists its shadows out of order, nearest first',
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
