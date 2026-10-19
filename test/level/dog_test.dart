import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/audio/sfx.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/dog.dart';
import 'package:waraya/level/dog_levels.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// Every sound the game asked for, with how loud.
class _Heard implements AudioOut {
  final List<(Sfx, double)> played = [];

  @override
  Future<void> preload() async {}

  @override
  void play(Sfx sfx, {double volume = 1.0}) => played.add((sfx, volume));
}

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

  group('seen off, and heard', () {
    testWithGame<LevelGame>(
      'you run back, seen, and the controls are not yours till you are there',
      () => build(flat()),
      (game) async {
        await game.ready();
        var biggestStep = 0.0;
        var furthestBack = double.infinity;
        var last = game.player.x;
        var bitten = false;
        // Hold right the whole time: while it sees you off you run left
        // anyway.
        Run(game).hold(
          3,
          axis: 1,
          each: () {
            final step = game.player.x - last;
            biggestStep = [
              biggestStep,
              step.abs(),
            ].reduce((a, b) => a > b ? a : b);
            if (step < -1) bitten = true;
            if (bitten) {
              furthestBack = [
                furthestBack,
                game.player.x,
              ].reduce((a, b) => a < b ? a : b);
            }
            last = game.player.x;
          },
        );
        expect(bitten, isTrue);
        expect(biggestStep, lessThan(15), reason: 'a run, not a jump');
        expect(furthestBack, closeTo(-300, 12));
      },
    );

    final heard = _Heard();
    testWithGame<LevelGame>(
      'it barks when it turns on you, and snarls when it gets you',
      () =>
          LevelGame(levels: [flat()], inputs: [ScriptedInput()], audio: heard),
      (game) async {
        await game.ready();
        heard.played.clear();
        var firstBark = -1;
        var inSight = -1;
        var frame = 0;
        Run(game).hold(
          2,
          axis: 1,
          each: () {
            frame++;
            if (inSight < 0 && game.player.x >= -Dog.sight) inSight = frame;
            if (firstBark < 0 && heard.played.any((e) => e.$1 == Sfx.bark)) {
              firstBark = frame;
            }
          },
        );
        // As soon as you come into sight, not when it gets to you.
        expect(firstBark - inSight, inInclusiveRange(0, 2));
        expect(heard.played.map((e) => e.$1), contains(Sfx.snarl));
        final atYou = heard.played.firstWhere((e) => e.$1 == Sfx.bark);
        expect(atYou.$2, greaterThan(0.5), reason: 'loud: it is after you');
      },
    );

    testWithGame<LevelGame>(
      'and only under its breath at your past',
      () => LevelGame(
        levels: [
          flat(delays: const [2.5]),
        ],
        inputs: [ScriptedInput()],
        audio: heard,
      ),
      (game) async {
        await game.ready();
        final run = Run(game)..walkTo(-120);
        for (var i = 0; i < 12; i++) {
          run
            ..hold(0.25, axis: 1)
            ..hold(0.25, axis: -1);
        }
        run.hold(0.8);
        heard.played.clear();
        run.hold(1.5);
        final barks = heard.played.where((e) => e.$1 == Sfx.bark);
        expect(barks, isNotEmpty);
        expect(barks.every((e) => e.$2 < 0.5), isTrue);
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

    // The same pacing, in the dark and in the light: how long you pace does
    // not decide it, where you pace does.
    testWithGame<LevelGame>(
      'pace-in-the-dark: pacing short of the lamp works, under it never',
      () => build(DogLevels.paceInTheDark),
      (game) async {
        List<Move> run(int turns, {required bool inTheLight}) => [
          const Move.right(0.55, jump: true),
          const Move.right(0.55, jump: true),
          const Move.right(0.25),
          const Move.right(0.55, jump: true),
          Move.right(inTheLight ? 2.0 : 1.3),
          ...pace(turns, first: -1),
          Move.left(inTheLight ? 2.6 : 1.6),
          const Move.right(8),
        ];
        expect(
          await finishing(game, {
            for (final turns in [2, 12, 16, 20])
              turns: run(turns, inTheLight: false),
            for (final turns in [12, 16, 20, 24])
              100 + turns: run(turns, inTheLight: true),
          }),
          {12, 16, 20},
        );
      },
    );

    // The floor in front of the dog's ground is the one spot down there it
    // can see and cannot get at. Pacing there solved both ledge levels
    // without the ledge, found by playing; a lamp under the ledge closed it.
    for (final level in [DogLevels.theDog, DogLevels.paceInTheDark]) {
      testWithGame<LevelGame>(
        '${level.id}: pacing on the floor in front of it never works',
        () => build(level),
        (game) async {
          final runs = <int, List<Move>>{};
          for (final (w, walk) in [2.4, 2.6, 2.8, 3.0].indexed) {
            for (final (t, turns) in [8, 12, 16, 20, 24].indexed) {
              for (final (s, wait) in [0.0, 0.6, 2.0].indexed) {
                runs[w * 100 + t * 10 + s] = [
                  Move.right(walk),
                  ...pace(turns, first: -1),
                  Move(wait),
                  const Move.right(8),
                ];
              }
            }
          }
          expect(await finishing(game, runs), isEmpty);
        },
      );
    }

    // The order is the puzzle: pacing then the button works however long
    // you pace (past a minimum) and however briefly you stand; the button
    // then pacing never does, however long you wait after.
    testWithGame<LevelGame>(
      'the-dog-first: the dog then the button, never the other way round',
      () => build(DogLevels.theDogFirst),
      (game) async {
        final runs = <int, List<Move>>{};
        for (final (t, turns) in [10, 12, 16, 20].indexed) {
          for (final (s, stand) in [0.0, 1.0, 2.0].indexed) {
            runs[t * 10 + s] = [
              const Move.right(0.4),
              ...pace(turns),
              const Move.left(1.0),
              Move(stand),
              const Move.right(10),
            ];
          }
          for (final (w, wait) in [0.0, 0.6, 2.0, 4.0, 6.0].indexed) {
            runs[100 + t * 10 + w] = [
              const Move.left(0.45),
              const Move(1.0),
              const Move.right(1.0),
              ...pace(turns),
              Move(wait),
              const Move.right(10),
            ];
          }
        }
        expect(await finishing(game, runs), {
          for (var t = 0; t < 4; t++)
            for (var s = 0; s < 3; s++) t * 10 + s,
        });
      },
    );

    // The key darkens what you did before it: pace, then throw it, works;
    // throw it, then pace, never does.
    testWithGame<LevelGame>(
      'the-dark-behind-you: the pacing then the key, never the other way',
      () => build(DogLevels.theDarkBehindYou),
      (game) async {
        final runs = <int, List<Move>>{};
        for (final (t, turns) in [10, 14, 20].indexed) {
          for (final (w, wait) in [0.0, 0.6, 1.2].indexed) {
            runs[t * 10 + w] = [
              const Move.right(0.35),
              ...pace(turns),
              const Move.left(0.8),
              const Move(0.5),
              const Move.right(0.8),
              Move(wait),
              const Move.right(8),
            ];
          }
          for (final (w, wait) in [0.0, 0.6, 1.2, 3.0, 6.0].indexed) {
            runs[100 + t * 10 + w] = [
              const Move.left(0.3),
              const Move(0.5),
              const Move.right(0.8),
              ...pace(turns),
              Move(wait),
              const Move.right(8),
            ];
          }
        }
        expect(await finishing(game, runs), {
          for (var t = 0; t < 3; t++)
            for (var w = 0; w < 3; w++) t * 10 + w,
        });
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
