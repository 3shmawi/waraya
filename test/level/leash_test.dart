import 'dart:math';
import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/leash_line.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// The leash (`docs/phase-12-more.md` §3): you cannot get further than
/// [Level.leash] from your past. On the bench (`docs/lab.md`), so the game
/// and the gate refuse it by name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build(Level level) =>
      LevelGame(levels: [level], inputs: [ScriptedInput()]);

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  /// A floor and nothing else, with the leash and the delay given.
  Level flat({
    double leash = 100,
    double delay = 1,
    List<LightSpec> lights = const [],
  }) => Level(
    id: 'leash-flat',
    name: 'leash-flat',
    teaches: 'leash-flat',
    delaySeconds: delay,
    leash: leash,
    spawnX: 0,
    floorTop: 620,
    blocks: const [Rect.fromLTRB(-2000, 620, 4000, 2200)],
    lights: lights,
    goal: const Rect.fromLTRB(3800, 548, 3880, 620),
  );

  /// How far the body is from where its past holds it: the past, or the
  /// start while there is no past yet.
  double fromPast(LevelGame game) {
    final past = game.shadows.single;
    final to = past.isActive
        ? past.bounds.center
        : Offset(game.level.spawnX, game.level.floorTop - 48);
    return (game.player.bounds.center - to).distance;
  }

  group('the rule', () {
    testWithGame<LevelGame>(
      'you get as far as the leash and no further',
      () => build(flat()),
      (game) async {
        await game.ready();
        var furthest = 0.0;
        final run = Run(game)
          ..hold(
            8,
            axis: 1,
            each: () => furthest = max(furthest, fromPast(game)),
          );
        expect(furthest, lessThanOrEqualTo(100.01));
        // Held, not stopped: every time the past catches up you get
        // another leash's length.
        expect(game.player.x, greaterThan(400), reason: run.where);
      },
    );

    testWithGame<LevelGame>(
      'your past is there from the start, standing, and holds you',
      () => build(flat(leash: 50, delay: 2)),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        // Before a single tick: someone at the other end of the rope.
        expect(past.isActive, isTrue);
        expect(past.x, game.level.spawnX);
        Run(game).hold(1.9, axis: 1);
        expect(past.x, game.level.spawnX, reason: 'it waits out the delay');
        expect(game.player.x, inInclusiveRange(45, 50.01));
      },
    );

    testWithGame<LevelGame>(
      'the end is soft: a slow walk behind your past, not a stop and a wait',
      () => build(flat(leash: 90, delay: 3)),
      (game) async {
        await game.ready();
        final run = Run(game)..hold(6, axis: 1);
        // Once it is walking after you, you never stand still for long: the
        // hard end had you stopped for over two seconds in every three.
        var still = 0, longest = 0;
        var last = game.player.x;
        run.hold(
          6,
          axis: 1,
          each: () {
            still = game.player.x - last < 0.05 ? still + 1 : 0;
            longest = max(longest, still);
            last = game.player.x;
          },
        );
        expect(longest * Playthrough.dt, lessThan(0.3));
        expect(fromPast(game), lessThanOrEqualTo(90.01));
      },
    );

    testWithGame<LevelGame>(
      'it never pulls: a past walking away leaves you where you are',
      () => build(flat(leash: 40, delay: 1)),
      (game) async {
        await game.ready();
        // Out and back, then stand: your past walks out again on its own.
        final run = Run(game)
          ..hold(0.3, axis: 1)
          ..hold(0.6, axis: -1)
          ..hold(0.4);
        final standing = game.player.x;
        var furthest = 0.0;
        run.hold(3, each: () => furthest = max(furthest, fromPast(game)));
        expect(game.player.x, standing);
        expect(furthest, greaterThan(40), reason: 'the past never left');
      },
    );

    testWithGame<LevelGame>(
      'and you cannot jump further from it than that either',
      () => build(flat(leash: 60, delay: 1)),
      (game) async {
        await game.ready();
        final run = Run(game)..hold(2);
        var top = double.infinity;
        run.hold(1, jump: true, each: () => top = min(top, game.player.y));
        expect(top, closeTo(620 - 60, 1));
      },
    );

    testWithGame<LevelGame>(
      'a past in the light holds nothing',
      () => build(
        flat(lights: const [LightSpec(Rect.fromLTRB(-2000, 200, 4000, 620))]),
      ),
      (game) async {
        await game.ready();
        Run(game).hold(4, axis: 1);
        expect(game.player.x, greaterThan(600));
      },
    );

    testWithGame<LevelGame>(
      'off an edge with your past on it, you hang under it',
      () => build(Levels.hangOnYourPast),
      (game) async {
        await game.ready();
        final run = Run(game);
        var hung = false;
        run.hold(4, axis: 1, each: () => hung |= game.player.isHanging);
        expect(hung, isTrue, reason: run.where);
        expect(game.player.y, greaterThan(620));
        expect(game.reloads, 0);
      },
    );

    test('the line tightens up to the end and thins past it', () {
      expect(LeashLine.widthAt(0.5), lessThan(LeashLine.widthAt(1)));
      expect(LeashLine.widthAt(1.4), lessThan(LeashLine.widthAt(1)));
      expect(LeashLine.widthAt(2), lessThan(LeashLine.widthAt(1.4)));
    });

    test('and hums past it', () {
      expect(LeashLine.strainAt(1), 0);
      expect(LeashLine.strainAt(1.1), greaterThan(0));
      expect(LeashLine.strainAt(1.5), greaterThan(LeashLine.strainAt(1.1)));
    });

    // In the dark you can never be more than a leash ahead of where you were
    // D seconds ago, so leash ÷ delay is the fastest you go there. At 30 a
    // second «النور بيفكّك» was a crawl, reported from playing.
    test('no level with a leash crawls', () {
      for (final level in Levels.bench.where((l) => l.leash != null)) {
        final pace = level.leash! / level.delays.last;
        expect(pace, greaterThanOrEqualTo(50), reason: level.id);
      }
    });

    test('no level in the campaign has one', () {
      expect(Levels.campaign.where((level) => level.leash != null), isEmpty);
    });
  });

  group('the bench and the game', () {
    final level = Levels.hangOnYourPast;

    test('a level with a leash says so', () {
      expect(level.requires, contains('leash'));
      expect(Level.labMechanics, contains('leash'));
      expect(Level.knownMechanics, isNot(contains('leash')));
    });

    test('the bench reads it; the game refuses it by name', () {
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(levelFromJson(json, accepts: Level.benchMechanics).leash, 200);
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelUnsupportedException>().having(
            (e) => e.onTheBench,
            'on the bench',
            {'leash'},
          ),
        ),
      );
    });

    test('the gate refuses it as on trial', () async {
      final verdict = await checkLevelJson(
        jsonDecode(jsonEncode(level.toJson())),
      );
      expect(verdict.accepted, isFalse);
      expect('${verdict.findings.single}', contains('still on the bench'));
    });
  });

  for (final level in Levels.bench.where((l) => l.leash != null)) {
    group(level.id, () {
      testWithGame<LevelGame>('solved', () => build(level), (game) async {
        await game.ready();
        final run = start(game)..play(level.solution, stopWhenComplete: true);
        expect(run.finishedAt, isNotNull);
      });

      for (final (i, idea) in level.wrongIdeas.indexed) {
        testWithGame<LevelGame>(
          'wrong idea ${i + 1} does not finish',
          () => build(level),
          (game) async {
            await game.ready();
            final run = start(game)..play(idea, stopWhenComplete: true);
            expect(run.finishedAt, isNull);
          },
        );
      }

      testWithGame<LevelGame>('nothing cheap finishes it', () => build(level), (
        game,
      ) async {
        await game.ready();
        final beaten = <String>[];
        for (final entry in cheapRuns(level).entries) {
          game.reload();
          final run = start(game)..play(entry.value, stopWhenComplete: true);
          if (run.finishedAt != null) beaten.add(entry.key);
        }
        expect(beaten, isEmpty);
      });
    });
  }

  // The way in under the ledge is for the leash: with it taken off, no
  // step off the edge and turn back, at any frame, falls into it.
  final loose = levelFromJson(
    Levels.hangOnYourPast.toJson()
      ..remove('leash')
      ..remove('requires'),
  );
  testWithGame<LevelGame>(
    'hang-on-your-past: without the leash a fall goes past the way in',
    () => build(loose),
    (game) async {
      await game.ready();
      final inside = <String>[];
      for (var out = 0; out < 24; out++) {
        for (var wait = 0; wait < 30; wait++) {
          game.reload();
          final run = Run(game)
            ..walkTo(-10)
            ..hold(out / 60, axis: 1)
            ..hold(wait / 60)
            ..hold(3, axis: -1);
          if (run.finishedAt != null || game.player.y == 818) {
            inside.add('out $out, wait $wait');
          }
        }
      }
      expect(inside, isEmpty);
    },
  );

  // A jump that falls short goes down the lower roof's face, past the way in
  // under it, and pushing into the face all the way down does not turn it in.
  testWithGame<LevelGame>(
    'light-then-dark: a short jump falls past the way in',
    () => build(Levels.lightThenDark),
    (game) async {
      await game.ready();
      final inside = <String>[];
      for (var frames = 40; frames < 78; frames++) {
        game.reload();
        final run = start(game)
          ..play([
            const Move.left(2.5),
            Move.right(frames / 60),
            const Move.right(0.8, jump: true),
            const Move.right(3),
          ], stopWhenComplete: true);
        if (run.finishedAt != null || game.player.y == 822) {
          inside.add('run-up $frames');
        }
      }
      expect(inside, isEmpty);
    },
  );

  // The lamp in dark-then-light is over a step on the way, so walking out
  // to the edge — over the step or round it — lights your past for a moment,
  // not for a run and a jump.
  testWithGame<LevelGame>(
    'dark-then-light: passing the lamp on the way is not standing in it',
    () => build(Levels.darkThenLight),
    (game) async {
      await game.ready();
      final beaten = <String>[];
      for (var tenths = 60; tenths <= 110; tenths += 2) {
        for (final hop in [false, true]) {
          game.reload();
          final run = start(game)
            ..play([
              const Move.right(1.5),
              Move.left(tenths / 10, jump: hop),
              const Move.left(0.8, jump: true),
              const Move.left(5),
            ], stopWhenComplete: true);
          if (run.finishedAt != null) beaten.add('${tenths / 10}s, hop $hop');
        }
      }
      expect(beaten, isEmpty);
    },
  );

  // And its way in under the high roof is for the leash, like the first.
  final looseHigh = levelFromJson(
    Levels.darkThenLight.toJson()
      ..remove('leash')
      ..remove('requires'),
  );
  testWithGame<LevelGame>(
    'dark-then-light: without the leash a fall goes past the way in',
    () => build(looseHigh),
    (game) async {
      await game.ready();
      final inside = <String>[];
      for (var out = 0; out < 24; out++) {
        for (var wait = 0; wait < 30; wait++) {
          game.reload();
          Run(game)
            ..walkTo(-10)
            ..hold(out / 60, axis: 1)
            ..hold(wait / 60)
            ..hold(2, axis: -1);
          if (game.player.y == 422) inside.add('out $out, wait $wait');
        }
      }
      expect(inside, isEmpty);
    },
  );
}
