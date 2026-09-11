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
import 'ground.dart';
import 'photo_band.dart';
import 'power_line.dart';
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

    // The photographed bands, far to near. Depth drives the parallax: 0 is
    // infinitely distant, 1 sits in the world plane with the character. The
    // far band is the same treeline as the mid one, hazed and scaled down --
    // aerial perspective from a single source frame.
    //
    // No palms yet. Every palm in art/source is partly occluded by an awning,
    // a tarp or a water tower, and those are as dark as the tree, so no
    // rectangular crop separates them. Unblocking it needs either one frame of
    // a palm standing clear against sky, or a hand mask.
    final far = await images.load('layer_far_treeline.webp');
    final mid = await images.load('layer_mid_treeline.webp');

    Rect view() => camera.visibleWorldRect;

    await world.addAll([
      PhotoBand(
        image: far,
        depth: 0.15,
        heightUnits: 120,
        // Above the mid band's top edge, or it is hidden behind it entirely.
        bottomY: WarayaConfig.horizonY - 96,
        visibleWorldRect: view,
        priority: -40,
      ),
      PhotoBand(
        image: mid,
        depth: 0.45,
        heightUnits: 230,
        bottomY: WarayaConfig.horizonY + 4,
        visibleWorldRect: view,
        priority: -30,
      ),
      GroundPlane(color: const Color(0xFF2A1A10), span: 40000, priority: -20),
      PowerLine(
        color: const Color(0xFF1B1119),
        span: 40000,
        visibleWorldRect: view,
        priority: -5,
      ),
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
