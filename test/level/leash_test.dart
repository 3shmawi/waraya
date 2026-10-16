import 'dart:math';
import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
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
      'before your past arrives it holds you from the start',
      () => build(flat(leash: 50, delay: 2)),
      (game) async {
        await game.ready();
        Run(game).hold(1.9, axis: 1);
        expect(game.shadows.single.isActive, isFalse);
        expect(game.player.x, inInclusiveRange(40, 50.01));
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
        final run = Run(game)..hold(2.75, axis: 1);
        var hung = false;
        run.hold(0.4, each: () => hung |= game.player.isHanging);
        expect(hung, isTrue, reason: run.where);
        expect(game.player.y, greaterThan(620));
        expect(game.reloads, 0);
      },
    );

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

  for (final level in [Levels.hangOnYourPast, Levels.theLightLetsGo]) {
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
}
