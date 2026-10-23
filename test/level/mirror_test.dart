import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/mirror_levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// The mirror (`docs/phase-12-more.md` §9): when your past arrives on it, you
/// are where it is. On the bench (`docs/lab.md`), so the game and the gate
/// refuse it by name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build(Level level) =>
      LevelGame(levels: [level], inputs: [ScriptedInput()]);

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  /// A floor with a mirror at 100–160, and nothing else.
  Level flat({
    List<double> delays = const [1],
    List<LightSpec> lights = const [],
    bool kills = false,
  }) => Level(
    id: 'mirror-flat',
    name: 'mirror-flat',
    teaches: 'mirror-flat',
    delays: delays,
    spawnX: 0,
    floorTop: 620,
    shadowKills: kills,
    blocks: const [Rect.fromLTRB(-2000, 620, 4000, 2200)],
    mirrors: const [Rect.fromLTRB(100, 608, 160, 620)],
    lights: lights,
    goal: const Rect.fromLTRB(3800, 548, 3880, 620),
  );

  /// Where the body was put down each time it jumped, and where the past
  /// that sent it was standing then.
  final landings = <(double, double)>[];

  /// Walks over the mirror and on to the right; returns the times, in
  /// seconds from the start, at which the body jumped.
  List<double> walkOver(LevelGame game, {double seconds = 4}) {
    final jumps = <double>[];
    landings.clear();
    var t = 0.0;
    var last = game.player.x;
    Run(game).hold(
      seconds,
      axis: 1,
      each: () {
        t += Playthrough.dt;
        if ((game.player.x - last).abs() > 30) {
          jumps.add(t);
          landings.add((game.player.x, game.shadow.x));
        }
        last = game.player.x;
      },
    );
    return jumps;
  }

  group('the rule', () {
    testWithGame<LevelGame>(
      'your past arriving on it puts you where it is',
      () => build(flat()),
      (game) async {
        await game.ready();
        final jumps = walkOver(game, seconds: 1.7);
        expect(jumps, hasLength(1));
        // One delay after you walked onto it.
        expect(jumps.single, closeTo(1.45, 0.15));
        final (you, past) = landings.single;
        expect(you, past);
        expect(game.mirrors.single.trigger.left, lessThan(you + 22));
        expect(game.reloads, 0);
      },
    );

    testWithGame<LevelGame>(
      'standing on it yourself does nothing',
      () => build(flat(delays: const [3])),
      (game) async {
        await game.ready();
        final run = Run(game)..walkTo(130);
        final there = game.player.x;
        run.hold(2.5);
        expect(game.player.x, there);
      },
    );

    testWithGame<LevelGame>(
      'once: being put there is not arriving, so it does not echo',
      () => build(flat()),
      (game) async {
        await game.ready();
        expect(walkOver(game, seconds: 6), hasLength(1));
      },
    );

    testWithGame<LevelGame>(
      'and every time you walk onto it again, again',
      () => build(flat()),
      (game) async {
        await game.ready();
        bool onIt() => game.player.x >= 94 && game.player.x <= 166;
        walkOver(game, seconds: 1.7);
        expect(onIt(), isTrue, reason: 'sent back once');
        // Off it to the right, back over it to the left, and stand clear.
        Run(game)
          ..hold(0.5, axis: 1)
          ..hold(0.9, axis: -1);
        expect(onIt(), isFalse);
        Run(game).hold(1.2);
        expect(onIt(), isTrue, reason: 'and again');
      },
    );

    testWithGame<LevelGame>(
      'a past in the light sends nobody',
      () => build(
        flat(lights: const [LightSpec(Rect.fromLTRB(60, 200, 200, 620))]),
      ),
      (game) async {
        await game.ready();
        expect(walkOver(game), isEmpty);
      },
    );

    testWithGame<LevelGame>(
      'two pasts, two returns',
      () => build(flat(delays: const [1, 2.5])),
      (game) async {
        await game.ready();
        expect(walkOver(game), hasLength(2));
      },
    );

    testWithGame<LevelGame>(
      'the past it puts you inside does not kill you; meeting it later does',
      () => build(flat(kills: true)),
      (game) async {
        await game.ready();
        walkOver(game, seconds: 1.7);
        expect(game.reloads, 0, reason: 'standing inside your past');
        // Step out of it and stand: it walks on along your old path, over
        // where you are standing.
        Run(game).hold(0.3, axis: -1);
        expect(game.reloads, 0);
        var caught = false;
        Run(game).hold(2, each: () => caught |= game.reloads > 0);
        expect(caught, isTrue);
      },
    );
  });

  group('marks', () {
    testWithGame<LevelGame>(
      'with two doors, every button and key carries its door\'s shape',
      () => build(Levels.yourPastGoesAgain),
      (game) async {
        await game.ready();
        final near = game.doors.firstWhere((d) => d.id == 'near');
        final far = game.doors.firstWhere((d) => d.id == 'far');
        expect({near.mark, far.mark}, {0, 1});
        for (final plate in game.plates) {
          final door = game.doors.firstWhere((d) => d.id == plate.opens);
          expect(plate.mark, door.mark);
        }
      },
    );

    testWithGame<LevelGame>(
      'with one, none: there is nothing to tell apart',
      () => build(Levels.theMirrorBringsYouBack),
      (game) async {
        await game.ready();
        expect(game.doors.single.mark, isNull);
        expect(game.plates.single.mark, isNull);
      },
    );
  });

  group('the bench and the game', () {
    final level = Levels.theMirrorBringsYouBack;

    test('a level with a mirror says so', () {
      expect(level.requires, contains('mirror'));
    });

    test('promoted: the game plays it, and an older build refuses it', () {
      expect(Level.knownMechanics, contains('mirror'));
      expect(Level.labMechanics, isNot(contains('mirror')));
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(levelFromJson(json).mirrors, level.mirrors);
      // What the name is for: a build from before it would put the level up
      // with no mirror in it, and a level about the mirror without one.
      final older = Level.knownMechanics.difference({'mirror'});
      expect(
        () => levelFromJson(json, accepts: older),
        throwsA(
          isA<LevelUnsupportedException>().having((e) => e.missing, 'missing', {
            'mirror',
          }),
        ),
      );
    });

    test('a level with none writes none', () {
      expect(Levels.campaign.first.toJson(), isNot(contains('mirrors')));
    });

    test('the gate takes it', () async {
      final verdict = await checkLevelJson(
        jsonDecode(jsonEncode(level.toJson())),
      );
      expect(verdict.findings, isEmpty);
    });

    test('the editor keeps it', () {
      final again = EditorDoc.fromLevel(level).toLevel();
      expect(again.mirrors, level.mirrors);
      expect(jsonEncode(again.toJson()), jsonEncode(level.toJson()));
    });

    test('the campaign has all nine, together, at its end', () {
      final mirrors = [
        for (final (i, l) in Levels.campaign.indexed)
          if (l.mirrors.isNotEmpty) i,
      ];
      expect(mirrors, hasLength(9));
      expect(mirrors.last - mirrors.first, 8, reason: 'one unbroken run');
      expect(Levels.campaign[mirrors.first].id, level.id);
      expect(mirrors.last, Levels.campaign.length - 1);
      expect(
        Levels.campaign[mirrors.first - 1].id,
        Levels.allOfItInTheDark.id,
        reason: 'after the stairwell: three of them put a lamp out',
      );
    });
  });

  for (final level in Levels.campaign.where((l) => l.mirrors.isNotEmpty)) {
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

      // The mirror is the puzzle: with it taken out, the solution is a walk
      // down to somewhere there is no coming back from.
      final without = levelFromJson(
        level.toJson()
          ..remove('mirrors')
          ..remove('requires'),
      );
      testWithGame<LevelGame>(
        'without the mirror the solution does not finish',
        () => build(without),
        (game) async {
          await game.ready();
          final run = start(game)..play(level.solution, stopWhenComplete: true);
          expect(run.finishedAt, isNull);
        },
      );
    });
  }

  group('the harder ones: sweeps', () {
    /// Plays each of [runs] from a fresh level and names the ones that
    /// finish.
    Future<Set<String>> finishing(
      LevelGame game,
      Map<String, List<Move>> runs,
    ) async {
      await game.ready();
      final done = <String>{};
      for (final entry in runs.entries) {
        game.reload();
        final run = start(game)..play(entry.value, stopWhenComplete: true);
        if (run.finishedAt != null) done.add(entry.key);
      }
      return done;
    }

    // Down, a wait short of the key, then onto it and stay: not a knife
    // edge — a second and more of waits work, and none at all does not.
    testWithGame<LevelGame>(
      'open-it-late: any wait down there over a second, and only that',
      () => build(MirrorLevels.openItLate),
      (game) async {
        final runs = {
          for (final wait in [0.0, 0.3, 1.5, 2.0, 2.5])
            '$wait': [
              const Move.right(1.75),
              Move(wait),
              const Move.right(0.6),
              // Stand until the mirror takes you back, then go.
              Move(6.0 - 1.75 - wait - 0.6),
              const Move.left(6),
            ],
        };
        expect(await finishing(game, runs), {'1.5', '2.0', '2.5'});
      },
    );

    testWithGame<LevelGame>(
      'all-of-it-in-the-mirror: the same window, with the lamp after',
      () => build(MirrorLevels.allOfItInTheMirror),
      (game) async {
        final runs = {
          for (final wait in [0.0, 0.5, 1.6, 2.0, 2.4])
            '$wait': [
              const Move.right(1.75),
              Move(wait),
              const Move.right(1.9),
              Move(6.9 - 1.75 - wait - 1.9),
              const Move.left(7),
            ],
        };
        expect(await finishing(game, runs), {'1.6', '2.0', '2.4'});
      },
    );

    testWithGame<LevelGame>(
      "the-mirror-in-the-light: any while on the door's button, then the lamp's",
      () => build(MirrorLevels.theMirrorInTheLight),
      (game) async {
        final runs = {
          for (final stand in [1.4, 1.85, 2.2])
            '$stand': [
              const Move.right(2.15),
              Move(stand),
              const Move.right(1.1),
              const Move(2),
              const Move.left(6),
            ],
        };
        expect(await finishing(game, runs), {'1.4', '1.85', '2.2'});
      },
    );

    testWithGame<LevelGame>(
      "two-of-you-two-returns: any while on the door's button that fits",
      () => build(MirrorLevels.twoOfYouTwoReturns),
      (game) async {
        final runs = {
          // Shorter than that and the far past lets go of the button before
          // you are at the door: it holds it as long as you did.
          for (final stand in [1.8, 2.1, 2.4])
            '$stand': [
              const Move.right(1.75),
              const Move.right(1.42),
              Move(stand),
              const Move.left(0.9),
              Move(4.4 - stand),
              const Move.left(8),
            ],
        };
        expect(await finishing(game, runs), {'1.8', '2.1', '2.4'});
      },
    );

    // The button first, for as long as you like, then the climb: your past
    // is off the button before you are up.
    testWithGame<LevelGame>(
      'a-step-then-a-mirror: the button before the climb never works',
      () => build(MirrorLevels.aStepThenAMirror),
      (game) async {
        final runs = {
          for (final stand in [0.5, 1.5, 3.0, 5.0])
            '$stand': [
              const Move.left(1.0),
              Move(stand),
              const Move.right(2.1),
              const Move(4.0, crouch: true),
              const Move.left(0.9),
              const Move(0.15),
              const Move.right(0.4),
              const Move.right(0.55, jump: true),
              const Move.right(0.6, jump: true),
              const Move.right(6),
            ],
        };
        expect(await finishing(game, runs), isEmpty);
      },
    );

    testWithGame<LevelGame>(
      'two-mirrors: the key any time in the window before the drop',
      () => build(MirrorLevels.twoMirrors),
      (game) async {
        final runs = {
          for (final wait in [0.2, 0.6, 1.0])
            '$wait': [
              const Move.right(2.2),
              const Move.right(0.95),
              const Move(1.7),
              const Move.left(0.5),
              Move(wait),
              const Move.left(0.5),
              Move(1.6 - wait),
              const Move.right(6),
            ],
        };
        expect(await finishing(game, runs), {'0.2', '0.6', '1.0'});
      },
    );

    // Every order that does the far button before going through: none of
    // them gets you the right side of the first door while your past is on
    // the far button.
    testWithGame<LevelGame>(
      'from-behind-the-door: the far button first never works',
      () => build(MirrorLevels.fromBehindTheDoor),
      (game) async {
        final runs = {
          for (final far in [0.5, 2.0, 4.0])
            for (final near in [1.0, 3.0, 5.0])
              for (final wait in [1.0, 3.0, 5.5])
                '$far/$near/$wait': [
                  const Move.left(1.6),
                  Move(far),
                  const Move.right(2.75),
                  Move(near),
                  const Move.right(0.6),
                  Move(wait),
                  const Move.right(8),
                ],
        };
        expect(await finishing(game, runs), isEmpty);
      },
    );
  });
}
