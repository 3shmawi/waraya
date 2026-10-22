import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/level/barber_levels.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

import 'run.dart';

/// The barber's mirrors (`docs/media/drops.md` §3.5): your past arrives on
/// one and goes on from the other, doing what you do from over there, until
/// it arrives on that one again. Never a step. On the bench.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build(Level level) =>
      LevelGame(levels: [level], inputs: [ScriptedInput()]);

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  /// A street with a mirror at -400, and its twin 300 up at the same x, on a
  /// floor above the street.
  Level twin({double delay = 2}) => Level(
    id: 'barber-twin',
    name: 'barber-twin',
    teaches: 'barber-twin',
    delaySeconds: delay,
    spawnX: -600,
    floorTop: 620,
    blocks: const [
      Rect.fromLTRB(-3000, 620, 3000, 2200),
      Rect.fromLTRB(-3000, 320, 3000, 340),
    ],
    barberMirrors: const [
      BarberMirrorSpec(
        from: Rect.fromLTRB(-430, 608, -370, 620),
        to: Rect.fromLTRB(-430, 308, -370, 320),
      ),
    ],
    goal: const Rect.fromLTRB(2800, 548, 2880, 620),
  );

  group('the rule', () {
    testWithGame<LevelGame>(
      'your past goes across, and does what you do from over there',
      () => build(twin()),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        final run = Run(game)..walkTo(-400); // onto the mirror
        run.walkTo(-100); // and on, 300 along the street
        run.hold(2.5);
        expect(past.away, const Offset(0, -300), reason: 'upstairs');
        expect(past.y, closeTo(320, 0.5));
        expect(past.x, closeTo(game.player.x, 1), reason: 'where you went');
        expect(game.player.y, 620, reason: 'and you stayed down here');
      },
    );

    testWithGame<LevelGame>(
      'going across is not an arrival on the other side',
      () => build(twin()),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        // Onto the mirror, and stand: your past arrives on it and comes
        // out standing on its twin, and stays there.
        final run = Run(game)..walkTo(-400);
        run.hold(3);
        expect(past.away, const Offset(0, -300));
      },
    );

    testWithGame<LevelGame>(
      'it comes back when it arrives on the mirror over there',
      () => build(twin()),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        final run = Run(game)..walkTo(-400);
        run.walkTo(-100);
        run.walkTo(-400); // back over the mirror: up there, over its twin
        run.hold(2.5);
        expect(past.away, Offset.zero, reason: 'back with you');
        expect(past.y, closeTo(620, 0.5));
      },
    );

    testWithGame<LevelGame>(
      'over there it is never a step',
      () => build(twin()),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        final run = Run(game)..walkTo(-400);
        run.walkTo(-200);
        run.hold(2.5, crouch: true); // ducked: a step, anywhere else
        expect(past.away, isNot(Offset.zero));
        expect(past.crouch, greaterThan(0.5));
        expect(game.standableShadows, isEmpty);
      },
    );

    testWithGame<LevelGame>(
      'over there it is a body: a wall up there stops it, not you',
      () => build(
        Level(
          id: 'barber-wall',
          name: 'barber-wall',
          teaches: 'barber-wall',
          delaySeconds: 2,
          spawnX: -600,
          floorTop: 620,
          blocks: const [
            Rect.fromLTRB(-3000, 620, 3000, 2200),
            Rect.fromLTRB(-3000, 320, 3000, 340),
            // Up there only.
            Rect.fromLTRB(-250, 240, -230, 320),
          ],
          barberMirrors: const [
            BarberMirrorSpec(
              from: Rect.fromLTRB(-430, 608, -370, 620),
              to: Rect.fromLTRB(-430, 308, -370, 320),
            ),
          ],
          goal: const Rect.fromLTRB(2800, 548, 2880, 620),
        ),
      ),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        final run = Run(game)..walkTo(-400);
        run.walkTo(0);
        run.hold(3);
        expect(game.player.x, closeTo(0, 6), reason: 'nothing in your way');
        expect(past.x + 22, lessThanOrEqualTo(-250), reason: 'its wall');
      },
    );

    testWithGame<LevelGame>(
      'off the edge over there, it is back with you',
      () => build(
        Level(
          id: 'barber-edge',
          name: 'barber-edge',
          teaches: 'barber-edge',
          delaySeconds: 2,
          spawnX: -600,
          floorTop: 620,
          blocks: const [
            Rect.fromLTRB(-3000, 620, 1000, 2200),
            // A room far off to the right, whose floor ends at 2300.
            Rect.fromLTRB(1500, 620, 2300, 2200),
          ],
          barberMirrors: const [
            BarberMirrorSpec(
              from: Rect.fromLTRB(-430, 608, -370, 620),
              to: Rect.fromLTRB(1570, 608, 1630, 620),
            ),
          ],
          goal: const Rect.fromLTRB(2800, 548, 2880, 620),
        ),
      ),
      (game) async {
        await game.ready();
        final past = game.shadows.single;
        final run = Run(game)..walkTo(-400);
        run.walkTo(400); // over there: 2400, past the end of its floor
        run.hold(4);
        expect(past.away, Offset.zero, reason: 'it fell, and came back');
        expect(past.y, closeTo(620, 0.5));
        expect(game.reloads, 0, reason: 'your past, not you');
      },
    );

    testWithGame<LevelGame>(
      'a reload brings every past back',
      () => build(twin()),
      (game) async {
        await game.ready();
        final run = Run(game)..walkTo(-400);
        run.hold(2.5);
        expect(game.shadows.single.away, isNot(Offset.zero));
        game.reload();
        run.hold(0.1);
        expect(game.shadows.single.away, Offset.zero);
      },
    );
  });

  for (final level in Levels.bench.where((l) => l.barberMirrors.isNotEmpty)) {
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
        'the same run, the same past',
        () => build(level),
        (game) async {
          await game.ready();
          final where = <(double, double)>[];
          for (var i = 0; i < 2; i++) {
            game.reload();
            start(game).play(level.solution, stopWhenComplete: true);
            final past = game.shadows.first;
            where.add((past.x, past.y));
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
    final level = BarberLevels.overYourHead;

    test('a level with them says so', () {
      expect(level.requires, contains('barber-mirrors'));
      expect(Level.labMechanics, contains('barber-mirrors'));
      expect(Level.knownMechanics, isNot(contains('barber-mirrors')));
    });

    test('the bench reads it; the game refuses it by name', () {
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(
        levelFromJson(json, accepts: Level.benchMechanics).barberMirrors,
        level.barberMirrors,
      );
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelUnsupportedException>().having(
            (e) => e.onTheBench,
            'on the bench',
            {'barber-mirrors'},
          ),
        ),
      );
    });

    test('a level with none writes none', () {
      expect(Levels.campaign.first.toJson(), isNot(contains('barberMirrors')));
    });

    test('the editor keeps them', () {
      final again = EditorDoc.fromLevel(level).toLevel();
      expect(again.barberMirrors, level.barberMirrors);
      expect(jsonEncode(again.toJson()), jsonEncode(level.toJson()));
    });

    test('no level in the campaign has one', () {
      expect(Levels.campaign.where((l) => l.barberMirrors.isNotEmpty), isEmpty);
    });
  });
}
