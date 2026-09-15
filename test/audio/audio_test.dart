import 'dart:math';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/audio/sfx.dart';
import 'package:waraya/audio/step_detector.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/lab/lab_scene.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/level_game.dart';

/// An [AudioOut] that writes down what it was asked to play.
class RecordingAudio implements AudioOut {
  final List<(Sfx, double)> played = [];
  int preloads = 0;

  List<Sfx> get sounds => [for (final entry in played) entry.$1];

  @override
  Future<void> preload() async => preloads++;

  @override
  void play(Sfx sfx, {double volume = 1}) => played.add((sfx, volume));

  void clear() => played.clear();
}

const double _dt = 1 / 60;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StepDetector', () {
    test('a footfall every half stride, alternating variants', () {
      final detector = StepDetector();
      final heard = <Sfx>[];
      // Two full strides, walked in small increments.
      for (var i = 0; i <= 200; i++) {
        final sfx = detector.advance(
          (i / 200 * 4 * pi) % (2 * pi),
          moving: true,
          grounded: true,
        );
        if (sfx != null) heard.add(sfx);
      }

      expect(heard, hasLength(4), reason: 'two strides, four feet');
      expect(heard.toSet(), hasLength(greaterThan(1)), reason: 'not one sound');
    });

    test('silent when standing still or in the air', () {
      final detector = StepDetector();
      detector.advance(0, moving: true, grounded: true);

      expect(detector.advance(pi + 0.1, moving: false, grounded: true), isNull);
      expect(detector.advance(0.1, moving: true, grounded: false), isNull);
    });

    test('catches the footfall that lands on the wrap', () {
      final detector = StepDetector();
      detector.advance(2 * pi - 0.05, moving: true, grounded: true);

      // 6.23 -> 0.02 is a step, and a naive "did it pass pi" test misses it.
      expect(detector.advance(0.02, moving: true, grounded: true), isNotNull);
    });

    test('reset forgets where the feet were', () {
      final detector = StepDetector()
        ..advance(0, moving: true, grounded: true)
        ..reset();
      expect(detector.advance(pi + 0.1, moving: true, grounded: true), isNull);
    });
  });

  group('SilentAudio', () {
    test('swallows everything without complaint', () async {
      const audio = SilentAudio();
      await audio.preload();
      audio.play(Sfx.jump, volume: 1);
    });
  });

  group('the lab makes the right noises', () {
    late RecordingAudio audio;

    LevelGame build() {
      audio = RecordingAudio();
      final level = Level(
        id: 'test',
        name: Levels.lab.name,
        teaches: Levels.lab.teaches,
        delaySeconds: 1,
        spawnX: Levels.lab.spawnX,
        floorTop: Levels.lab.floorTop,
        blocks: Levels.lab.blocks,
        plates: Levels.lab.plates,
        doors: Levels.lab.doors,
        goal: Levels.lab.goal,
        markers: Levels.lab.markers,
      );
      return LevelGame(levels: [level], audio: audio);
    }

    testWithGame<LevelGame>('loads its sounds up front', build, (game) async {
      await game.ready();
      expect(audio.preloads, 1);
    });

    testWithGame<LevelGame>('a hard landing is louder than a soft one', build, (
      game,
    ) async {
      await game.ready();
      for (var i = 0; i < 10; i++) {
        game.update(_dt);
      }
      audio.clear();

      // A long drop.
      game.player.position.setValues(150, 150);
      for (var i = 0; i < 60; i++) {
        game.update(_dt);
      }
      final hard = audio.played.firstWhere((e) => e.$1 == Sfx.land).$2;

      game.reload();
      audio.clear();
      // A short one.
      game.player.position.setValues(150, LabScene.floorTop - 130);
      for (var i = 0; i < 60; i++) {
        game.update(_dt);
      }
      final soft = audio.played.firstWhere((e) => e.$1 == Sfx.land).$2;

      expect(hard, greaterThan(soft));
      expect(hard, lessThanOrEqualTo(1));
    });

    testWithGame<LevelGame>('a gentle step down is not a thud', build, (
      game,
    ) async {
      await game.ready();
      for (var i = 0; i < 30; i++) {
        game.update(_dt);
      }
      expect(audio.sounds, isNot(contains(Sfx.land)));
    });

    testWithGame<LevelGame>('the plate clicks and the door answers', build, (
      game,
    ) async {
      await game.ready();
      // Stand on the plate, then leave. A second later the shadow arrives and
      // stands on it, so the plate clicks and the door answers — twice each,
      // in fact: once for us and once for our shadow.
      for (var i = 0; i < 40; i++) {
        game.player.position.x = LabScene.plate.center.dx;
        game.update(_dt);
      }
      expect(audio.sounds.where((s) => s == Sfx.plate), hasLength(1));
      expect(audio.sounds.where((s) => s == Sfx.door), hasLength(1));

      audio.clear();
      for (var i = 0; i < 100; i++) {
        game.player.position.x = 0;
        game.update(_dt);
      }

      expect(audio.sounds, contains(Sfx.plate));
      expect(audio.sounds, contains(Sfx.door));
    });

    testWithGame<LevelGame>(
      'footsteps follow the legs, not the position',
      build,
      (game) async {
        await game.ready();
        for (var i = 0; i < 30; i++) {
          game.update(_dt);
        }
        audio.clear();

        // Teleported a long way, a frame at a time, with the legs never moving:
        // the sound is driven by the stride phase, so a body that is being
        // dragged does not manufacture footsteps out of thin air.
        for (var i = 0; i < 120; i++) {
          game.player.position.x += WarayaConfig.walkSpeed * _dt;
          game.update(_dt);
        }

        expect(audio.sounds.where(Sfx.steps.contains), isEmpty);
      },
    );
  });
}
