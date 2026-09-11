import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/game/probe_walker.dart';
import 'package:waraya/game/sky_backdrop.dart';
import 'package:waraya/game/waraya_game.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/input/input_controller.dart';

class _ScriptedSource implements InputSource {
  @override
  String get label => 'scripted';

  @override
  bool hasBeenUsed = true;

  InputIntent next = InputIntent.none;

  @override
  InputIntent poll() => next;
}

void main() {
  // The game loads image assets now, and the asset bundle needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WarayaGame viewport', () {
    // flame_test sizes the game at 800x600.
    testWithGame<WarayaGame>(
      'shows exactly the configured world height',
      WarayaGame.new,
      (game) async {
        await game.ready();
        expect(
          game.camera.visibleWorldRect.height,
          closeTo(WarayaConfig.worldHeight, 0.01),
        );
      },
    );

    testWithGame<WarayaGame>(
      'widens rather than letterboxing',
      WarayaGame.new,
      (game) async {
        await game.ready();
        final narrow = game.camera.visibleWorldRect.width;

        game.onGameResize(Vector2(1600, 600));
        final wide = game.camera.visibleWorldRect.width;

        expect(wide, greaterThan(narrow));
        // Height stays pinned no matter how wide the device is.
        expect(
          game.camera.visibleWorldRect.height,
          closeTo(WarayaConfig.worldHeight, 0.01),
        );
      },
    );

    testWithGame<WarayaGame>(
      'sky sits behind the world, not over it',
      WarayaGame.new,
      (game) async {
        await game.ready();
        // The camera renders backdrop -> world -> viewport. A sky in the
        // viewport would hide the entire scene, which is easy to reintroduce
        // and invisible in a unit test that only checks the tree exists.
        expect(
          game.camera.backdrop.children.whereType<SkyBackdrop>(),
          hasLength(1),
        );
        expect(game.camera.viewport.children.whereType<SkyBackdrop>(), isEmpty);
      },
    );

    testWithGame<WarayaGame>('camera follows the walker', WarayaGame.new, (
      game,
    ) async {
      await game.ready();
      expect(game.walker.isMounted, isTrue);
      expect(game.camera.viewfinder.position.x, closeTo(game.walker.x, 0.01));
    });

    testWithGame<WarayaGame>(
      'camera tracks horizontally only',
      WarayaGame.new,
      (game) async {
        await game.ready();
        final horizonOnScreen = game.camera.visibleWorldRect.top;

        // Shove the walker off the horizon the way a jump eventually will.
        game.walker.position.y -= 300;
        game.update(0.016);
        game.update(0.016);

        expect(
          game.camera.viewfinder.position.y,
          closeTo(WarayaConfig.worldHeight / 2, 0.01),
        );
        expect(
          game.camera.visibleWorldRect.top,
          closeTo(horizonOnScreen, 0.01),
        );
      },
    );

    testWithGame<WarayaGame>(
      'the horizon is on screen at rest',
      WarayaGame.new,
      (game) async {
        await game.ready();
        final view = game.camera.visibleWorldRect;
        expect(WarayaConfig.horizonY, greaterThan(view.top));
        expect(WarayaConfig.horizonY, lessThan(view.bottom));
      },
    );
  });

  group('ProbeWalker', () {
    test('moves along the intent axis and records facing', () {
      final source = _ScriptedSource();
      final input = InputController([source]);
      final walker = ProbeWalker(input: input);
      final startX = walker.x;

      source.next = const InputIntent(moveAxis: 1);
      input.refresh();
      walker.update(0.5);

      expect(walker.x, closeTo(startX + WarayaConfig.walkSpeed * 0.5, 0.01));
      expect(walker.facing, 1);

      source.next = const InputIntent(moveAxis: -1);
      input.refresh();
      walker.update(0.5);

      expect(walker.x, closeTo(startX, 0.01));
      expect(walker.facing, -1);
    });

    test('jumps, rises, and lands back on the horizon', () {
      final source = _ScriptedSource();
      final input = InputController([source]);
      final walker = ProbeWalker(input: input);
      expect(walker.isGrounded, isTrue);

      source.next = const InputIntent(jump: true);
      input.refresh();
      walker.update(1 / 60);
      expect(walker.verticalVelocity, lessThan(0), reason: 'should be rising');
      expect(walker.y, lessThan(WarayaConfig.horizonY));
      expect(walker.isGrounded, isFalse);

      // Run a second of frames; the arc has to come back down and settle.
      source.next = InputIntent.none;
      var apex = walker.y;
      for (var i = 0; i < 60; i++) {
        input.refresh();
        walker.update(1 / 60);
        if (walker.y < apex) apex = walker.y;
      }

      expect(
        WarayaConfig.horizonY - apex,
        greaterThan(100),
        reason: 'should clear about its own height',
      );
      expect(walker.y, closeTo(WarayaConfig.horizonY, 0.001));
      expect(walker.verticalVelocity, 0);
      expect(walker.isGrounded, isTrue);
    });

    test('cannot jump again in mid-air', () {
      final source = _ScriptedSource();
      final input = InputController([source]);
      final walker = ProbeWalker(input: input);

      source.next = const InputIntent(jump: true);
      input.refresh();
      walker.update(1 / 60);
      final risingVelocity = walker.verticalVelocity;

      // Hold jump while airborne: it must not re-launch.
      for (var i = 0; i < 5; i++) {
        source.next = const InputIntent(jump: true);
        input.refresh();
        walker.update(1 / 60);
      }
      expect(walker.verticalVelocity, greaterThan(risingVelocity));
    });

    test('stands still with no intent', () {
      final input = InputController([_ScriptedSource()]);
      final walker = ProbeWalker(input: input);
      final startX = walker.x;

      input.refresh();
      walker.update(1.0);

      expect(walker.x, startX);
      // Vector2 stores float32, so the clamped value is not bit-identical to
      // the double it was assigned.
      expect(
        walker.y,
        closeTo(WarayaConfig.horizonY, 0.001),
        reason: 'gravity keeps it down',
      );
    });
  });
}
