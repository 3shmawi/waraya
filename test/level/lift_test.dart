import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/lift_levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// The old lift (`docs/media/drops.md` §3.2): it goes to the floor whose
/// button was stepped on last, carries whoever is in it, and shuts its gate
/// while it travels. On the bench, so the game and the gate refuse it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build(Level level) =>
      LevelGame(levels: [level], inputs: [ScriptedInput()]);

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  /// A street, a cabin at 0–120 going 200 up to a ledge to its right, UP at
  /// -500 and DOWN at -200.
  Level street({
    double delay = 8,
    bool startsUp = false,
    double spawnX = -650,
    double floorTop = 620,
  }) => Level(
    id: 'lift-street',
    name: 'lift-street',
    teaches: 'lift-street',
    delaySeconds: delay,
    spawnX: spawnX,
    floorTop: floorTop,
    blocks: const [
      Rect.fromLTRB(-3000, 620, 120, 2200),
      Rect.fromLTRB(120, 420, 3000, 2200),
    ],
    lifts: [
      LiftSpec(
        id: 'lift',
        area: const Rect.fromLTRB(0, 600, 120, 620),
        rise: 180,
        callDown: const Rect.fromLTRB(-240, 608, -160, 620),
        callUp: const Rect.fromLTRB(-540, 608, -460, 620),
        startsUp: startsUp,
      ),
    ],
    goal: const Rect.fromLTRB(2800, 348, 2880, 420),
  );

  group('the rule', () {
    testWithGame<LevelGame>(
      'it goes to the floor whose button was stepped on last',
      () => build(street()),
      (game) async {
        await game.ready();
        final lift = game.lifts.single;
        final run = Run(game)..walkTo(-500);
        expect(lift.calledUp, isTrue);
        run.hold(1.2);
        expect(lift.raised, 180, reason: 'up, and no further');
        // Standing on UP calls it nothing more: it is an arrival.
        run.walkTo(-200);
        expect(lift.calledUp, isFalse);
        run.hold(1.2);
        expect(lift.raised, 0);
      },
    );

    testWithGame<LevelGame>(
      'a call while it travels turns it round there and then',
      () => build(street()),
      (game) async {
        await game.ready();
        final lift = game.lifts.single;
        final run = Run(game)..walkTo(-500);
        run.walkTo(-200);
        final turnedAt = lift.raised;
        expect(turnedAt, greaterThan(0));
        expect(turnedAt, lessThan(180), reason: 'still on its way up');
        run.hold(0.1);
        expect(lift.raised, lessThan(turnedAt));
      },
    );

    testWithGame<LevelGame>(
      'it carries you, standing, and its gate keeps you in',
      // Cabin waiting up top: DOWN brings it to you, and your past's UP —
      // six seconds after yours — takes you up in it.
      () => build(street(delay: 6, startsUp: true)),
      (game) async {
        await game.ready();
        final lift = game.lifts.single;
        final run = Run(game)..walkTo(-500); // UP: nothing happens
        run.walkTo(-200); // DOWN: it comes
        run.walkTo(-40);
        run.hold(1.0);
        run
          ..hold(0.35, axis: 1, jump: true)
          ..hold(0.5);
        expect(lift.carries(x: game.player.x, feet: game.player.y), isTrue);

        var rode = 0;
        // Pushing right the whole way up: the gate holds you in.
        run.hold(
          4,
          axis: 1,
          each: () {
            // On the way up with you in it; once you are off at the top your
            // past calls it down again, empty.
            if (!lift.moving || !lift.calledUp || lift.raised == 0) return;
            rode++;
            expect(game.player.isGrounded, isTrue);
            expect(game.player.y, closeTo(lift.bounds.top, 0.5));
            expect(game.player.x + 22, lessThanOrEqualTo(lift.bounds.right));
          },
        );
        expect(rode, greaterThan(30));
        expect(game.player.y, 420, reason: 'off at the top, onto the ledge');
      },
    );

    testWithGame<LevelGame>(
      'feet on the ledge stay there when the cabin leaves',
      // Standing on the ledge with half a body still over the cabin, the
      // way you are the moment you step off it.
      () => build(street(startsUp: true, spawnX: 125, floorTop: 420)),
      (game) async {
        await game.ready();
        final lift = game.lifts.single;
        expect(lift.carries(x: game.player.x, feet: game.player.y), isTrue);
        lift.touch(youDown: true, youUp: false, pastDown: false, pastUp: false);
        Run(game).hold(1.5);
        expect(lift.raised, 0);
        expect(game.player.y, 420);
        expect(game.player.x, greaterThan(100));
      },
    );
  });

  for (final level in Levels.bench.where((l) => l.lifts.isNotEmpty)) {
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
        'the same run, the same lift',
        () => build(level),
        (game) async {
          await game.ready();
          final where = <(double, double)>[];
          for (var i = 0; i < 2; i++) {
            game.reload();
            start(game).play(level.solution, stopWhenComplete: true);
            where.add((game.lifts.single.raised, game.player.y));
          }
          expect(where.first, where.last);
        },
      );

      test('nothing against it but the bench', () {
        expect(checkNumbers(level), hasLength(1));
        expect('${checkNumbers(level).single}', contains('still on the bench'));
      });
    });
  }

  group('the bench and the game', () {
    final level = LiftLevels.callItFromUpThere;

    test('a level with a lift says so', () {
      expect(level.requires, contains('lifts'));
      expect(Level.labMechanics, contains('lifts'));
      expect(Level.knownMechanics, isNot(contains('lifts')));
    });

    test('the bench reads it; the game refuses it by name', () {
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(
        levelFromJson(json, accepts: Level.benchMechanics).lifts,
        level.lifts,
      );
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelUnsupportedException>().having(
            (e) => e.onTheBench,
            'on the bench',
            {'lifts'},
          ),
        ),
      );
    });

    test('where it starts survives the trip', () {
      final up = LiftLevels.callItWhileItIsUp;
      final again = levelFromJson(
        jsonDecode(jsonEncode(up.toJson())),
        accepts: Level.benchMechanics,
      );
      expect(again.lifts.single.startsUp, isTrue);
    });

    test('a level with none writes none', () {
      expect(Levels.campaign.first.toJson(), isNot(contains('lifts')));
    });

    test('the editor keeps it', () {
      final again = EditorDoc.fromLevel(level).toLevel();
      expect(again.lifts, level.lifts);
      expect(jsonEncode(again.toJson()), jsonEncode(level.toJson()));
    });

    test('no level in the campaign has one', () {
      expect(Levels.campaign.where((l) => l.lifts.isNotEmpty), isEmpty);
    });

    test('a lift and a door with one name is refused', () {
      final json = jsonDecode(jsonEncode(level.toJson())) as Map;
      json['doors'] = [
        {
          'id': 'lift',
          'closed': [600, 0, 626, 320],
        },
      ];
      final both = levelFromJson(json, accepts: Level.benchMechanics);
      expect(
        checkNumbers(both).map((f) => '$f'),
        contains(contains('two things are called "lift"')),
      );
    });
  });
}
