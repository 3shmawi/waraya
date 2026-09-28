// What the game reports about each go at a level, with nowhere to send it.
import 'dart:convert';
import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/attempts.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/level/supabase_attempts.dart';

class Recorded implements AttemptSink {
  final rows = <Attempt>[];

  @override
  void record(Attempt attempt) => rows.add(attempt);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Recorded sink;
  late AttemptLog log;
  setUp(() {
    sink = Recorded();
    log = AttemptLog(sink, random: Random(7));
  });

  LevelGame build() => LevelGame(
    levels: [Levels.pressItEarly, Levels.standOnYourself],
    inputs: [ScriptedInput()],
    attempts: log,
  );

  Playthrough start(LevelGame game) =>
      Playthrough(game, game.input.sources.first as ScriptedInput);

  testWithGame<LevelGame>('a level finished is one row, in game time', build, (
    game,
  ) async {
    await game.ready();
    final run = start(game)
      ..play(Levels.pressItEarly.solution, stopWhenComplete: true);

    final attempt = sink.rows.single;
    expect(attempt.outcome, 'finished');
    expect(attempt.levelId, Levels.pressItEarly.id);
    expect(attempt.delays, Levels.pressItEarly.delays);
    expect(attempt.reloads, 0);
    expect(attempt.seconds, closeTo(run.finishedAt!, 0.05));
  });

  testWithGame<LevelGame>('every retry is counted, and where it happened', build, (
    game,
  ) async {
    await game.ready();
    final run = start(game)..play(const [Move.left(1)]);
    final x = game.player.x;
    game.reload();
    run.play(const [Move.right(0.5)]);
    game.reload();
    run.play(Levels.pressItEarly.solution, stopWhenComplete: true);

    final attempt = sink.rows.single;
    expect(attempt.reloads, 2);
    expect(attempt.deaths, hasLength(2));
    expect(attempt.deaths.first.$1, x.round());
    // All three goes, not the last one: the level cost them that long.
    expect(attempt.seconds, greaterThan(run.finishedAt! - 0.05));
  });

  testWithGame<LevelGame>('picking another level leaves this one', build, (
    game,
  ) async {
    await game.ready();
    start(game).play(const [Move.left(2)]);
    await game.goTo(1);

    expect(sink.rows.single.outcome, 'left');
    expect(sink.rows.single.levelId, Levels.pressItEarly.id);
    expect(sink.rows.single.seconds, closeTo(2, 0.05));
  });

  testWithGame<LevelGame>(
    'put away and come back: the same go, sent twice, the last one counts',
    build,
    (game) async {
      await game.ready();
      // Put away before the first step, so the solution still starts where
      // it was recorded from.
      log.hidden();
      start(game).play(Levels.pressItEarly.solution, stopWhenComplete: true);

      expect(sink.rows.map((a) => a.outcome), ['hidden', 'finished']);
      expect(sink.rows.first.attemptId, sink.rows.last.attemptId);
    },
  );

  testWithGame<LevelGame>(
    'finishing and moving on does not also count as leaving',
    build,
    (game) async {
      await game.ready();
      start(game)
        ..play(Levels.pressItEarly.solution, stopWhenComplete: true)
        ..play(const [Move(1.5)]);

      expect(game.level.id, Levels.standOnYourself.id);
      expect(sink.rows.map((a) => a.outcome), ['finished']);
      log.hidden();
      expect(sink.rows.last.levelId, Levels.standOnYourself.id);
      expect(sink.rows.first.attemptId, isNot(sink.rows.last.attemptId));
    },
  );

  test('the row is what the table takes, with the install\'s id', () async {
    final bodies = <String>[];
    final attempts = SupabaseAttempts(
      uuid4(Random(1)),
      post: (body) async => bodies.add(body),
    );
    attempts.record(
      const Attempt(
        attemptId: 'a',
        levelId: 'two-not-one',
        delays: [2, 6],
        outcome: 'finished',
        seconds: 12.3456,
        reloads: 3,
        deaths: [(10, 620), (-40, 700)],
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(jsonDecode(bodies.single), {
      'attempt_id': 'a',
      'device_id': attempts.deviceId,
      'level_id': 'two-not-one',
      'delays': [2, 6],
      'outcome': 'finished',
      'seconds': 12.35,
      'reloads': 3,
      'deaths': [
        [10, 620],
        [-40, 700],
      ],
    });
  });

  test('a send that fails goes nowhere', () async {
    final attempts = SupabaseAttempts(
      'x',
      post: (_) async => throw Exception('offline'),
    );
    attempts.record(
      const Attempt(
        attemptId: 'a',
        levelId: 'l',
        delays: [1],
        outcome: 'left',
        seconds: 1,
        reloads: 0,
        deaths: [],
      ),
    );
    // Nothing thrown into the zone: the test would fail if it were.
    await Future<void>.delayed(Duration.zero);
  });

  test('ids are version-4 UUIDs, which is what the column takes', () {
    final random = Random(3);
    for (var i = 0; i < 50; i++) {
      expect(
        uuid4(random),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
  });
}
