import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/basket_levels.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// The basket on a rope (`docs/media/drops.md` §3.1): up while somebody
/// pulls, down when they let go, and it carries whoever is standing in it.
/// On the bench, so the game and the gate refuse it by name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build(Level level) =>
      LevelGame(levels: [level], inputs: [ScriptedInput()]);

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  /// A floor, a basket resting on it at 0–100 and going 200 up, and its rope
  /// — a plate at -300 — with whatever else a test wants.
  Level flat({
    double delay = 2,
    double linger = 0,
    List<PlateSpec> plates = const [],
    List<ToggleSpec> toggles = const [],
  }) => Level(
    id: 'basket-flat',
    name: 'basket-flat',
    teaches: 'basket-flat',
    delaySeconds: delay,
    spawnX: -400,
    floorTop: 620,
    blocks: [const Rect.fromLTRB(-3000, 620, 3000, 2200)],
    baskets: [
      BasketSpec(
        id: 'b',
        area: const Rect.fromLTRB(0, 600, 100, 620),
        rise: 200,
        lingerSeconds: linger,
      ),
    ],
    plates: [
      const PlateSpec(area: Rect.fromLTRB(-340, 608, -260, 620), opens: 'b'),
      ...plates,
    ],
    toggles: toggles,
    goal: const Rect.fromLTRB(2800, 548, 2880, 620),
  );

  group('the rule', () {
    testWithGame<LevelGame>(
      'it goes up while somebody is at the rope, and down when they leave',
      // Long enough that your past is not at the rope again before the end.
      () => build(flat(delay: 6)),
      (game) async {
        await game.ready();
        final basket = game.baskets.single;
        final run = Run(game)..walkTo(-300);
        run.hold(1.5);
        expect(basket.raised, 200, reason: 'all the way up, and no further');
        run.walkTo(-500);
        run.hold(1.5);
        expect(basket.raised, 0);
      },
    );

    testWithGame<LevelGame>(
      'it carries you, standing, all the way up and all the way down',
      // Long enough to pull, let it come down, and get in before your past
      // is at the rope.
      () => build(flat(delay: 4)),
      (game) async {
        await game.ready();
        final basket = game.baskets.single;
        final run = Run(game)..walkTo(-300);
        run.hold(1.2);
        // It is down again by the time you get back to it. In you get.
        run.walkTo(-40);
        run
          ..hold(0.35, axis: 1, jump: true)
          ..hold(0.6);
        expect(basket.carries(x: game.player.x, feet: game.player.y), isTrue);

        // Your past at the rope: up, and then down again.
        var rode = 0;
        var top = 0.0;
        run.hold(
          4,
          each: () {
            if (basket.raised == 0) return;
            rode++;
            if (basket.raised > top) top = basket.raised;
            expect(game.player.isGrounded, isTrue, reason: 'never airborne');
            expect(game.player.y, closeTo(basket.bounds.top, 0.5));
          },
        );
        expect(top, 200);
        expect(rode, greaterThan(60));
        expect(basket.raised, 0);
      },
    );

    testWithGame<LevelGame>(
      'a ride is recorded with the floor it was on, for your past to stand in',
      () => build(flat(delay: 4)),
      (game) async {
        await game.ready();
        final basket = game.baskets.single;
        final run = Run(game)..walkTo(-300);
        run.hold(1.2);
        run.walkTo(-40);
        run
          ..hold(0.35, axis: 1, jump: true)
          ..hold(0.5);
        var recorded = 0;
        var replayed = 0;
        run.hold(
          9,
          each: () {
            if (basket.raised > 0 && game.player.riding == basket.bounds) {
              recorded++;
            }
            if (game.shadows.single.snapshot?.riding != null) replayed++;
          },
        );
        expect(recorded, greaterThan(30), reason: 'while you rode it');
        expect(replayed, greaterThan(30), reason: 'and your past, after');
      },
    );

    testWithGame<LevelGame>(
      'the grace is your past\'s, never your own',
      () => build(flat(delay: 4, linger: 1)),
      (game) async {
        await game.ready();
        final basket = game.baskets.single;
        final run = Run(game)..walkTo(-300);
        run.hold(1.5);
        run.walkTo(-500);
        // You let go: it comes down at once.
        expect(basket.raised, lessThan(200));

        // Your past lets go: it stays up a second.
        run.hold(2.5);
        final upAgain = basket.raised;
        expect(upAgain, 200, reason: 'your past is at the rope now');
        var stayed = 0.0;
        run.hold(
          3,
          each: () {
            if (basket.raised == 200) stayed += Playthrough.dt;
          },
        );
        expect(stayed, greaterThan(1));
      },
    );

    testWithGame<LevelGame>(
      'an inverted plate holds it down whatever else is true',
      () => build(
        flat(
          plates: const [
            PlateSpec(
              area: Rect.fromLTRB(-140, 608, -60, 620),
              opens: 'b',
              inverts: true,
            ),
          ],
          toggles: const [
            ToggleSpec(area: Rect.fromLTRB(-240, 608, -160, 620), flips: 'b'),
          ],
        ),
      ),
      (game) async {
        await game.ready();
        final basket = game.baskets.single;
        final run = Run(game)..walkTo(-200); // the key: pulled for good
        run.hold(0.3);
        expect(basket.pulled, isTrue);
        run.walkTo(-100); // onto the inverted plate
        run.hold(1.5);
        expect(basket.pulled, isFalse);
        expect(basket.raised, 0);
      },
    );

    testWithGame<LevelGame>(
      'it is a floor: you walk into it, not through it',
      () => build(flat()),
      (game) async {
        await game.ready();
        Run(game).hold(3, axis: 1);
        expect(game.player.x, lessThan(0));
      },
    );
  });

  for (final level in Levels.bench.where((l) => l.baskets.isNotEmpty)) {
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
        'the same run, the same basket',
        () => build(level),
        (game) async {
          await game.ready();
          final where = <(double, double)>[];
          for (var i = 0; i < 2; i++) {
            game.reload();
            start(game).play(level.solution, stopWhenComplete: true);
            where.add((game.baskets.single.raised, game.player.y));
          }
          expect(where.first, where.last);
        },
      );

      test('the gate has nothing against it but the bench', () async {
        final verdict = await checkLevelJson(
          jsonDecode(jsonEncode(level.toJson())),
        );
        expect(verdict.findings, hasLength(1), reason: '${verdict.findings}');
        expect('${verdict.findings.single}', contains('still on the bench'));
      });
    });
  }

  group('the bench and the game', () {
    final level = BasketLevels.pullItForMe;

    test('a level with a basket says so', () {
      expect(level.requires, contains('baskets'));
      expect(Level.labMechanics, contains('baskets'));
      expect(Level.knownMechanics, isNot(contains('baskets')));
    });

    test('the bench reads it; the game refuses it by name', () {
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(
        levelFromJson(json, accepts: Level.benchMechanics).baskets,
        level.baskets,
      );
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelUnsupportedException>().having(
            (e) => e.onTheBench,
            'on the bench',
            {'baskets'},
          ),
        ),
      );
    });

    test('a level with none writes none', () {
      expect(Levels.campaign.first.toJson(), isNot(contains('baskets')));
    });

    test('the editor keeps it', () {
      final again = EditorDoc.fromLevel(level).toLevel();
      expect(again.baskets, level.baskets);
      expect(jsonEncode(again.toJson()), jsonEncode(level.toJson()));
    });

    test('no level in the campaign has one', () {
      expect(Levels.campaign.where((l) => l.baskets.isNotEmpty), isEmpty);
    });

    test('a basket and a door with one name is refused', () {
      final json = jsonDecode(jsonEncode(level.toJson())) as Map;
      json['doors'] = [
        {
          'id': 'basket',
          'closed': [600, 0, 626, 320],
        },
      ];
      final both = levelFromJson(json, accepts: Level.benchMechanics);
      expect(
        checkNumbers(both).map((f) => '$f'),
        contains(contains('two things are called "basket"')),
      );
      // And on its own, the bench is the only thing against it.
      expect(checkNumbers(level), hasLength(1));
    });
  });
}
