// Levels from the server, with no server.
//
// Everything that matters about `SupabaseLevels` is what it does when the
// server is wrong: slow, down, answering nonsense, or answering with a level
// this build should not play. So the server here is a function, and each test
// hands in the kind of wrong it is about.
import 'dart:async';
import 'dart:convert';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/level_source.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/level/supabase_levels.dart';

class MemoryCache implements LevelCache {
  MemoryCache([this.body]);

  String? body;

  @override
  Future<String?> read() async => body;

  @override
  Future<void> write(String body) async => this.body = body;
}

/// A campaign level under a new id, as a row PostgREST would send it.
Map<String, Object?> row(Level level, String id, [void Function(Map)? edit]) {
  final data = jsonDecode(jsonEncode(level.toJson())) as Map<String, Object?>
    ..['id'] = id;
  edit?.call(data);
  return {'data': data};
}

String body(List<Object?> rows) => jsonEncode(rows);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final good = row(Levels.standOnYourself, 'from-the-server');
  final alsoGood = row(Levels.goInLow, 'also-from-the-server');

  test('what the server publishes comes through, in its order', () async {
    final source = SupabaseLevels(
      fetch: () async => body([good, alsoGood]),
    );
    final levels = await source.load();
    expect(levels.map((l) => l.id), ['from-the-server', 'also-from-the-server']);
  });

  test('a level the gate should not have passed is refused here', () async {
    final refused = <Verdict>[];
    final broken = row(Levels.standOnYourself, 'broken', (data) {
      (data['solution']! as List).removeLast();
    });
    final source = SupabaseLevels(
      fetch: () async => body([broken, good]),
      onRefused: refused.add,
    );

    final levels = await source.load();

    expect(levels.map((l) => l.id), ['from-the-server']);
    expect(refused.single.levelId, 'broken');
    expect(refused.single.refusals, {Refusal.solutionFails});
  });

  test('a level newer than this build is refused by name', () async {
    final refused = <Verdict>[];
    final newer = row(Levels.standOnYourself, 'newer', (data) {
      data['requires'] = [...data['requires']! as List, 'light-switch'];
    });
    final source = SupabaseLevels(
      fetch: () async => body([newer, good]),
      onRefused: refused.add,
    );

    expect((await source.load()).map((l) => l.id), ['from-the-server']);
    expect(refused.single.refusals, {Refusal.unsupported});
    expect(refused.single.findings.single.detail, contains('light-switch'));
  });

  group('when the server is not there', () {
    test('with nothing kept, it fails — and the campaign does not', () async {
      final down = SupabaseLevels(fetch: () async => throw Exception('down'));
      await expectLater(down.load(), throwsException);

      final errors = <Object>[];
      final all = await LevelsThenExtras(
        const BuiltInLevels(),
        down,
        onError: errors.add,
      ).load();
      expect(all, Levels.campaign);
      expect(errors, hasLength(1));
    });

    test('the last good answer is played instead', () async {
      final cache = MemoryCache();
      await SupabaseLevels(
        fetch: () async => body([good]),
        cache: cache,
      ).load();
      // Written without being awaited, so give it its turn.
      await Future<void>.delayed(Duration.zero);

      final levels = await SupabaseLevels(
        fetch: () async => throw Exception('down'),
        cache: cache,
      ).load();
      expect(levels.map((l) => l.id), ['from-the-server']);
    });

    test('a server that hangs is given up on', () async {
      final never = Completer<String>();
      final levels = await SupabaseLevels(
        fetch: () => never.future,
        cache: MemoryCache(body([good])),
        timeout: const Duration(milliseconds: 50),
      ).load();
      expect(levels.map((l) => l.id), ['from-the-server']);
    });

    test('nonsense is not kept in place of the last good answer', () async {
      final cache = MemoryCache(body([good]));
      final levels = await SupabaseLevels(
        fetch: () async => '<html>502 Bad Gateway</html>',
        cache: cache,
      ).load();
      await Future<void>.delayed(Duration.zero);

      expect(levels.map((l) => l.id), ['from-the-server']);
      expect(cache.body, body([good]));
    });
  });

  test('a server level cannot stand in for a built-in one', () async {
    final impostor = row(Levels.goInLow, Levels.pressItEarly.id);
    final all = await LevelsThenExtras(
      const BuiltInLevels(),
      SupabaseLevels(fetch: () async => body([impostor, good])),
    ).load();

    expect(all.first, same(Levels.pressItEarly));
    expect(all.map((l) => l.id), [
      ...Levels.campaign.map((l) => l.id),
      'from-the-server',
    ]);
  });

  testWithGame<LevelGame>(
    'levels that arrive mid-play go on the end, and nothing else moves',
    () => LevelGame(
      levels: [Levels.pressItEarly, Levels.standOnYourself],
      inputs: [ScriptedInput()],
    ),
    (game) async {
      await game.ready();
      final before = game.level;
      game.addLevels([
        levelFromJson(good['data']),
        levelFromJson(row(Levels.goInLow, Levels.standOnYourself.id)['data']),
      ]);

      expect(game.level, same(before));
      expect(game.levelIndex, 0);
      expect(game.levels.map((l) => l.id), [
        Levels.pressItEarly.id,
        Levels.standOnYourself.id,
        'from-the-server',
      ]);
      expect(game.levels[1], same(Levels.standOnYourself));
    },
  );
}
