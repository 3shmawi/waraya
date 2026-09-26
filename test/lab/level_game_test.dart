import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/lab/lab_scene.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/level_game.dart';

const double _dt = 1 / 60;

/// Runs [frames] game frames, optionally parking the player at [x] first so
/// the recorder sees a chosen path. Returns what the player's x was at the
/// moment each frame was recorded.
List<double> run(LevelGame game, int frames, {double? x, double? crouch}) {
  final history = <double>[];
  for (var i = 0; i < frames; i++) {
    if (x != null) game.player.position.x = x;
    if (crouch != null) game.player.crouch = crouch;
    // The recorder samples at the top of update, before the world moves.
    history.add(game.player.x);
    game.update(_dt);
  }
  return history;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame gameWith({
    double delaySeconds = 1,
    bool solid = true,
    bool kills = false,
  }) {
    // A copy of the bench with the test's numbers: the level seeds the
    // settings on load, so overriding them has to happen in the level.
    final level = Level(
      id: 'test',
      name: Levels.lab.name,
      teaches: Levels.lab.teaches,
      delaySeconds: delaySeconds,
      spawnX: Levels.lab.spawnX,
      floorTop: Levels.lab.floorTop,
      blocks: Levels.lab.blocks,
      plates: Levels.lab.plates,
      doors: Levels.lab.doors,
      goal: Levels.lab.goal,
      markers: Levels.lab.markers,
      shadowIsSolid: solid,
      shadowKills: kills,
    );
    return LevelGame(levels: [level]);
  }

  group('LevelGame', () {
    testWithGame<LevelGame>(
      'the shadow does not exist until the delay has passed',
      gameWith,
      (game) async {
        await game.ready();
        const delayTicks = 60;

        run(game, delayTicks, x: 120);
        expect(game.shadow.isActive, isFalse);
        expect(game.recorder.secondsUntilPlaying, closeTo(0, 0.02));

        run(game, 1, x: 120);
        expect(game.shadow.isActive, isTrue);
      },
    );

    testWithGame<LevelGame>(
      'the shadow walks the path the player walked, to the unit',
      gameWith,
      (game) async {
        await game.ready();
        const delayTicks = 60;

        // A moving path, so a shadow that merely sat still would fail.
        final history = <double>[];
        for (var i = 0; i < 200; i++) {
          game.player.position.x = i * 3.7;
          history.add(game.player.x);
          game.update(_dt);
          if (i >= delayTicks) {
            expect(game.shadow.x, history[i - delayTicks], reason: 'frame $i');
          }
        }
      },
    );

    testWithGame<LevelGame>(
      'the shadow holds the plate down and the door opens',
      gameWith,
      (game) async {
        await game.ready();
        // Test 1, end to end: stand on the plate, walk away, and have your own
        // past press it for you.
        run(game, 60, x: LabScene.plate.center.dx);
        expect(game.plates.first.pressedByPlayer, isTrue);
        expect(game.plates.first.pressedByShadow, isFalse);

        // Leave, and wait out the one-second delay somewhere else entirely.
        run(game, 20, x: 0);

        expect(game.plates.first.pressedByPlayer, isFalse);
        expect(game.plates.first.pressedByShadow, isTrue);
        expect(game.doors.first.wantsOpen, isTrue);

        // And the door actually travels far enough to walk through.
        run(game, 25, x: 0);
        expect(game.doors.first.isSolid, isFalse);
      },
    );

    testWithGame<LevelGame>(
      'a ducked shadow is something to stand on, and only from above',
      gameWith,
      (game) async {
        await game.ready();
        // Ducked, because that is the game's rule: a body that walked past
        // standing up is not a floor. The bench plays the same `LevelGame`
        // the campaign does and is not allowed a private version of it.
        run(game, 90, x: 150, crouch: 1);

        expect(game.shadow.isActive, isTrue);
        // Drop the player onto the shadow's head. `bounds` rather than
        // `size.y`: a ducked body is shorter, and the head is wherever the
        // recorded pose put it.
        final head = game.shadow.bounds.top;
        game.player.position.setValues(150, head - 40);
        game.player.locomotion.reset();
        run(game, 30, x: 150, crouch: 1);

        expect(game.player.isOnShadow, isTrue);
        expect(game.player.y, closeTo(head, 1));
      },
    );

    testWithGame<LevelGame>(
      'with solidity off the shadow is scenery',
      () => gameWith(solid: false),
      (game) async {
        await game.ready();
        // Ducked, so the only thing keeping the player off it is the flag.
        // Walking past standing up would pass this test with the flag on.
        run(game, 90, x: 150, crouch: 1);
        game.player.position.setValues(150, game.shadow.bounds.top - 40);
        game.player.locomotion.reset();
        run(game, 30, x: 150, crouch: 1);

        expect(game.player.isOnShadow, isFalse);
        expect(game.player.y, closeTo(LabScene.floorTop, 0.001));
      },
    );

    testWithGame<LevelGame>(
      'shadowKills reloads the scene on contact',
      () => gameWith(kills: true),
      (game) async {
        await game.ready();
        // Stand still: after the delay, your own past walks into you.
        run(game, 61, x: 200);

        expect(game.reloads, 1);
        expect(game.player.x, LabScene.spawnX);
        expect(game.shadow.isActive, isFalse, reason: 'history dies with you');
        expect(game.recorder.pending, isEmpty);
      },
    );

    testWithGame<LevelGame>('reload puts everything back', gameWith, (
      game,
    ) async {
      await game.ready();
      run(game, 90, x: LabScene.plate.center.dx);
      expect(game.shadow.isActive, isTrue);
      expect(game.plates.first.isPressed, isTrue);

      game.reload();
      game.update(_dt);

      expect(game.reloads, 1);
      expect(game.player.x, LabScene.spawnX);
      expect(game.shadow.isActive, isFalse);
      expect(game.doors.first.openFraction, 0);
      expect(game.goals.first.reached, isFalse);
      expect(game.goals.last.reached, isFalse);
    });

    testWithGame<LevelGame>(
      'the delay slider takes effect while the game runs',
      gameWith,
      (game) async {
        await game.ready();
        run(game, 90, x: 300);
        expect(game.shadow.isActive, isTrue);

        game.settings.delaySeconds = 6;
        run(game, 10, x: 300);
        expect(game.recorder.delayTicks, 360);
        expect(
          game.recorder.secondsUntilPlaying,
          greaterThan(0),
          reason: 'a longer delay means the shadow waits for the buffer',
        );
      },
    );

    testWithGame<LevelGame>(
      'a monstrous first frame does not drop the player out of the world',
      gameWith,
      (game) async {
        await game.ready();
        // What a real browser hands you after a slow load. Integrated in one
        // step, gravity would put the player thousands of units below a floor
        // that an overlap test can no longer see them hitting.
        game.update(10);
        run(game, 5);

        expect(game.player.y, closeTo(LabScene.floorTop, 0.001));
        expect(game.player.isGrounded, isTrue);
      },
    );

    testWithGame<LevelGame>(
      'walking off the end of the floor puts you back, not nowhere',
      gameWith,
      (game) async {
        await game.ready();
        game.player.position.setValues(LabScene.floor.left - 200, 400);
        run(game, 60);

        expect(game.reloads, greaterThanOrEqualTo(1));
        expect(game.player.x, LabScene.spawnX);
      },
    );

    testWithGame<LevelGame>(
      'the shadow replays a crouch, box and all',
      gameWith,
      (game) async {
        await game.ready();
        run(game, 90, x: 150);
        final standing = game.shadow.bounds.height;

        // Spend a moment folded up. The shadow is a second behind, so it is
        // still standing when the player has already ducked.
        run(game, 40, x: 150, crouch: 1);
        expect(game.shadow.bounds.height, standing, reason: 'not yet');

        // Stand back up and wait for the crouch to come round.
        run(game, 40, x: 150);

        expect(game.shadow.snapshot!.crouch, 1);
        expect(
          game.shadow.bounds.height,
          closeTo(standing * WarayaConfig.crouchHeightFactor, 0.001),
        );
        expect(
          game.shadow.bounds.bottom,
          closeTo(LabScene.floorTop, 0.001),
          reason: 'a crouched shadow shrinks from the head, not the feet',
        );
      },
    );

    testWithGame<LevelGame>(
      'the shadow is smoothed between ticks without moving its hitbox',
      gameWith,
      (game) async {
        await game.ready();
        // Walk it along so successive snapshots differ.
        for (var i = 0; i < 90; i++) {
          game.player.position.x = i * 3.0;
          game.update(_dt);
        }
        final box = game.shadow.bounds;

        game.shadow.alpha = 0;
        final lagging = game.shadow.renderOffset;
        game.shadow.alpha = 1;
        final caughtUp = game.shadow.renderOffset;

        expect(lagging.dx, isNot(0), reason: 'start of a tick: one step back');
        expect(caughtUp.dx, 0, reason: 'end of a tick: on the snapshot');
        expect(
          game.shadow.bounds,
          box,
          reason: 'smoothing is a drawing trick; collision stays on the tick',
        );
      },
    );

    testWithGame<LevelGame>(
      'a hard landing shakes the camera, a step down does not',
      gameWith,
      (game) async {
        await game.ready();
        run(game, 10);
        expect(game.shake.isShaking, isFalse);

        // Drop the player from most of the screen height.
        game.player.position.setValues(150, 200);
        run(game, 60, x: 150);

        expect(game.shake.isShaking, isTrue);

        // And it dies away rather than rattling forever.
        run(game, 90, x: 150);
        expect(game.shake.isShaking, isFalse);
      },
    );

    testWithGame<LevelGame>(
      'draws without blowing up, shadow and trail included',
      () => gameWith(),
      (game) async {
        await game.ready();
        game.settings.showTrail = true;
        run(game, 90, x: 150);
        expect(game.shadow.isActive, isTrue);

        // Renders nothing to look at, but does walk every paint path in the
        // scene: the translucent shadow layer, the trail, the grey boxes and
        // the HUD text. A crash in any of them is invisible to the logic
        // tests above.
        final recorder = PictureRecorder();
        game.render(Canvas(recorder));
        recorder.endRecording().dispose();
      },
    );

    testWithGame<LevelGame>(
      'the viewport keeps the world height pinned, like the real game',
      gameWith,
      (game) async {
        await game.ready();
        expect(game.camera.visibleWorldRect.height, closeTo(720, 0.01));
      },
    );
  });
}
