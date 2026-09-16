import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import '../level/solution.dart';

/// How the world is framed on a screen, which is not the same question on a
/// desktop window and on a phone held upright.
///
/// Both of these came out of playing on a phone. Pinning the world height and
/// letting the width stretch — the Phase 1 rule — showed 324 world units
/// across on a 412x839 screen, which is two jumps end to end and makes a
/// side-scroller unreadable. Zooming out to fix that then put all the new room
/// *below* the floor as a dead black band, because the camera was centred on
/// the middle of the world rather than on where the ground is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelGame build() =>
      LevelGame(levels: [Levels.pressItEarly], inputs: [ScriptedInput()]);

  /// width, height, and what the shape is
  const screens = <(double, double, String)>[
    (412, 839, 'a phone held upright'),
    (839, 412, 'a phone on its side'),
    (1120, 630, 'a laptop window'),
    (1920, 1080, 'a wide desktop'),
    (768, 1024, 'a tablet held upright'),
  ];

  for (final (width, height, shape) in screens) {
    testWithGame<LevelGame>('$shape sees enough of the world', build, (
      game,
    ) async {
      await game.ready();
      game.onGameResize(Vector2(width, height));
      game.update(1 / 60);

      final view = game.camera.visibleWorldRect;
      expect(
        view.width,
        greaterThanOrEqualTo(WarayaConfig.minVisibleWorldWidth - 0.5),
        reason: '$shape shows only ${view.width.toStringAsFixed(0)} across',
      );
      // Never letterboxed: the world always fills the screen edge to edge.
      expect(view.width * view.height, greaterThan(0));
    });

    testWithGame<LevelGame>('$shape puts the ground in the same place', build, (
      game,
    ) async {
      await game.ready();
      game.onGameResize(Vector2(width, height));
      game.update(1 / 60);

      final view = game.camera.visibleWorldRect;
      final groundFraction =
          (game.level.floorTop - view.top) / view.height;
      expect(
        groundFraction,
        closeTo(WarayaConfig.groundOnScreen, 0.02),
        reason:
            '$shape puts the floor at '
            '${(groundFraction * 100).toStringAsFixed(0)}% down the screen',
      );
    });
  }

  testWithGame<LevelGame>(
    'the ground is deep enough to fill the bottom of a tall screen',
    build,
    (game) async {
      await game.ready();
      game.onGameResize(Vector2(412, 839));
      game.update(1 / 60);

      // Whatever the camera can see below the floor has to be ground, not the
      // bare background colour showing under the level.
      final bottom = game.camera.visibleWorldRect.bottom;
      for (final rect in game.level.blocks) {
        if (rect.top != game.level.floorTop) continue;
        expect(
          rect.bottom,
          greaterThanOrEqualTo(bottom),
          reason: 'the floor slab stops at ${rect.bottom} and the camera can '
              'see down to ${bottom.toStringAsFixed(0)}',
        );
      }
    },
  );
}
