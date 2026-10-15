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
      expect(
        levelFromJson(json, accepts: Level.benchMechanics).lights,
        level.lights,
      );
    });

    test('the bench plays it; the game refuses it by name', () {
      expect(Level.labMechanics, contains('light-switch'));
      expect(Level.knownMechanics, isNot(contains('light-switch')));
      expect(
        () => levelFromJson(jsonDecode(jsonEncode(level.toJson()))),
        throwsA(
          isA<LevelUnsupportedException>().having(
            (e) => e.onTheBench,
            'on the bench',
            {'light-switch'},
          ),
        ),
      );
    });

    test('the gate refuses it as on trial, and for nothing else', () {
      final findings = checkNumbers(Levels.youHoldTheDark);
      expect(findings.map((f) => f.refusal), [Refusal.unsupported]);
      expect('${findings.single}', contains('still on the bench'));
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
        contains(contains('which is not a door or a light')),
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
