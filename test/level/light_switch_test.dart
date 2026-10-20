// The light switch (`docs/phase-12-more.md` §2), on the bench.
//
// A light with a name can be switched off by a plate or a key that names it,
// "open" meaning dark, in the order a door is held: an inverted plate under a
// body keeps it lit, then a plate held or a key thrown puts it out. The first
// half of this file is the rule on levels built to show one thing each; the
// second is the three levels that use it, and the numbers they rest on.
import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/level/props.dart';

import 'run.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame Function() build(Level level) =>
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]);

  group('the rule', () {
    testWithGame<LevelGame>(
      'a plate in the dark puts the light out while it is held',
      build(_room()),
      (game) async {
        await game.ready();
        final lamp = game.lights.single;
        final run = Run(game)..walkTo(250);
        expect(lamp.isOn, isFalse, reason: run.where);

        run.walkTo(500);
        expect(lamp.isOn, isTrue, reason: 'nobody is holding it now');
      },
    );

    testWithGame<LevelGame>(
      'your past under a lit lamp presses nothing; put out, it does',
      build(_room()),
      (game) async {
        await game.ready();
        final gate = game.doors.single;
        // Stand on the plate under the lamp, then hold the switch while your
        // past arrives on it.
        final run = Run(game)
          ..walkTo(-350)
          ..hold(4);
        var widest = 0.0;
        run
          ..walkTo(250)
          ..hold(
            1.5,
            each: () {
              if (gate.openFraction > widest) widest = gate.openFraction;
            },
          );
        expect(widest, 1, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'and without the switch it holds nothing',
      build(_room()),
      (game) async {
        await game.ready();
        final gate = game.doors.single;
        var opened = false;
        Run(game)
          ..walkTo(-350)
          ..hold(1.5)
          ..walkTo(500)
          ..hold(
            3,
            each: () {
              if (gate.openFraction > 0) opened = true;
            },
          );
        expect(opened, isFalse);
      },
    );

    // The consequence that makes it a puzzle rather than a lever: you cannot
    // leave a plate for your past to turn its own lamp off with.
    testWithGame<LevelGame>(
      'a plate under its own lamp cannot switch it off',
      build(
        _room(
          plates: const [
            PlateSpec(area: Rect.fromLTRB(-400, 608, -300, 620), opens: 'lamp'),
          ],
        ),
      ),
      (game) async {
        await game.ready();
        final lamp = game.lights.single;
        final run = Run(game)
          ..walkTo(-350)
          ..hold(1.0);
        expect(lamp.isOn, isFalse, reason: 'your own weight counts');

        var outWhileYourPastWasThere = false;
        run
          ..walkTo(300)
          ..hold(
            5,
            each: () {
              final past = game.shadow;
              if (past.isActive && past.x < -280 && !lamp.isOn) {
                outWhileYourPastWasThere = true;
              }
            },
          );
        expect(outWhileYourPastWasThere, isFalse, reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'a key puts it out until your past comes back to it',
      build(
        _room(
          delay: 2,
          plates: const [],
          toggles: const [
            ToggleSpec(area: Rect.fromLTRB(200, 608, 300, 620), flips: 'lamp'),
          ],
        ),
      ),
      (game) async {
        await game.ready();
        final lamp = game.lights.single;
        final run = Run(game)..walkTo(250);
        final thrown = run.t;
        run.walkTo(500);
        expect(lamp.isOn, isFalse, reason: 'still out after you left it');

        run.waitUntil(thrown + 2 + 0.3);
        expect(lamp.isOn, isTrue, reason: 'your past threw it back');
      },
    );

    testWithGame<LevelGame>(
      'an inverted plate held keeps it lit, whatever else is held',
      build(
        _room(
          delay: 2,
          plates: const [
            PlateSpec(area: Rect.fromLTRB(-400, 608, -300, 620), opens: 'gate'),
            PlateSpec(area: Rect.fromLTRB(200, 608, 300, 620), opens: 'lamp'),
            PlateSpec(
              area: Rect.fromLTRB(400, 608, 500, 620),
              opens: 'lamp',
              inverts: true,
            ),
          ],
        ),
      ),
      (game) async {
        await game.ready();
        final lamp = game.lights.single;
        final run = Run(game)..walkTo(450);
        expect(lamp.isOn, isTrue);
        // Your past is still on the inverted plate while you stand on the
        // switch: lit. Then it steps off: out.
        run
          ..hold(2.5)
          ..walkTo(250)
          ..hold(0.3);
        expect(lamp.isOn, isTrue, reason: run.where);
        run.hold(2.5);
        expect(lamp.isOn, isFalse, reason: run.where);
      },
    );

    testWithGame<LevelGame>('starting again lights it again', build(_room()), (
      game,
    ) async {
      await game.ready();
      Run(game).walkTo(250);
      expect(game.lights.single.isOn, isFalse);
      game.reload();
      expect(game.lights.single.isOn, isTrue);
    });
  });

  group('as data', () {
    final level = _room();

    test('a light with no name is the bare rectangle every light was', () {
      final json = Levels.underTheLight.toJson();
      expect(json['lights'], everyElement(isA<List<Object?>>()));
      expect(Levels.underTheLight.requires, isNot(contains('light-switch')));
    });

    test('a named light writes its name and reads back the same', () {
      final json = jsonDecode(jsonEncode(level.toJson())) as Map;
      expect((json['lights'] as List).single, {
        'area': [-420, 200, -280, 620],
        'id': 'lamp',
      });
      expect(level.requires, contains('light-switch'));
      expect(levelFromJson(json).lights, level.lights);
    });

    test('promoted: the game plays it, and an older build refuses it', () {
      expect(Level.knownMechanics, contains('light-switch'));
      expect(Level.labMechanics, isNot(contains('light-switch')));
      expect(
        levelFromJson(jsonDecode(jsonEncode(level.toJson()))).id,
        level.id,
      );
      // What the name is for: a build from before it reads the level's
      // `requires` and refuses it, rather than keeping a lamp lit that the
      // level was drawn around putting out.
      final older = Level.knownMechanics.difference({'light-switch'});
      expect(
        () => levelFromJson(
          jsonDecode(jsonEncode(level.toJson())),
          accepts: older,
        ),
        throwsA(
          isA<LevelUnsupportedException>().having((e) => e.missing, 'missing', {
            'light-switch',
          }),
        ),
      );
    });

    test('the gate takes a level that uses it, on its numbers alone', () {
      expect(checkNumbers(Levels.youHoldTheDark), isEmpty);
    });

    test('a plate may name a light, but a light and a door not one name', () {
      final clash = _room(
        lights: const [
          LightSpec(Rect.fromLTRB(-420, 200, -280, 620), id: 'gate'),
        ],
      );
      expect(
        checkNumbers(clash).map((f) => '$f'),
        contains(contains('two things are called "gate"')),
      );
      expect(
        checkNumbers(level).map((f) => '$f'),
        isNot(contains(contains('not a door'))),
      );
    });

    test('renaming a light in the editor takes its switches with it', () {
      final doc = EditorDoc.fromLevel(level);
      final lamp = doc.pieces.firstWhere((p) => p.kind == PieceKind.light);
      doc.renameLight(lamp, 'stairwell');
      expect(doc.toLevel().lights.single.id, 'stairwell');
      expect(doc.toLevel().plates.map((p) => p.opens), contains('stairwell'));
      expect(doc.linkTargets, ['gate', 'stairwell']);

      // Unnamed, it is a light nothing switches, and the switch points at
      // nothing — which the check says, rather than the light quietly
      // staying on.
      doc.renameLight(lamp, '');
      expect(doc.toLevel().lights.single.id, isNull);
      expect(
        checkNumbers(doc.toLevel()).map((f) => '$f'),
        contains(contains('which is not a door, a light or a basket')),
      );
    });

    test('an inverted plate under its own lamp is refused, not flickered', () {
      final flicker = _room(
        plates: const [
          PlateSpec(area: Rect.fromLTRB(-400, 608, -300, 620), opens: 'gate'),
          PlateSpec(area: Rect.fromLTRB(200, 608, 300, 620), opens: 'lamp'),
          // Under the lamp, keeping it lit.
          PlateSpec(
            area: Rect.fromLTRB(-410, 608, -350, 620),
            opens: 'lamp',
            inverts: true,
          ),
        ],
      );
      expect(
        checkNumbers(flicker).map((f) => '$f'),
        contains(contains('on and off every frame')),
      );
      // The same plate out in the dark is a rule, not a bug.
      final fine = _room(
        plates: const [
          PlateSpec(area: Rect.fromLTRB(-400, 608, -300, 620), opens: 'gate'),
          PlateSpec(area: Rect.fromLTRB(200, 608, 300, 620), opens: 'lamp'),
          PlateSpec(
            area: Rect.fromLTRB(400, 608, 500, 620),
            opens: 'lamp',
            inverts: true,
          ),
        ],
      );
      expect(
        checkNumbers(fine).map((f) => '$f'),
        isNot(contains(contains('every frame'))),
      );
    });

    test('the editor keeps the name through opening and saving', () {
      for (final level in [level, ...Levels.bench]) {
        expect(EditorDoc.fromLevel(level).toLevel().lights, level.lights);
      }
    });
  });

  group('the bench levels', () {
    final levels = [
      Levels.youHoldTheDark,
      Levels.yourPastsDark,
      Levels.oneHoldsTheDark,
      Levels.theThirdFlip,
      Levels.allOfItInTheDark,
    ];

    for (final level in levels) {
      testWithGame<LevelGame>(
        '${level.id}: solved, and nothing cheap or wrong solves it',
        build(level),
        (game) async {
          await game.ready();
          final source = game.input.sources.first as ScriptedInput;
          double? play(List<Move> moves) {
            game.reload();
            return (Playthrough(
              game,
              source,
            )..play(moves, stopWhenComplete: true)).finishedAt;
          }

          expect(level.requires, contains('light-switch'));
          expect(level.canBeChecked, isTrue);
          expect(play(level.solution), isNotNull);
          for (final (i, idea) in level.wrongIdeas.indexed) {
            expect(play(idea), isNull, reason: 'wrong idea ${i + 1}');
          }
          for (final MapEntry(key: name, value: run) in cheapRuns(
            level,
          ).entries) {
            expect(play(run), isNull, reason: name);
          }
        },
      );
    }

    // You hold the dark: the gate's grace starts when your past steps off
    // the plate, so it has to outlast the switch you are still standing on
    // plus the walk. Four seconds covers a short press held a while, which is
    // the version somebody watching the gate will play.
    for (final (plate, held) in const [(1.0, 1.0), (1.0, 3.0), (2.5, 1.5)]) {
      testWithGame<LevelGame>(
        'you hold the dark: ${plate}s on the plate, ${held}s on the switch',
        build(Levels.youHoldTheDark),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..walkTo(-450)
            ..hold(plate)
            ..walkTo(40)
            ..hold(0.55, axis: 1, jump: true)
            ..walkTo(150)
            ..hold(held)
            ..hold(5, axis: 1);
          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }

    // Your past's dark: out of the lamp, a step is too far from the shelf by
    // any climb (searched); under it, it reaches — and only with the lamp out.
    for (final x in const <double>[150, 180, 197]) {
      testWithGame<LevelGame>(
        'your past\'s dark: a step in the dark at $x does not reach the shelf',
        build(Levels.yourPastsDark),
        (game) async {
          await game.ready();
          expect(highestClimbFrom(game, x, delay: 5), greaterThan(430));
        },
      );
    }

    for (final x in const <double>[260, 336]) {
      testWithGame<LevelGame>(
        'your past\'s dark: a step at $x, then the key, reaches the shelf',
        build(Levels.yourPastsDark),
        (game) async {
          await game.ready();
          final run = Run(game)..walkTo(x);
          final ducked = run.t;
          run
            ..hold(1.5, crouch: true)
            ..walkTo(170)
            ..hold(0.55, axis: -1, jump: true)
            ..walkTo(50)
            ..hold(0.2)
            ..walkTo(x - 110)
            ..waitUntil(ducked + 5.1)
            ..climb(1)
            ..hold(4, axis: 1);
          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }

    testWithGame<LevelGame>(
      'your past\'s dark: under the lit lamp, no climb reaches',
      build(Levels.yourPastsDark),
      (game) async {
        await game.ready();
        expect(highestClimbFrom(game, 336, delay: 5), greaterThan(430));
      },
    );

    // One holds the dark: the window is how long you stood on the plate, so
    // standing longer is the lever — and holding the switch yourself too long
    // is the one way to miss it.
    for (final (plate, held, works) in const [
      (1.5, 1.6, true),
      (2.0, 1.6, true),
      (3.0, 2.5, true),
      (2.0, 4.0, false),
    ]) {
      testWithGame<LevelGame>(
        'one holds the dark: ${plate}s on the plate, ${held}s on the switch',
        build(Levels.oneHoldsTheDark),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..walkTo(-400)
            ..hold(plate)
            ..walkTo(-225)
            ..hold(0.55, axis: 1, jump: true)
            ..walkTo(-100)
            ..hold(held)
            ..hold(5, axis: 1);
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }
  });

  group('the third flip', () {
    final level = Levels.theThirdFlip;

    testWithGame<LevelGame>(
      'one touch: out, lit by the near past, out for good by the far',
      build(level),
      (game) async {
        await game.ready();
        final lamp = game.lights.single;
        // Off it again at once, as the level is played: a key notices a
        // past *arriving*, so a near past still standing on it when the far
        // one arrives is no new arrival — and no third flip.
        final run = Run(game)..play(level.solution.take(2));
        final thrown = run.t;
        expect(lamp.isOn, isFalse, reason: 'you threw it');
        run
          ..play(level.solution.skip(2).take(2))
          ..waitUntil(thrown + 3);
        expect(lamp.isOn, isTrue, reason: 'the near past threw it back');
        run.waitUntil(thrown + 5.5);
        expect(lamp.isOn, isFalse, reason: 'the far past threw it again');
        run.waitUntil(thrown + 20);
        expect(lamp.isOn, isFalse, reason: 'and nobody comes after the far');
      },
    );

    // The hole the wide lamp closes: a stair in the dark beside it, with no
    // key at all. Searched, and short of the roof by a body.
    for (final x in const <double>[300, 330, 347]) {
      testWithGame<LevelGame>(
        'a stair in the dark at $x does not reach the roof',
        build(level),
        (game) async {
          await game.ready();
          expect(highestStairClimbFrom(game, x), greaterThan(390));
        },
      );
    }
  });

  group('all of it in the dark', () {
    final level = Levels.allOfItInTheDark;

    // Through the gate without the key — the first wrong idea's way — and a
    // stair in the dark beside the roof's lamp: short, as in the level before.
    for (final x in const <double>[400, 430, 447]) {
      testWithGame<LevelGame>(
        'a stair in the dark at $x does not reach the roof',
        build(level),
        (game) async {
          await game.ready();
          expect(
            highestStairClimbFrom(
              game,
              x,
              first: level.wrongIdeas.first.take(7).toList(),
            ),
            greaterThan(390),
          );
        },
      );
    }

    // The first room's window is how long you stood on the plate; a touch on
    // the balcony is a press, but a walk under it is not.
    for (final (plate, held, through) in const [
      (2.0, 1.0, true),
      (3.0, 1.6, true),
      (2.0, 3.5, false),
    ]) {
      testWithGame<LevelGame>(
        'the first room: ${plate}s on the plate, ${held}s on the switch',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(3))
            ..walkTo(-616)
            ..hold(0.55, axis: 1, jump: true)
            ..walkTo(-515)
            ..hold(plate)
            ..walkTo(-410)
            ..hold(0.55, axis: 1, jump: true)
            ..walkTo(-280)
            ..hold(held)
            ..hold(3, axis: 1);
          expect(game.player.x > 60, through, reason: run.where);
        },
      );
    }

    testWithGame<LevelGame>(
      'walking under the plate\'s balcony presses nothing',
      build(level),
      (game) async {
        await game.ready();
        var opened = false;
        Run(game)
          ..play(level.solution.take(3))
          ..walkTo(-616)
          ..hold(
            1.5,
            axis: 1,
            each: () {
              if (game.doors.single.openFraction > 0) opened = true;
            },
          );
        expect(opened, isFalse);
      },
    );
  });

  group('the last six seconds', () {
    final level = Levels.theLastSixSeconds;

    // Up the step and onto the shelf the moment the step is there, after
    // whatever the run before it was.
    void climbWhenThere(Run run, double ducked) => run
      ..walkTo(330)
      ..waitUntil(ducked + level.delaySeconds + 0.1)
      ..hold(0.5, jump: true)
      ..hold(0.9, axis: 1, jump: true)
      ..hold(5, axis: 1);

    // The budget is the six seconds before the key. The walk from the step
    // to the key and back spends a little over four of them, and what is
    // left is how long you can stop to think between the step and the key.
    for (final (pause, works) in const [
      (0.0, true),
      (0.6, true),
      (1.2, true),
      (2.5, false),
    ]) {
      testWithGame<LevelGame>(
        'stopping ${pause}s between the step and the key '
        '${works ? 'still fits' : 'does not fit'}',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)..play(level.solution.take(6));
          final ducked = run.t;
          run
            ..play(level.solution.skip(6).take(1))
            ..hold(pause)
            ..play(level.solution.skip(7).take(4));
          climbWhenThere(run, ducked);
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // Each wrong idea fails at the step, for the reason it says — so each
    // has to have thrown the key, and the plate held the gate for a moment.
    for (final (i, idea) in level.wrongIdeas.indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} throws the key and stands on the plate',
        build(level),
        (game) async {
          await game.ready();
          var dark = false;
          var held = false;
          final run = Run(game);
          for (final move in idea) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!game.lights.single.isOn) dark = true;
                if (game.doors.single.openFraction > 0) held = true;
              },
            );
          }
          expect(dark, isTrue, reason: run.where);
          expect(held, isTrue, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // The other order of the two, the step first, fits too: the lesson is
    // the key last, not which of the others comes first.
    testWithGame<LevelGame>(
      'the step and then the plate, then the key, fits too',
      build(level),
      (game) async {
        await game.ready();
        final run = Run(game)..walkTo(330);
        final ducked = run.t;
        run
          ..hold(1.0, crouch: true)
          ..walkTo(235)
          ..hold(0.55, axis: -1, jump: true)
          ..walkTo(118)
          ..hold(0.3)
          ..walkTo(65)
          ..hold(0.2)
          ..walkTo(65)
          ..hold(0.55, axis: -1, jump: true)
          ..hold(0.2);
        expect(game.lights.single.isOn, isFalse, reason: run.where);
        climbWhenThere(run, ducked);
        expect(run.finishedAt, isNotNull, reason: run.where);
      },
    );

    // The plate's balcony is as high as the step, and the shelf is the
    // whole lamp away from it: no running jump off it gets there.
    testWithGame<LevelGame>(
      'the shelf is out of reach from the plate\'s balcony',
      build(level),
      (game) async {
        await game.ready();
        for (var runUp = 0.0; runUp <= 0.6; runUp += Playthrough.dt * 2) {
          game.reload();
          final run = Run(game)
            ..play(level.solution.take(4))
            ..walkTo(105)
            ..hold(runUp, axis: 1)
            ..hold(1.2, axis: 1, jump: true);
          expect(
            game.player.y,
            isNot(430),
            reason: 'run-up $runUp: ${run.where}',
          );
        }
      },
    );

    // And a past ducked on the plate is a step and a press at once, nearly
    // as high as the shelf. With the plate at the balcony's far end it is
    // short however it is run off, which is what keeps the two things two.
    // Ducks at [x] on the plate's balcony, throws the key, comes back up
    // onto that step and runs off it to the right, [frames] frames before
    // jumping: whether that lands on the shelf.
    Future<bool> runOffStep(LevelGame game, double x, int frames) async {
      game.reload();
      final run = Run(game)
        ..walkTo(235)
        ..hold(0.55, axis: -1, jump: true)
        ..walkTo(x);
      final ducked = run.t;
      run
        ..hold(2.0, crouch: true)
        ..walkTo(65)
        ..hold(0.2)
        ..walkTo(65)
        ..hold(0.55, axis: -1, jump: true)
        ..hold(0.2)
        ..walkTo(235)
        ..hold(0.2)
        ..walkTo(235)
        ..hold(0.55, axis: -1, jump: true)
        ..walkTo(x - 48)
        ..waitUntil(ducked + level.delaySeconds + 0.2)
        ..hold(0.15, axis: 1, jump: true) // up onto it
        ..hold(0.6)
        ..walkTo(x - 25);
      expect(game.player.y, lessThan(450), reason: 'on it: ${run.where}');
      run
        ..hold(frames * Playthrough.dt, axis: 1)
        ..hold(1.0, axis: 1, jump: true)
        ..hold(1.5, axis: 1);
      return game.player.y == 430;
    }

    // And a past ducked on the plate is a step and a press at once, nearly
    // as high as the shelf. With the plate at the balcony's far end it is
    // short however it is run off, which is what keeps the two things two.
    testWithGame<LevelGame>(
      'a step on the plate is out of reach of the shelf',
      build(level),
      (game) async {
        await game.ready();
        for (final x in const <double>[140, 146]) {
          for (var frames = 0; frames <= 30; frames++) {
            expect(
              await runOffStep(game, x, frames),
              isFalse,
              reason: 'at $x, $frames frames',
            );
          }
        }
      },
    );

    // The control that says the search above can find a way: a step at the
    // balcony's other end, off the plate, does reach.
    testWithGame<LevelGame>(
      'a step at the balcony\'s other end does reach the shelf',
      build(level),
      (game) async {
        await game.ready();
        var reached = false;
        for (var frames = 0; frames <= 30 && !reached; frames++) {
          reached = await runOffStep(game, 190, frames);
        }
        expect(reached, isTrue);
      },
    );
  });

  group('a chain of dark', () {
    final level = Levels.aChainOfDark;

    LightZone lamp(LevelGame game, String id) =>
        game.lights.singleWhere((light) => light.spec.id == id);

    // What each wrong idea did, watched frame by frame, so each fails for the
    // reason its comment gives and not by missing a balcony.
    for (final (i, (switchOut, plateOut, opened)) in const [
      (true, true, true), // yours first; the gate opens, but not for you
      (false, true, false), // never on your own plate
      (false, true, true), // the gate opens, and you are too far
    ].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} stands where it says and does not finish',
        build(level),
        (game) async {
          await game.ready();
          var sawSwitchOut = false;
          var sawPlateOut = false;
          var sawOpen = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!lamp(game, 'switch-lamp').isOn) sawSwitchOut = true;
                if (!lamp(game, 'plate-lamp').isOn) sawPlateOut = true;
                // Open by a past while you are away over by the switch.
                if (game.doors.single.openFraction > 0.5 &&
                    game.player.x < -400) {
                  sawOpen = true;
                }
              },
            );
          }
          expect(sawSwitchOut, switchOut, reason: run.where);
          expect(sawPlateOut, plateOut, reason: run.where);
          expect(sawOpen, opened, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // The far past leaves the switch six seconds after you did, and by then
    // you have to be on your own plate: the walk there takes a little over
    // four, and the rest is how long you can stop on the way.
    for (final (pause, works) in const [
      (0.0, true),
      (0.8, true),
      (1.5, true),
      (2.5, false),
    ]) {
      testWithGame<LevelGame>(
        'stopping ${pause}s between the switch and the plate '
        '${works ? 'still chains' : 'breaks the chain'}',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(5))
            ..hold(pause)
            ..play(level.solution.skip(5));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }
  });

  group('one holds the dark, one is the step', () {
    final level = Levels.oneIsTheStep;

    // The near past's step is there for as long as you ducked, so the duck
    // is how long you can stop before climbing it — as long as the far past
    // is still on the switch, which is how long you stood there.
    for (final (duck, pause, works) in const [
      (1.0, 0.0, true),
      (2.0, 1.0, true),
      (3.0, 1.2, true),
      (1.0, 1.0, false),
    ]) {
      testWithGame<LevelGame>(
        'a ${duck}s duck and a ${pause}s stop before climbing '
        '${works ? 'still' : 'no longer'} reaches the shelf',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)..play(level.solution.take(6));
          final ducked = run.t;
          run
            ..hold(duck, crouch: true)
            ..hold(0.25, axis: -1)
            ..waitUntil(ducked + 2.1 + pause)
            ..play(level.solution.skip(9));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    for (final (i, darkens) in const [true, false, true].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} ${darkens ? 'puts the lamp out' : 'never does'} '
        'and does not finish',
        build(level),
        (game) async {
          await game.ready();
          var dark = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!game.lights.single.isOn) dark = true;
              },
            );
          }
          expect(dark, darkens, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // A stair of both pasts (`stairOfYourself`'s way, a second later for the
    // far past at six) anywhere in the dark: on the floor beside the lamp, or
    // on the switch's balcony, 114 higher. Searched, every shuffle; each one
    // builds — the feet get well above a single step's — and none lands on
    // the shelf.
    for (final (x, balcony) in const [
      (125.0, false),
      (147.0, false),
      (60.0, true),
      (110.0, true),
    ]) {
      testWithGame<LevelGame>(
        'a stair in the dark at $x${balcony ? ' on the balcony' : ''} '
        'does not reach the shelf',
        build(level),
        (game) async {
          await game.ready();
          var highest = double.infinity;
          var onShelf = false;
          for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
            game.reload();
            final run = Run(game);
            if (balcony) run.play(level.solution.take(3));
            run.walkTo(x);
            void hold(
              double seconds, {
              double axis = 0,
              bool jump = false,
              bool crouch = false,
            }) => run.hold(
              seconds,
              axis: axis,
              jump: jump,
              crouch: crouch,
              each: () {
                final player = game.player;
                if (player.y < highest) highest = player.y;
                if (player.isGrounded && player.y <= 431 && player.x > 370) {
                  onShelf = true;
                }
              },
            );
            hold(4.5, crouch: true); // the bottom step
            hold(1.6);
            hold(0.5, jump: true); // onto it
            hold(1.0, crouch: true); // the second step
            hold(1.0);
            hold(0.7, jump: true); // onto that
            hold(shuffle * Playthrough.dt, axis: 1);
            hold(1.0, axis: 1, jump: true);
            hold(0.6, axis: 1);
          }
          expect(highest, lessThan(balcony ? 260 : 370), reason: 'it builds');
          expect(onShelf, isFalse);
        },
      );
    }
  });

  group('your step is the switch', () {
    final level = Levels.yourStepIsTheSwitch;

    // The near past is the step and the switch at once, for as long as you
    // ducked: the duck is how long you can stop before climbing it.
    for (final (duck, pause, works) in const [
      (1.5, 0.0, true),
      (2.5, 1.0, true),
      (3.0, 1.5, true),
      (1.5, 1.2, false),
    ]) {
      testWithGame<LevelGame>(
        'a ${duck}s duck on the switch and a ${pause}s stop '
        '${works ? 'still' : 'no longer'} gets through',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)..play(level.solution.take(8));
          final ducked = run.t;
          run
            ..hold(duck, crouch: true)
            ..hold(0.25, axis: -1)
            ..waitUntil(ducked + 2.1 + pause)
            ..play(level.solution.skip(11));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // What each wrong idea did with the lamp and the gate, frame by frame.
    for (final (i, (dark, opened, onLedge)) in const [
      (true, true, false), // you hold the switch: the gate opens, no way up
      (true, true, false), // the far past is the step, too far from the plate
      (true, false, true), // up on the ledge, and nobody on the plate
    ].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} gets where it says and does not finish',
        build(level),
        (game) async {
          await game.ready();
          var sawDark = false;
          var sawOpen = false;
          var sawLedge = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!game.lights.single.isOn) sawDark = true;
                if (game.doors.single.openFraction > 0.5) sawOpen = true;
                if (game.player.isGrounded && game.player.y <= 321) {
                  sawLedge = true;
                }
              },
            );
          }
          expect(sawDark, dark, reason: run.where);
          expect(sawOpen, opened, reason: run.where);
          expect(sawLedge, onLedge, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // A stair of both pasts on the open floor beside the switch's balcony:
    // the ledge is 300 up, and a stair's reach is 274. Searched; each one
    // builds, and none gets onto the ledge.
    for (final x in const <double>[80, 120]) {
      testWithGame<LevelGame>(
        'a stair in the dark at $x does not reach the ledge',
        build(level),
        (game) async {
          await game.ready();
          var highest = double.infinity;
          var onLedge = false;
          for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
            game.reload();
            final run = Run(game)..walkTo(x);
            void hold(
              double seconds, {
              double axis = 0,
              bool jump = false,
              bool crouch = false,
            }) => run.hold(
              seconds,
              axis: axis,
              jump: jump,
              crouch: crouch,
              each: () {
                final player = game.player;
                if (player.y < highest) highest = player.y;
                if (player.isGrounded && player.y <= 321) onLedge = true;
              },
            );
            hold(4.5, crouch: true);
            hold(1.6);
            hold(0.5, jump: true);
            hold(1.0, crouch: true);
            hold(1.0);
            hold(0.7, jump: true);
            hold(shuffle * Playthrough.dt, axis: 1);
            hold(1.0, axis: 1, jump: true);
            hold(0.6, axis: 1);
          }
          expect(highest, lessThan(370), reason: 'it builds');
          expect(onLedge, isFalse);
        },
      );
    }
  });

  group('the far one works twice', () {
    final level = Levels.theFarOneTwice;

    // The far past is on the switch for as long as you stood there, six
    // seconds on — and has to be when you climb, a little under five after
    // you leave it. So a stand too short is a far past still on its way.
    for (final (stand, works) in const [
      (0.45, false),
      (1.0, false),
      (1.5, true),
      (2.5, true),
      (3.5, true),
    ]) {
      testWithGame<LevelGame>(
        '${stand}s on the next room\'s switch '
        '${works ? 'holds' : 'does not hold'} its dark for the climb',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(9))
            ..hold(stand)
            ..play(level.solution.skip(10));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // The near past's step is there for as long as you ducked.
    for (final (duck, pause, works) in const [
      (1.0, 0.0, true),
      (2.0, 0.8, true),
      (1.0, 0.8, false),
    ]) {
      testWithGame<LevelGame>(
        'a ${duck}s duck and a ${pause}s stop '
        '${works ? 'still' : 'no longer'} climbs',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)..play(level.solution.take(12));
          final ducked = run.t;
          run
            ..hold(duck, crouch: true)
            ..hold(0.25, axis: -1)
            ..waitUntil(ducked + 2.1 + pause)
            ..play(level.solution.skip(15));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // Each wrong idea gets through the gate to the step — it fails at the
    // climb, for its own reason — and puts the lamp out or never does.
    for (final (i, darkens) in const [true, false, true].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} reaches the step and does not finish',
        build(level),
        (game) async {
          await game.ready();
          var dark = false;
          var through = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!game.lights.single.isOn) dark = true;
                if (game.player.x > 250) through = true;
              },
            );
          }
          expect(dark, darkens, reason: run.where);
          expect(through, isTrue, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // A stair of both pasts — on the switch's balcony beside the gate, or on
    // the floor between the gate and the lamp. Searched; each builds, none
    // gets over the shut gate or onto the shelf.
    for (final (x, balcony) in const [
      (-40.0, true),
      (-25.0, true),
      (55.0, false),
      (75.0, false),
    ]) {
      testWithGame<LevelGame>(
        'a stair at $x${balcony ? ' on the switch\'s balcony' : ''} '
        'gets over nothing',
        build(level),
        (game) async {
          await game.ready();
          var highest = double.infinity;
          var over = false;
          for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
            game.reload();
            final run = Run(game);
            // To the far side of the gate, through it, for the floor ones.
            if (!balcony) run.play(level.solution.take(11));
            if (balcony) {
              run
                ..walkTo(-155)
                ..hold(0.2)
                ..walkTo(-155)
                ..hold(0.55, axis: 1, jump: true);
            }
            run.walkTo(x);
            final shut = balcony;
            void hold(
              double seconds, {
              double axis = 0,
              bool jump = false,
              bool crouch = false,
            }) => run.hold(
              seconds,
              axis: axis,
              jump: jump,
              crouch: crouch,
              each: () {
                final player = game.player;
                if (player.y < highest) highest = player.y;
                final onShelf =
                    player.isGrounded && player.y <= 431 && player.x > 320;
                final pastGate =
                    shut &&
                    player.x > 40 &&
                    game.doors.single.openFraction < 0.05;
                if (onShelf || pastGate) over = true;
              },
            );
            hold(4.5, crouch: true);
            hold(1.6);
            hold(0.5, jump: true);
            hold(1.0, crouch: true);
            hold(1.0);
            hold(0.7, jump: true);
            hold(shuffle * Playthrough.dt, axis: 1);
            hold(1.0, axis: 1, jump: true);
            hold(0.6, axis: 1);
          }
          expect(highest, lessThan(balcony ? 260 : 370), reason: 'it builds');
          expect(over, isFalse);
        },
      );
    }
  });

  group('the key behind you', () {
    final level = Levels.theKeyBehindYou;

    // Two clocks after the duck. The step is there six seconds on, for as
    // long as you ducked; and the gate stays open three and a half seconds
    // after your past leaves the plate — so how long you stood there is how
    // long you can stop on the way back for the key.
    for (final (stand, pause, works) in const [
      (4.0, 0.0, true),
      (4.0, 1.0, true),
      (3.1, 1.0, false), // the gate shuts before you are back through
      (4.0, 2.2, false), // the step is gone before you are back
    ]) {
      testWithGame<LevelGame>(
        '${stand}s on the plate and a ${pause}s stop after the duck '
        '${works ? 'still' : 'no longer'} gets up',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(3))
            ..hold(stand)
            ..play(level.solution.skip(4).take(4));
          final ducked = run.t;
          run
            ..play(level.solution.skip(8).take(1))
            ..hold(pause)
            ..play(level.solution.skip(9).take(5))
            ..waitUntil(ducked + level.delaySeconds + 0.1)
            ..play(level.solution.skip(15));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // Each wrong idea gets into the second room; one puts the lamp out too
    // early, one is shut in before it can, one never does.
    for (final (i, darkens) in const [true, false, false].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} gets through the gate and does not finish',
        build(level),
        (game) async {
          await game.ready();
          var dark = false;
          var through = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!game.lights.single.isOn) dark = true;
                if (game.player.x > 250) through = true;
              },
            );
          }
          expect(dark, darkens, reason: run.where);
          expect(through, isTrue, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    testWithGame<LevelGame>(
      'a short stand on the plate shuts you in with the step',
      build(level),
      (game) async {
        await game.ready();
        final run = Run(game)..play(level.wrongIdeas[1]);
        expect(game.player.x, greaterThan(26), reason: run.where);
        expect(game.doors.single.openFraction, 0, reason: run.where);
      },
    );
  });

  group('a chain through the gate', () {
    final level = Levels.aChainThroughTheGate;

    LightZone lamp(LevelGame game, String id) =>
        game.lights.singleWhere((light) => light.spec.id == id);

    // What each wrong idea did with the two lamps, frame by frame; each gets
    // into the second room and fails at the last gate.
    for (final (i, (switchOut, plateOut)) in const [
      (true, false), // yours, but nobody on the switch back there
      (true, true), // both, but the far past on the switch too early
      (false, true), // the switch, but never yours
    ].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} gets through the first gate and no further',
        build(level),
        (game) async {
          await game.ready();
          var sawSwitchOut = false;
          var sawPlateOut = false;
          var through = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!lamp(game, 'switch-lamp').isOn) sawSwitchOut = true;
                if (!lamp(game, 'plate-lamp').isOn) sawPlateOut = true;
                if (game.player.x > 100) through = true;
              },
            );
          }
          expect(sawSwitchOut, switchOut, reason: run.where);
          expect(sawPlateOut, plateOut, reason: run.where);
          expect(through, isTrue, reason: run.where);
          expect(game.player.x, lessThan(800), reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // Where a stop costs: before the first gate it is the gate's grace,
    // after it the far past's time on the switch. A second and a half fits
    // either side; two and a half does not.
    for (final (after, pause, works) in const [
      (5, 1.5, true),
      (12, 1.5, true),
      (5, 2.5, false),
      (12, 2.5, false),
    ]) {
      testWithGame<LevelGame>(
        'a ${pause}s stop ${after < 10 ? 'before' : 'after'} the first gate '
        '${works ? 'still chains' : 'breaks the chain'}',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(after))
            ..hold(pause)
            ..play(level.solution.skip(after));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // A stair of both pasts beside each gate, and on your own balcony:
    // searched, each builds, and none gets past a shut gate.
    for (final (x, prefix, door) in const [
      // The nearest dark floor to the first gate: the switch's lamp leaves
      // no room for a body between it and the gate.
      (-250.0, 0, 0),
      (400.0, 19, 1), // on your own balcony
      (760.0, 13, 1), // on the floor against the last gate
    ]) {
      testWithGame<LevelGame>(
        'a stair at $x gets over no shut gate',
        build(level),
        (game) async {
          await game.ready();
          final gate = level.doors[door].closed;
          var highest = double.infinity;
          var over = false;
          for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
            game.reload();
            final run = Run(game)
              ..play(level.solution.take(prefix))
              ..walkTo(x);
            void hold(
              double seconds, {
              double axis = 0,
              bool jump = false,
              bool crouch = false,
            }) => run.hold(
              seconds,
              axis: axis,
              jump: jump,
              crouch: crouch,
              each: () {
                final player = game.player;
                if (player.y < highest) highest = player.y;
                if (player.x > gate.right + 22 &&
                    game.doors[door].openFraction < 0.05) {
                  over = true;
                }
              },
            );
            hold(4.5, crouch: true);
            hold(1.6);
            hold(0.5, jump: true);
            hold(1.0, crouch: true);
            hold(1.0);
            hold(0.7, jump: true);
            hold(shuffle * Playthrough.dt, axis: 1);
            hold(1.0, axis: 1, jump: true);
            hold(0.6, axis: 1);
          }
          expect(highest, lessThan(x == 400 ? 260 : 370), reason: 'it builds');
          expect(over, isFalse);
        },
      );
    }
  });

  group('you hold the last', () {
    final level = Levels.youHoldTheLast;

    // The switch by the first gate: the far past has to be on it when you
    // climb, a little under five seconds after you leave it.
    for (final (stand, works) in const [
      (0.45, false),
      (1.5, true),
      (3.0, true),
    ]) {
      testWithGame<LevelGame>(
        '${stand}s on the switch by the gate '
        '${works ? 'holds' : 'does not hold'} the dark for the climb',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(9))
            ..hold(stand)
            ..play(level.solution.skip(10));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // The near past's step is there for as long as you ducked.
    for (final (duck, pause, works) in const [
      (1.0, 0.0, true),
      (2.0, 0.8, true),
      (1.0, 0.8, false),
    ]) {
      testWithGame<LevelGame>(
        'a ${duck}s duck and a ${pause}s stop '
        '${works ? 'still' : 'no longer'} climbs',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)..play(level.solution.take(14));
          final ducked = run.t;
          run
            ..hold(duck, crouch: true)
            ..hold(0.25, axis: -1)
            ..waitUntil(ducked + 2.1 + pause)
            ..play(level.solution.skip(17));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // Two get up and find the last gate shut when they get to it — it only
    // ever opened under their own weight on its plate — and one never gets
    // up at all.
    for (final (i, up) in const [true, true, false].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} ${up ? 'gets up to a shut gate' : 'never gets up'}',
        build(level),
        (game) async {
          await game.ready();
          var onShelf = false;
          var openedForUs = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                final player = game.player;
                if (player.isGrounded && player.y <= 431 && player.x > 330) {
                  onShelf = true;
                }
                if (player.x > 700 && game.doors.last.openFraction > 0.5) {
                  openedForUs = true;
                }
              },
            );
          }
          expect(onShelf, up, reason: run.where);
          expect(openedForUs, isFalse, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // A stair of both pasts by each gate and below the shelf: searched, each
    // builds, none gets past a shut gate or onto the shelf from the floor.
    for (final (x, prefix, door) in const [
      (-40.0, 0, 0), // on the switch's balcony, by the first gate
      (50.0, 13, -1), // on the floor in the dark, short of the lamp
      (700.0, 20, 1), // on the shelf, by the last gate
    ]) {
      testWithGame<LevelGame>('a stair at $x gets over nothing', build(level), (
        game,
      ) async {
        await game.ready();
        var highest = double.infinity;
        var over = false;
        for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
          game.reload();
          final run = Run(game)..play(level.solution.take(prefix));
          if (prefix == 0) {
            run
              ..walkTo(-155)
              ..hold(0.2)
              ..walkTo(-155)
              ..hold(0.55, axis: 1, jump: true);
          }
          run.walkTo(x);
          final floor = game.player.y;
          void hold(
            double seconds, {
            double axis = 0,
            bool jump = false,
            bool crouch = false,
          }) => run.hold(
            seconds,
            axis: axis,
            jump: jump,
            crouch: crouch,
            each: () {
              final player = game.player;
              if (player.y < highest) highest = player.y;
              if (door == -1) {
                if (player.isGrounded && player.y <= 431 && player.x > 330) {
                  over = true;
                }
              } else {
                final gate = level.doors[door].closed;
                if (player.x > gate.right + 22 &&
                    game.doors[door].openFraction < 0.05) {
                  over = true;
                }
              }
            },
          );
          hold(4.5, crouch: true);
          hold(1.6);
          hold(0.5, jump: true);
          hold(1.0, crouch: true);
          hold(1.0);
          hold(0.7, jump: true);
          hold(shuffle * Playthrough.dt, axis: 1);
          hold(1.0, axis: 1, jump: true);
          hold(0.6, axis: 1);
          expect(floor - highest, greaterThan(250), reason: 'it builds');
        }
        expect(over, isFalse);
      });
    }
  });

  group('the chain\'s key', () {
    final level = Levels.theChainsKey;

    LightZone lamp(LevelGame game, String id) =>
        game.lights.singleWhere((light) => light.spec.id == id);

    testWithGame<LevelGame>(
      'the key puts the switch\'s lamp out, on, and out for good',
      build(level),
      (game) async {
        await game.ready();
        final switchLamp = lamp(game, 'switch-lamp');
        double? thrown;
        final run = Run(game);
        for (final move in level.solution.take(5)) {
          run.hold(
            move.seconds,
            axis: move.axis,
            jump: move.jump,
            crouch: move.crouch,
            each: () {
              if (!switchLamp.isOn) thrown ??= run.t;
            },
          );
        }
        expect(thrown, isNotNull, reason: 'you threw it');
        run.waitUntil(thrown! + 3);
        expect(switchLamp.isOn, isTrue, reason: 'the near past threw it back');
        run.waitUntil(thrown! + 7);
        expect(switchLamp.isOn, isFalse, reason: 'the far past, for good');
        run.waitUntil(thrown! + 25);
        expect(switchLamp.isOn, isFalse);
      },
    );

    // The far past's dark on the plate runs from the plate to six seconds
    // after it; the near past is on the switch only as long as you were.
    // So a stop fits before the switch, and not at the gate.
    for (final (after, pause, works) in const [
      (10, 1.5, true), // off the plate, before the switch
      (14, 0.4, true), // a moment at the gate
      (15, 1.0, false), // a second at the gate: the near past has left
    ]) {
      testWithGame<LevelGame>(
        'a ${pause}s stop after move $after '
        '${works ? 'still' : 'no longer'} gets through',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(after))
            ..hold(pause)
            ..play(level.solution.skip(after));
          expect(run.finishedAt, works ? isNotNull : isNull, reason: run.where);
        },
      );
    }

    // Each gets the gate open while it stands on the switch itself — the
    // far past is on the plate then — and finds it shut when it gets there.
    for (final (i, keyThrown) in const [
      false, // no key: the switch's lamp never goes out
      true, // the key after the plate: the dark comes back too late
      true, // held yourself, long: the far past is off the plate by then
    ].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} reaches a shut gate',
        build(level),
        (game) async {
          await game.ready();
          var thrown = false;
          var shutWhenThere = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (!lamp(game, 'switch-lamp').isOn) thrown = true;
                if (game.player.x > 200 &&
                    game.doors.single.openFraction < 0.05) {
                  shutWhenThere = true;
                }
              },
            );
          }
          expect(thrown, keyThrown, reason: run.where);
          expect(shutWhenThere, isTrue, reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }
  });

  group('the gate opens twice', () {
    final level = Levels.theGateOpensTwice;

    testWithGame<LevelGame>(
      'one stand on the plate opens the middle gate twice, and shuts between',
      build(level),
      (game) async {
        await game.ready();
        final middle = game.doors.last;
        // Off the plate — the opening under your own weight shuts as you
        // step off — and stand short of the gate, watching it.
        final run = Run(game)..play(level.solution.take(4));
        var openings = 0;
        var wasOpen = true;
        void watch() {
          final open = middle.openFraction > 0.5;
          if (open && !wasOpen) openings++;
          wasOpen = open;
        }

        run
          ..hold(0.6, axis: 1, each: watch)
          ..hold(9, each: watch);
        expect(openings, 2, reason: run.where);
      },
    );

    // The far past's opening ends six seconds and the grace after you step
    // off the plate, however long you stood — the six-second rule again — so
    // a stop by the key spends it, and standing longer does not buy it back.
    for (final (stand, pause, works) in const [
      (1.0, 0.0, true),
      (1.0, 1.5, true),
      (1.0, 3.0, false),
      (2.5, 3.0, false),
    ]) {
      testWithGame<LevelGame>(
        '${stand}s on the plate and a ${pause}s stop by the key '
        '${works ? 'still' : 'no longer'} gets back',
        build(level),
        (game) async {
          await game.ready();
          final run = Run(game)
            ..play(level.solution.take(3))
            ..hold(stand)
            ..play(level.solution.skip(4).take(6))
            ..hold(pause)
            ..play(level.solution.skip(10).take(1))
            ..walkTo(60);
          // Through on whichever opening is next, if there is one.
          var through = false;
          run.hold(
            4,
            axis: -1,
            each: () {
              if (game.player.x < -30) through = true;
            },
          );
          expect(through, works, reason: run.where);
        },
      );
    }

    for (final (i, (crossed, keyThrown)) in const [
      (true, false), // through and back, and the key forgotten
      (true, true), // the way out's plate before the key
      (false, false), // straight for the way out
    ].indexed) {
      testWithGame<LevelGame>(
        'wrong idea ${i + 1} reaches the way out, shut',
        build(level),
        (game) async {
          await game.ready();
          var wentThrough = false;
          var thrown = false;
          final run = Run(game);
          for (final move in level.wrongIdeas[i]) {
            run.hold(
              move.seconds,
              axis: move.axis,
              jump: move.jump,
              crouch: move.crouch,
              each: () {
                if (game.player.x > 40) wentThrough = true;
                if (!game.lights.single.isOn) thrown = true;
              },
            );
          }
          expect(wentThrough, crossed, reason: run.where);
          expect(thrown, keyThrown, reason: run.where);
          expect(game.player.x, greaterThan(-774), reason: run.where);
          expect(run.finishedAt, isNull, reason: run.where);
        },
      );
    }

    // A stair of both pasts by each gate: searched, each builds, none gets
    // past one shut.
    for (final (x, door, toward) in const [
      (-700.0, 0, -1.0), // the way out, from inside
      (-60.0, 1, 1.0), // the middle gate, from the first side
      (60.0, 1, -1.0), // and from the key's side
    ]) {
      testWithGame<LevelGame>(
        'a stair at $x gets past no shut gate',
        build(level),
        (game) async {
          await game.ready();
          final gate = level.doors[door].closed;
          var highest = double.infinity;
          var past = false;
          for (var shuffle = 0; shuffle <= 34; shuffle += 2) {
            game.reload();
            final run = Run(game);
            // To the key's side, for the one built there.
            if (x > 26) run.play(level.solution.take(7));
            run.walkTo(x);
            void hold(
              double seconds, {
              double axis = 0,
              bool jump = false,
              bool crouch = false,
            }) => run.hold(
              seconds,
              axis: axis,
              jump: jump,
              crouch: crouch,
              each: () {
                final player = game.player;
                if (player.y < highest) highest = player.y;
                final beyond = toward > 0
                    ? player.x > gate.right + 22
                    : player.x < gate.left - 22;
                if (beyond && game.doors[door].openFraction < 0.05) {
                  past = true;
                }
              },
            );
            hold(4.5, crouch: true);
            hold(1.6);
            hold(0.5, jump: true);
            hold(1.0, crouch: true);
            hold(1.0);
            hold(0.7, jump: true);
            hold(shuffle * Playthrough.dt, axis: toward);
            hold(1.0, axis: toward, jump: true);
            hold(0.6, axis: toward);
          }
          expect(highest, lessThan(370), reason: 'it builds');
          expect(past, isFalse);
        },
      );
    }
  });
}

/// A room with one named lamp over a plate that holds a gate, a switch for
/// the lamp in the dark, and the way out past the gate.
Level _room({
  List<PlateSpec> plates = const [
    PlateSpec(area: Rect.fromLTRB(-400, 608, -300, 620), opens: 'gate'),
    PlateSpec(area: Rect.fromLTRB(200, 608, 300, 620), opens: 'lamp'),
  ],
  List<ToggleSpec> toggles = const [],
  double delay = 4,
  List<LightSpec> lights = const [
    LightSpec(Rect.fromLTRB(-420, 200, -280, 620), id: 'lamp'),
  ],
}) => Level(
  id: 'lamp-room',
  name: 'x',
  teaches: 'x',
  delaySeconds: delay,
  spawnX: 0,
  blocks: const [Rect.fromLTRB(-1500, 620, 1500, 2200)],
  lights: lights,
  plates: plates,
  toggles: toggles,
  doors: const [
    DoorSpec(id: 'gate', closed: Rect.fromLTRB(800, 360, 826, 620)),
  ],
  goal: const Rect.fromLTRB(900, 548, 980, 620),
);
