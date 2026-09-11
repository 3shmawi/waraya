import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../input/input.dart';
import '../input/input_controller.dart';
import '../input/keyboard_input_source.dart';
import '../input/touch_input_source.dart';
import '../ui/debug_hud.dart';
import 'config.dart';
import 'placeholder_village.dart';
import 'probe_walker.dart';
import 'sky_backdrop.dart';

/// Phase 1 skeleton: one scene, one walker, no gameplay.
///
/// Two decisions from the plan are baked in here and shouldn't be revisited
/// casually:
///
/// 1. **[MaxViewport] with a fixed world height.** The default viewport takes
///    the whole canvas and `onGameResize` sets the zoom so exactly
///    [WarayaConfig.worldHeight] world units are visible vertically. Tall
///    phones see less width, wide desktops see more, and no device gets
///    letterbox bars. Art must be authored wider than the widest viewport.
///
/// 2. **All input arrives as [InputIntent].** Nothing below this class asks
///    what platform it is on.
class WarayaGame extends FlameGame with HasKeyboardHandlerComponents {
  late final InputController input;
  late final ProbeWalker walker;

  @override
  Color backgroundColor() => const Color(0xFF1B2A4A);

  @override
  Future<void> onLoad() async {
    final keyboard = KeyboardInputSource();
    final touch = TouchInputSource();
    input = InputController([keyboard, touch]);

    // The controller itself is not a source of events; the two backends are.
    await add(input);
    await add(keyboard);

    // The sky goes in the backdrop, not the viewport: the camera renders
    // backdrop -> world -> viewport, so a viewport sky would paint over the
    // whole scene.
    await camera.backdrop.add(SkyBackdrop());
    await camera.viewport.add(touch);
    await camera.viewport.add(
      DebugHud(input: input, visibleWorldRect: () => camera.visibleWorldRect),
    );

    // Four depth bands standing in for Friday 2's parallax layers, plus the
    // surface under them. Values run light-to-dark with distance so the depth
    // reads before any real parallax motion exists.
    await world.addAll([
      PlaceholderTreeline(
        color: const Color(0xFF8C6472),
        seed: 1,
        priority: -30,
      ),
      PlaceholderVillageRow(
        color: const Color(0xFF5E4552),
        seed: 2,
        priority: -25,
      ),
      PlaceholderPalms(color: const Color(0xFF3A2B3B), seed: 3, priority: -20),
      PlaceholderGround(color: const Color(0xFF16101E), priority: -15),
      PlaceholderPoles(color: const Color(0xFF120D18), seed: 4, priority: -8),
    ]);

    walker = ProbeWalker(input: input);
    await world.add(walker);
    // Side-scroller framing: the camera tracks the walker horizontally only,
    // and its vertical position is pinned so the horizon stays where the art
    // was composed for it instead of riding up and down with the character.
    camera.viewfinder.position = Vector2(0, WarayaConfig.worldHeight / 2);
    camera.follow(walker, horizontalOnly: true);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Fix the world height; the width is whatever the device gives us.
    if (size.y > 0) {
      camera.viewfinder.zoom = size.y / WarayaConfig.worldHeight;
    }
  }

  @override
  void update(double dt) {
    // Refresh the merged intent once, before anything consumes it, so every
    // component in this frame sees identical input.
    input.refresh();
    super.update(dt);
  }
}
