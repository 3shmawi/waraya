import 'dart:convert';
import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/sky_backdrop.dart';
import 'package:waraya/game/stairwell.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/ui/level_fade.dart';
import 'package:waraya/ui/level_select.dart';
import 'package:waraya/ui/words.dart';

/// Where a level stands, and the chapters that come out of it
/// (`docs/phase-12-more.md` §4).
///
/// A place is paint. The rectangles are the same wherever they are drawn —
/// `look_test.dart` plays the whole campaign lit to prove it — so what is
/// checked here is the rest: that a place travels with its level, that it
/// never stops a level being read, and that walking from one place into the
/// next is a beat of dark with the new place's name in it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const double dt = 1 / 60;

  Level roundTrip(Level level) =>
      levelFromJson(jsonDecode(jsonEncode(level.toJson())));

  /// The first level of the second chapter.
  final firstStair = Levels.campaign.indexWhere(
    (level) => level.place == LevelPlace.stairwell,
  );

  group('the data', () {
    test('the campaign is two chapters, each one unbroken run', () {
      // A place that came back after another one would put up the first
      // place's card twice, and say a chapter was over that was not.
      final runs = <LevelPlace>[];
      for (final level in Levels.campaign) {
        if (runs.isEmpty || runs.last != level.place) runs.add(level.place);
      }
      expect(runs, [LevelPlace.rooftops, LevelPlace.stairwell]);
    });

    test('the stairwell is the light switch, and ends on a finale', () {
      final stairs = Levels.campaign.sublist(firstStair);
      expect(stairs.first.id, Levels.youHoldTheDark.id);
      expect(stairs.last.id, Levels.allOfItInTheDark.id);
      // Each chapter ends in a level that gathers it up.
      expect(Levels.campaign[firstStair - 1].id, Levels.allOfItAgain.id);
      for (final level in stairs) {
        expect(level.requires, contains('light-switch'), reason: level.id);
      }
    });

    test('a place goes with its level through JSON', () {
      for (final level in Levels.campaign) {
        expect(roundTrip(level).place, level.place, reason: level.id);
      }
    });

    test(
      'the rooftops are not written, so older levels read back the same',
      () {
        final json = Levels.pressItEarly.toJson();
        expect(json, isNot(contains('place')));
        expect(Levels.youHoldTheDark.toJson()['place'], 'stairwell');
      },
    );

    test('a place is never something a level requires', () {
      // A build that has never heard of places draws the stairwell on the
      // rooftops, and that is the same puzzle somewhere else.
      for (final level in Levels.campaign) {
        expect(level.requires.where((m) => m.contains('place')), isEmpty);
      }
    });

    test('a place this build has never heard of is drawn on the rooftops', () {
      final json = Levels.youHoldTheDark.toJson()..['place'] = 'factory';
      final level = levelFromJson(jsonDecode(jsonEncode(json)));
      expect(level.place, LevelPlace.rooftops);
      expect(level.id, Levels.youHoldTheDark.id);
    });

    test('every place has a name in both languages', () {
      for (final place in LevelPlace.values) {
        for (final lang in Lang.values) {
          expect(Words(lang).placeName(place), isNotEmpty);
        }
      }
      expect(
        Words(Lang.ar).placeName(LevelPlace.stairwell),
        isNot(Words(Lang.en).placeName(LevelPlace.stairwell)),
      );
    });
  });

  group('the scene', () {
    testWithGame<LevelGame>(
      'a stairwell level stands in the stairwell',
      () => LevelGame(
        levels: Levels.campaign,
        startAt: firstStair,
        inputs: [ScriptedInput()],
        look: LevelLook.silhouette,
      ),
      (game) async {
        await game.ready();
        expect(game.shownPlace, LevelPlace.stairwell);
        expect(game.camera.backdrop.children.whereType<StairwellWall>(), [
          isA<StairwellWall>(),
        ]);
        expect(game.camera.backdrop.children.whereType<SkyBackdrop>(), isEmpty);
        expect(game.world.children.whereType<StairFlights>(), hasLength(1));
        expect(game.world.children.whereType<LandingWall>(), hasLength(1));
      },
    );

    testWithGame<LevelGame>(
      'the stairwell draws, and draws the same thing twice',
      () => LevelGame(
        levels: Levels.campaign,
        startAt: firstStair,
        inputs: [ScriptedInput()],
        look: LevelLook.silhouette,
      ),
      (game) async {
        await game.ready();
        // Nothing in it may be random or read the clock: the clips are
        // rendered from the game frame by frame and have to come out the same
        // every time. Two recordings of the same frame are compared op for op
        // through their pixels.
        Future<List<int>> frame() async {
          final recorder = PictureRecorder();
          game.render(Canvas(recorder));
          final image = await recorder.endRecording().toImage(200, 120);
          final bytes = await image.toByteData();
          image.dispose();
          return bytes!.buffer.asUint8List().toList();
        }

        final first = await frame();
        final second = await frame();
        expect(first, second);
      },
    );

    testWithGame<LevelGame>(
      'the bench is grey boxes wherever a level says it is',
      () =>
          LevelGame(levels: [Levels.youHoldTheDark], inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        expect(game.shownPlace, isNull);
        expect(game.world.children.whereType<StairFlights>(), isEmpty);
      },
    );
  });

  group('the card between chapters', () {
    /// Plays the level before the stairwell to its end, then steps frames
    /// until the level changes, returning what the fade said on the way.
    Future<({double heldFor, double darkAtSwap, String? name})> crossInto(
      LevelGame game,
    ) async {
      final source = game.input.sources.first as ScriptedInput;
      final run = Playthrough(game, source)
        ..play(game.level.solution, stopWhenComplete: true);
      expect(game.completed, isTrue, reason: run.where);

      final startedOn = game.levelIndex;
      var held = 0.0;
      String? name;
      double? darkAtSwap;
      for (var frame = 0; frame < 600 && darkAtSwap == null; frame++) {
        source.next = InputIntent.none;
        game.update(dt);
        if (game.fade.darkness >= 1) held += dt;
        name ??= game.fade.chapter;
        if (game.levelIndex != startedOn) darkAtSwap = game.fade.darkness;
      }
      expect(darkAtSwap, isNotNull, reason: 'the level never advanced');
      return (heldFor: held, darkAtSwap: darkAtSwap!, name: name);
    }

    testWithGame<LevelGame>(
      'walking into the stairwell is the dark with its name in it',
      () => LevelGame(
        levels: Levels.campaign,
        startAt: firstStair - 1,
        inputs: [ScriptedInput()],
        look: LevelLook.silhouette,
      ),
      (game) async {
        await game.ready();
        expect(game.shownPlace, LevelPlace.rooftops);

        final crossing = await crossInto(game);
        expect(crossing.name, 'بيت السلّم');
        expect(crossing.darkAtSwap, 1);
        expect(
          crossing.heldFor,
          greaterThanOrEqualTo(
            LevelFade.chapterSeconds - LevelFade.coverSeconds,
          ),
          reason: 'long enough for the name to be read',
        );
        expect(game.fade.nameShowing, 1, reason: 'fully up before the swap');

        // And then the new place comes up through it.
        for (var frame = 0; frame < 120; frame++) {
          game.update(dt);
          await Future<void>.value();
        }
        expect(game.fade.darkness, 0);
        expect(game.fade.chapter, isNull);
        expect(game.shownPlace, LevelPlace.stairwell);
        expect(game.level.id, Levels.youHoldTheDark.id);
      },
    );

    testWithGame<LevelGame>(
      'the card speaks the game\'s language',
      () => LevelGame(
        levels: Levels.campaign,
        startAt: firstStair - 1,
        inputs: [ScriptedInput()],
        look: LevelLook.silhouette,
      )..lang = Lang.en,
      (game) async {
        await game.ready();
        expect((await crossInto(game)).name, 'The stairwell');
      },
    );

    testWithGame<LevelGame>(
      'two levels in one place have no card between them',
      () => LevelGame(
        levels: Levels.campaign,
        inputs: [ScriptedInput()],
        look: LevelLook.silhouette,
      ),
      (game) async {
        await game.ready();
        final crossing = await crossInto(game);
        expect(crossing.name, isNull);
        expect(crossing.heldFor, lessThan(LevelFade.chapterSeconds / 2));
      },
    );

    testWithGame<LevelGame>(
      'the bench never puts a card up',
      () => LevelGame(
        levels: Levels.campaign,
        startAt: firstStair - 1,
        inputs: [ScriptedInput()],
      ),
      (game) async {
        await game.ready();
        final crossing = await crossInto(game);
        expect(crossing.name, isNull);
        expect(crossing.heldFor, lessThan(LevelFade.chapterSeconds / 2));
      },
    );

    testWithGame<LevelGame>(
      'starting over on the card does not leave the screen black',
      () => LevelGame(
        levels: Levels.campaign,
        startAt: firstStair - 1,
        inputs: [ScriptedInput()],
        look: LevelLook.silhouette,
      ),
      (game) async {
        await game.ready();
        final source = game.input.sources.first as ScriptedInput;
        Playthrough(
          game,
          source,
        ).play(game.level.solution, stopWhenComplete: true);
        for (var frame = 0; frame < 90 && game.fade.chapter == null; frame++) {
          source.next = InputIntent.none;
          game.update(dt);
        }
        expect(game.fade.chapter, isNotNull, reason: 'the card never came up');

        game.retry();
        for (var frame = 0; frame < 240; frame++) {
          source.next = InputIntent.none;
          game.update(dt);
          await Future<void>.value();
        }
        expect(game.fade.darkness, 0);
        expect(game.levelIndex, firstStair - 1);
      },
    );
  });

  group('the level list', () {
    test(
      'a heading before the first level of each chapter, and nowhere else',
      () {
        final entries = LevelSelect.chapters(Levels.campaign);
        final headings = [
          for (final (i, (place, index)) in entries.indexed)
            if (index == null) (i, place),
        ];
        expect(headings, [
          (0, LevelPlace.rooftops),
          // Every level before it, plus the first heading.
          (firstStair + 1, LevelPlace.stairwell),
        ]);
        // Every level still there, once, in order: the numbers carry on.
        expect([
          for (final (_, index) in entries) ?index,
        ], List.generate(Levels.campaign.length, (i) => i));
      },
    );

    test('a list in one place has no headings at all', () {
      final entries = LevelSelect.chapters(Levels.bench);
      expect(entries.where((e) => e.$2 == null), isEmpty);
    });
  });
}
