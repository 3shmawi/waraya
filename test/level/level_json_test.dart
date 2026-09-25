import 'dart:convert';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/level_source.dart';
import 'package:waraya/level/levels.dart';

import 'solution.dart';

/// A level that survives a round trip through JSON is not one whose fields
/// compare equal — it is one that can still be finished. So that is what these
/// check: encode a level, decode it, and replay the recorded solution on the
/// copy. If serialisation drops a plate or rounds a rectangle, the puzzle
/// stops working and the test says so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Level roundTrip(Level level) =>
      levelFromJson(jsonDecode(jsonEncode(level.toJson())));

  group('a level survives the trip to JSON and back', () {
    for (final level in Levels.campaign) {
      testWithGame<LevelGame>(
        '${level.id} is still solvable after being encoded and decoded',
        () => LevelGame(levels: [roundTrip(level)], inputs: [ScriptedInput()]),
        (game) async {
          await game.ready();
          final run = Playthrough(
            game,
            game.input.sources.first as ScriptedInput,
          )..play(walkthroughs[level.id]!, stopWhenComplete: true);

          expect(run.finishedAt, isNotNull, reason: run.where);
        },
      );
    }

    test('and keeps every field it was given', () {
      for (final level in Levels.campaign) {
        final copy = roundTrip(level);
        expect(copy.id, level.id);
        expect(copy.name, level.name);
        expect(copy.teaches, level.teaches);
        expect(copy.delaySeconds, level.delaySeconds);
        expect(copy.spawnX, level.spawnX);
        expect(copy.floorTop, level.floorTop);
        expect(copy.shadowKills, level.shadowKills);
        expect(copy.shadowIsSolid, level.shadowIsSolid);
        expect(copy.goal, level.goal);
        expect(copy.blocks, level.blocks);
        expect(copy.markers, level.markers);
        expect(
          copy.plates.map((p) => p.opens),
          level.plates.map((p) => p.opens),
        );
        // Which way round a plate works is the difference between a door you
        // can open and one you cannot, and it is one bool in the middle of a
        // list of rectangles — exactly the kind of thing a round trip drops
        // without anything looking wrong.
        expect(
          copy.plates.map((p) => p.inverts),
          level.plates.map((p) => p.inverts),
        );
        expect(
          copy.toggles.map((t) => (t.area, t.flips)),
          level.toggles.map((t) => (t.area, t.flips)),
        );
        // A light that did not survive the trip is a level that plays, and
        // plays as an easier level, with nothing anywhere saying so.
        expect(copy.lights, level.lights);
        expect(copy.requires, level.requires);
        expect(copy.doors.map((d) => d.id), level.doors.map((d) => d.id));
      }
    });
  });

  group('malformed data fails with something you can act on', () {
    Map<String, Object?> valid() =>
        jsonDecode(jsonEncode(Levels.pressItEarly.toJson()))
            as Map<String, Object?>;

    void expectRefused(Map<String, Object?> json, String mentions) {
      expect(
        () => levelFromJson(json),
        throwsA(
          isA<LevelFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains(mentions), contains('press-it-early')),
          ),
        ),
      );
    }

    test(
      'a missing name',
      () => expectRefused(valid()..remove('name'), 'name'),
    );

    // Written both ways, and both are checked. A level from before there
    // could be more than one shadow carries `delaySeconds` alone and is still
    // read; anything with `delays` is read from that and `delaySeconds` is
    // along for the ride, for older builds to find.
    test('a delay that is text', () {
      expectRefused(
        valid()
          ..remove('delays')
          ..['delaySeconds'] = 'soon',
        'delaySeconds',
      );
    });

    test('a list of delays with text in it', () {
      expectRefused(valid()..['delays'] = [3, 'soon'], 'delays[1]');
    });

    test('a list of delays with nothing in it', () {
      expectRefused(valid()..['delays'] = <double>[], 'delays');
    });

    test('a rectangle with three numbers', () {
      expectRefused(valid()..['goal'] = [1, 2, 3], 'goal');
    });

    test('a rectangle that is inside out', () {
      expectRefused(valid()..['goal'] = [100, 100, 10, 10], 'goal');
    });

    test('a plate that opens nothing', () {
      expectRefused(
        valid()
          ..['plates'] = [
            {
              'area': [0, 0, 10, 10],
            },
          ],
        'opens',
      );
    });

    test('junk instead of a level', () {
      expect(() => levelFromJson('nope'), throwsA(isA<LevelFormatException>()));
      expect(() => levelsFromJson(42), throwsA(isA<LevelFormatException>()));
    });

    test('text that is not JSON at all', () {
      expect(
        const JsonLevels('<html>404</html>', label: 'server').load(),
        throwsA(
          isA<LevelFormatException>().having(
            (e) => e.message,
            'message',
            contains('server'),
          ),
        ),
      );
    });
  });

  group('built-in levels plus whatever the server adds', () {
    final extra = Levels.pressItEarly;

    test('extra levels land after the ones that shipped', () async {
      final source = LevelsThenExtras(
        const BuiltInLevels(),
        JsonLevels(
          jsonEncode([
            {...extra.toJson(), 'id': 'from-the-server'},
          ]),
        ),
      );

      final levels = await source.load();
      expect(levels.length, Levels.campaign.length + 1);
      expect(levels.last.id, 'from-the-server');
      expect(
        levels.take(Levels.campaign.length).map((l) => l.id),
        Levels.campaign.map((l) => l.id),
        reason: 'the shipped campaign keeps its order',
      );
    });

    test(
      'a server cannot overwrite a level that ships with the game',
      () async {
        final source = LevelsThenExtras(
          const BuiltInLevels(),
          JsonLevels(
            jsonEncode([
              {...extra.toJson(), 'name': 'hijacked', 'delaySeconds': 0.5},
            ]),
          ),
        );

        final levels = await source.load();
        expect(levels.length, Levels.campaign.length);
        expect(levels.first.name, Levels.pressItEarly.name);
      },
    );

    test('a server having a bad day costs you nothing', () async {
      Object? reported;
      final source = LevelsThenExtras(
        const BuiltInLevels(),
        const JsonLevels('{ not json', label: 'server'),
        onError: (error) => reported = error,
      );

      final levels = await source.load();
      expect(levels.map((l) => l.id), Levels.campaign.map((l) => l.id));
      expect(reported, isA<LevelFormatException>());
    });
  });
}
