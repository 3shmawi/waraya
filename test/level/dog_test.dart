import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/dog.dart';
import 'package:waraya/level/dog_levels.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// The street dog (`docs/phase-12-more.md` §10): it runs at what moves, and
/// it sees you off. On the bench, so the game and the gate refuse it by name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build(Level level) =>
      LevelGame(levels: [level], inputs: [ScriptedInput()]);

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  /// A floor, and a dog keeping 0–600, sitting at 300, seeing you off to
  /// -300.
  Level flat({
    List<double> delays = const [1],
    List<LightSpec> lights = const [],
    List<Rect> blocks = const [],
  }) => Level(
    id: 'dog-flat',
    name: 'dog-flat',
    teaches: 'dog-flat',
    delays: delays,
    spawnX: -400,
    floorTop: 620,
    blocks: [const Rect.fromLTRB(-3000, 620, 3000, 2200), ...blocks],
    lights: lights,
    dogs: const [
      DogSpec(area: Rect.fromLTRB(0, 560, 600, 620), home: 300, backTo: -300),
    ],
    goal: const Rect.fromLTRB(2800, 548, 2880, 620),
  );

  group('the rule', () {
    testWithGame<LevelGame>(
      'it runs at you and sees you off, back where you came in',
      () => build(flat()),
      (game) async {
        await game.ready();
        var seenOff = false;
        Run(game).hold(
          3,
          axis: 1,
          each: () => seenOff |= game.player.x < -290 && game.player.x > -310,
        );
        expect(seenOff, isTrue);
        expect(game.reloads, 0, reason: 'seen off, not killed');
      },
    );

    testWithGame<LevelGame>(
      'it is faster than you, and never leaves its ground',
      () => build(flat()),
      (game) async {
        await game.ready();
        expect(Dog.chaseSpeed, greaterThan(220));
        var furthest = 300.0;
        Run(game).hold(
          4,
          axis: 1,
          each: () => furthest = [
            furthest,
            game.dogs.single.along,
          ].reduce((a, b) => a < b ? a : b),
        );
        expect(furthest, greaterThanOrEqualTo(Dog.bodyWidth / 2));
      },
    );

    testWithGame<LevelGame>(
      'what stands still it leaves alone',
      () => build(flat()),
      (game) async {
        await game.ready();
        // Up to the edge of where it can see, and stand.
        final run = Run(game)..walkTo(-140);
        run.hold(4);
        expect(game.dogs.single.target, isNull);
        expect(game.dogs.single.along, closeTo(300, 1));
      },
    );

    testWithGame<LevelGame>(
      'once after something it does not let go while that keeps moving',
      () => build(flat(delays: const [2.5])),
      (game) async {
        await game.ready();
        // Pace at the edge, stand while your past paces there, then walk in.
        final run = Run(game)..walkTo(-120);
        for (var i = 0; i < 12; i++) {
          run
            ..hold(0.25, axis: 1)
            ..hold(0.25, axis: -1);
        }
        run.hold(1.0);
        expect(game.dogs.single.afterYou, isFalse);
        run.hold(1.2, axis: 1);
        expect(game.player.x, greaterThan(100), reason: 'walked right by');
        expect(game.dogs.single.afterYou, isFalse);
      },
    );

    testWithGame<LevelGame>(
      'a past in the light is not there for it either',
      () => build(
        flat(lights: const [LightSpec(Rect.fromLTRB(-260, 200, 0, 620))]),
      ),
      (game) async {
        await game.ready();
        final run = Run(game)..walkTo(-120);
        for (var i = 0; i < 8; i++) {
          run
            ..hold(0.25, axis: 1)
            ..hold(0.25, axis: -1);
        }
        run.hold(1.0);
        expect(game.dogs.single.target, isNull);
      },
    );
  });

  group('the bench and the game', () {
    final level = DogLevels.theDog;

    test('a level with a dog says so', () {
      expect(level.requires, contains('dog'));
      expect(Level.labMechanics, contains('dog'));
      expect(Level.knownMechanics, isNot(contains('dog')));
    });

    test('the bench reads it; the game refuses it by name', () {
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(
        levelFromJson(json, accepts: Level.benchMechanics).dogs,
        level.dogs,
      );
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelUnsupportedException>().having(
            (e) => e.onTheBench,
            'on the bench',
            {'dog'},
          ),
        ),
      );
    });

    test('a level with none writes none', () {
      expect(Levels.campaign.first.toJson(), isNot(contains('dogs')));
    });

    test('the gate refuses it as on trial', () async {
      final verdict = await checkLevelJson(
        jsonDecode(jsonEncode(level.toJson())),
      );
      expect(verdict.accepted, isFalse);
      expect('${verdict.findings.single}', contains('still on the bench'));
    });

    test('the editor keeps it', () {
      final again = EditorDoc.fromLevel(level).toLevel();
      expect(again.dogs, level.dogs);
      expect(jsonEncode(again.toJson()), jsonEncode(level.toJson()));
    });

    test('no level in the campaign has one', () {
      expect(Levels.campaign.where((l) => l.dogs.isNotEmpty), isEmpty);
    });
  });

  for (final level in Levels.bench.where((l) => l.dogs.isNotEmpty)) {
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

      testWithGame<LevelGame>(
        'the same run, the same dog',
        () => build(level),
        (game) async {
          await game.ready();
          final where = <double>[];
          for (var i = 0; i < 2; i++) {
            game.reload();
            start(game).play(level.solution, stopWhenComplete: true);
            where.add(game.dogs.single.along);
          }
          expect(where.first, where.last);
        },
      );
    });
  }

  group('sweeps', () {
    Future<Set<int>> finishing(
      LevelGame game,
      Map<int, List<Move>> runs,
    ) async {
      await game.ready();
      final done = <int>{};
      for (final entry in runs.entries) {
        game.reload();
        final run = start(game)..play(entry.value, stopWhenComplete: true);
        if (run.finishedAt != null) done.add(entry.key);
      }
      return done;
    }

    /// Back and forth, [turns] times, starting towards [first].
    List<Move> pace(int turns, {double first = 1}) => [
      for (var i = 0; i < turns; i++)
        Move(0.3, axis: i.isEven ? first : -first),
    ];

    testWithGame<LevelGame>(
      'the-dog: any long enough pacing at the end of the ledge',
      () => build(DogLevels.theDog),
      (game) async {
        List<Move> run(int turns) => [
          const Move.right(0.55, jump: true),
          const Move.right(0.55, jump: true),
          const Move.right(0.25),
          const Move.right(0.55, jump: true),
          const Move.right(2.0),
          // Back first: the end of the ledge is just ahead.
          ...pace(turns, first: -1),
          const Move.left(2.6),
          const Move.right(8),
        ];
        expect(
          await finishing(game, {
            for (final turns in [2, 12, 16, 20]) turns: run(turns),
          }),
          {12, 16, 20},
        );
      },
    );

    // Pace long enough and it works; how much longer than that does not
    // matter. Too short and your past stops before you are through.
    testWithGame<LevelGame>(
      'walk-on-the-button: any long enough walk on the button',
      () => build(DogLevels.walkOnTheButton),
      (game) async {
        final runs = {
          for (final turns in [2, 12, 16, 20])
            turns: [
              const Move.right(1.45),
              ...pace(turns),
              const Move(0.6),
              const Move.right(8),
            ],
        };
        expect(await finishing(game, runs), {12, 16, 20});
      },
    );
  });
}
