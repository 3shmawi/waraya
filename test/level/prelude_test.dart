import 'dart:convert';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

/// Level zero and the demonstration it opens with (`docs/phase-11-feel.md`
/// §4.1), and the bench's way of keeping it from players (`docs/lab.md` §1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final level = Levels.thatsYou;

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  LevelGame build() => LevelGame(levels: [level], inputs: [ScriptedInput()]);

  group('the bench and the game', () {
    test('no name is both on trial and in the game', () {
      expect(
        Level.labMechanics.intersection(Level.knownMechanics),
        isEmpty,
      );
    });

    test('a level with a prelude says so', () {
      expect(level.requires, contains('prelude'));
      expect(Levels.campaign.where((l) => l.prelude.isNotEmpty), isEmpty);
    });

    test('the bench reads it; the game refuses it by name', () {
      final json = jsonDecode(jsonEncode(level.toJson()));
      expect(
        levelFromJson(json, accepts: Level.benchMechanics).prelude,
        level.prelude,
      );
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelUnsupportedException>()
              .having((e) => e.onTheBench, 'on the bench', {'prelude'})
              .having((e) => '$e', 'message', contains('still on the bench')),
        ),
      );
    });

    test('the gate refuses it as on trial, not as unknown', () async {
      final verdict = await checkLevelJson(
        jsonDecode(jsonEncode(level.toJson())),
      );
      expect(verdict.accepted, isFalse);
      expect('${verdict.findings.single}', contains('still on the bench'));
    });

    test('the editor\'s panel says the same, before any replay', () {
      expect(
        checkNumbers(level).map((f) => '$f'),
        contains(contains('still on the bench')),
      );
    });

    test('every bench level can be checked', () {
      for (final bench in Levels.bench) {
        expect(bench.canBeChecked, isTrue, reason: bench.id);
      }
    });
  });

  group('level zero', () {
    testWithGame<LevelGame>('stand on it, then go: your past holds it', build, (
      game,
    ) async {
      await game.ready();
      final run = start(game)..play(level.solution);
      expect(run.finishedAt, isNotNull, reason: run.where);
    });

    for (final (i, idea) in level.wrongIdeas.indexed) {
      testWithGame<LevelGame>('wrong idea ${i + 1} does not finish', build, (
        game,
      ) async {
        await game.ready();
        final run = start(game)..play(idea);
        expect(run.finishedAt, isNull, reason: run.where);
      });
    }

    testWithGame<LevelGame>(
      'the demonstration walks before you move, and goes when you do',
      build,
      (game) async {
        await game.ready();
        final prelude = game.prelude!;
        final run = start(game)..play(const [Move(2.0)]);
        expect(prelude.figure.isActive, isTrue, reason: run.where);
        expect(prelude.figure.x, greaterThan(level.spawnX), reason: run.where);

        run.play(const [Move.right(0.2), Move(1.0)]);
        expect(prelude.showing, isFalse);
        expect(prelude.figure.isActive, isFalse);

        // Put back, it shows again: the level is where it started.
        game.reload();
        run.play(const [Move(0.5)]);
        expect(prelude.showing, isTrue);
      },
    );

    testWithGame<LevelGame>(
      'the demonstration presses nothing',
      build,
      (game) async {
        await game.ready();
        // Leave the plate at once: only the demonstration is on it after
        // that, and the door must not care.
        final run = start(game)..play(const [Move.left(0.6), Move(0.01)]);
        game.prelude!.restart(); // as if never dismissed
        run.play(const [Move(2.5)]);
        expect(game.plates.single.isPressed, isFalse, reason: run.where);
      },
    );
  });
}
