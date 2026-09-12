import 'dart:ui';

import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/lab/lab_scene.dart';
import 'package:waraya/lab/lab_settings.dart';
import 'package:waraya/lab/shadow_lab_game.dart';

const double _dt = 1 / 60;

/// Runs [frames] game frames, optionally parking the player at [x] first so
/// the recorder sees a chosen path. Returns what the player's x was at the
/// moment each frame was recorded.
List<double> run(ShadowLabGame game, int frames, {double? x, double? crouch}) {
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

  ShadowLabGame gameWith({
    double delaySeconds = 1,
    bool solid = true,
    bool kills = false,
  }) {
    final settings = LabSettings()
      ..delaySeconds = delaySeconds
      ..shadowIsSolid = solid
      ..shadowKills = kills;
    return ShadowLabGame(settings: settings);
  }

  group('ShadowLabGame', () {
    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
      'the shadow holds the plate down and the door opens',
      gameWith,
      (game) async {
        await game.ready();
        // Test 1, end to end: stand on the plate, walk away, and have your own
        // past press it for you.
        run(game, 60, x: LabScene.plate.center.dx);
        expect(game.plate.pressedByPlayer, isTrue);
        expect(game.plate.pressedByShadow, isFalse);

        // Leave, and wait out the one-second delay somewhere else entirely.
        run(game, 20, x: 0);

        expect(game.plate.pressedByPlayer, isFalse);
        expect(game.plate.pressedByShadow, isTrue);
        expect(game.door.wantsOpen, isTrue);

        // And the door actually travels far enough to walk through.
        run(game, 25, x: 0);
        expect(game.door.isSolid, isFalse);
      },
    );

    testWithGame<ShadowLabGame>(
      'a solid shadow is something to stand on, and only from above',
      gameWith,
      (game) async {
        await game.ready();
        run(game, 90, x: 150);

        expect(game.shadow.isActive, isTrue);
        // Drop the player onto the shadow's head.
        game.player.position.setValues(
          150,
          game.shadow.y - game.shadow.size.y - 40,
        );
        game.player.verticalVelocity = 0;
        run(game, 30, x: 150);

        expect(game.player.isOnShadow, isTrue);
        expect(game.player.y, closeTo(game.shadow.y - game.shadow.size.y, 1));
      },
    );

    testWithGame<ShadowLabGame>(
      'with solidity off the shadow is scenery',
      () => gameWith(solid: false),
      (game) async {
        await game.ready();
        run(game, 90, x: 150);
        game.player.position.setValues(
          150,
          game.shadow.y - game.shadow.size.y - 40,
        );
        game.player.verticalVelocity = 0;
        run(game, 30, x: 150);

        expect(game.player.isOnShadow, isFalse);
        expect(game.player.y, closeTo(LabScene.floorTop, 0.001));
      },
    );

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>('reload puts everything back', gameWith, (
      game,
    ) async {
      await game.ready();
      run(game, 90, x: LabScene.plate.center.dx);
      expect(game.shadow.isActive, isTrue);
      expect(game.plate.isPressed, isTrue);

      game.reload();
      game.update(_dt);

      expect(game.reloads, 1);
      expect(game.player.x, LabScene.spawnX);
      expect(game.shadow.isActive, isFalse);
      expect(game.door.openFraction, 0);
      expect(game.doorGoal.reached, isFalse);
      expect(game.ledgeGoal.reached, isFalse);
    });

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
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

    testWithGame<ShadowLabGame>(
      'the viewport keeps the world height pinned, like the real game',
      gameWith,
      (game) async {
        await game.ready();
        expect(game.camera.visibleWorldRect.height, closeTo(720, 0.01));
      },
    );
  });
}
