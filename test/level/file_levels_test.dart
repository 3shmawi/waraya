import 'dart:convert';
import 'dart:io';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/file_levels.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'solution.dart';

/// Levels read off the disk, which is what makes "a level is data, not code"
/// true in practice rather than on paper.
///
/// The test that matters is the last one in the first group: a level that has
/// been through a file is not one whose fields compare equal, it is one that
/// can still be **finished**. Everything else here is about the authoring loop
/// being usable — a mistake in a file you are editing has to say which file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('waraya-levels'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, Object? json) =>
      File('${dir.path}/$name')..writeAsStringSync(jsonEncode(json));

  group('a folder of levels', () {
    test('is read in filename order, so the names decide the order', () async {
      write('20-second.json', Levels.campaign[1].toJson());
      write('10-first.json', Levels.campaign[0].toJson());
      write('notes.txt', 'ignored');

      final levels = await FileLevels(dir.path).load();
      expect(levels.map((l) => l.id), [
        Levels.campaign[0].id,
        Levels.campaign[1].id,
      ]);
    });

    test('can be one file holding several', () async {
      write('all.json', Levels.campaign.map((l) => l.toJson()).toList());
      expect(
        (await FileLevels(dir.path).load()).length,
        Levels.campaign.length,
      );
    });

    test('or one file holding one, which is how one gets written', () async {
      final file = write('one.json', Levels.campaign.first.toJson());
      expect(
        (await FileLevels(file.path).load()).single.id,
        Levels.campaign.first.id,
      );
    });
  });

  group('what it says when the file is wrong', () {
    test('a typo names the file it is in', () async {
      File('${dir.path}/broken.json').writeAsStringSync('{ "id": ');
      await expectLater(
        FileLevels(dir.path).load(),
        throwsA(
          isA<LevelFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('broken.json'), contains('not valid JSON')),
          ),
        ),
      );
    });

    test('a missing field names the file too', () async {
      write('half.json', {'id': 'half', 'name': 'half'});
      await expectLater(
        FileLevels(dir.path).load(),
        throwsA(
          isA<LevelFormatException>().having(
            (e) => e.message,
            'message',
            contains('half.json'),
          ),
        ),
      );
    });

    test('two levels with one id name both files', () async {
      write('a.json', Levels.campaign.first.toJson());
      write('b.json', Levels.campaign.first.toJson());
      await expectLater(
        FileLevels(dir.path).load(),
        throwsA(
          isA<LevelFormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('a.json'), contains('b.json')),
          ),
        ),
      );
    });

    test('a path that is neither a file nor a folder says so', () {
      expect(
        FileLevels('${dir.path}/nowhere.json').load(),
        throwsA(isA<LevelFormatException>()),
      );
    });

    test('a level ahead of this build is left out and reported', () async {
      // `crates` is named in the plan and deliberately not built, which makes
      // it the honest stand-in for a level authored against a newer build
      // than this one.
      write('ahead.json', Levels.campaign.first.toJson()..['requires'] = [
        'crates',
      ]);
      write('here.json', Levels.campaign[1].toJson());

      final skipped = <LevelUnsupportedException>[];
      final levels = await FileLevels(
        dir.path,
        onSkipped: skipped.add,
      ).load();

      expect(levels.single.id, Levels.campaign[1].id);
      expect(skipped.single.missing, {'crates'});
    });
  });

  testWithGame<LevelGame>(
    'a level that has been through a file can still be finished',
    () => LevelGame(levels: [Levels.campaign.first], inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      final level = Levels.campaign.first;
      final file = File('${dir.path}/round-trip.json')
        ..writeAsStringSync(jsonEncode(level.toJson()));

      await game.replaceLevels(await FileLevels(file.path).load());

      final run = Playthrough(game, game.input.sources.first as ScriptedInput)
        ..play(walkthroughs[level.id]!, stopWhenComplete: true);
      expect(run.finishedAt, isNotNull, reason: run.where);
    },
  );

  group('swapping the list under a running game', () {
    testWithGame<LevelGame>(
      'keeps your place by id, not by position',
      () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        await game.goTo(2);
        final editing = game.level.id;

        // What authoring actually looks like: something new lands in front of
        // the level you have open. By position you would be thrown into a
        // different level every time you pressed reload.
        await game.replaceLevels([Levels.campaign[5], ...Levels.campaign]);

        expect(game.level.id, editing);
        expect(game.levelIndex, 3);
      },
    );

    testWithGame<LevelGame>(
      'falls back to the first when the level you were on is gone',
      () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        await game.goTo(4);
        await game.replaceLevels(Levels.campaign.take(2).toList());
        expect(game.levelIndex, 0);
      },
    );

    testWithGame<LevelGame>(
      'ignores an empty list rather than leaving nothing on screen',
      () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        await game.goTo(1);
        final before = game.level.id;

        // The folder was emptied, or every level in it was refused. Obeying
        // that is a crash; keeping the last good one is what lets you fix the
        // file and press the button again.
        await game.replaceLevels(const []);
        expect(game.level.id, before);
      },
    );
  });
}
