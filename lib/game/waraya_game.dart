import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';

import '../input/input.dart';
import '../input/input_controller.dart';
import '../input/keyboard_input_source.dart';
import '../input/touch_input_source.dart';
import '../ui/debug_hud.dart';
import 'config.dart';
import 'ground.dart';
import 'palm_row.dart';
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
    // The palms are crowns only. Every palm in art/source has its lower trunk
    // crossing something as dark as itself, so no brightness matte separates
    // them -- but rendering the row behind the treeline hides exactly the part
    // that could not be cut.
    final far = await images.load('layer_far_treeline.webp');
    final mid = await images.load('layer_mid_treeline.webp');
    final palm = await images.load('palm_01.webp');

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
      // Behind the mid band on purpose: only the crown clears the trees, which
      // is both how a village skyline looks and why the missing trunk in the
      // cut-out never shows.
      PalmRow(
        sprite: Sprite(palm),
        span: 40000,
        heightUnits: 215,
        // Inside the treeline band, so the feathered cut stays hidden.
        baseY: WarayaConfig.horizonY - 130,
        priority: -35,
      ),
      PhotoBand(
        image: mid,
        depth: 0.45,
        heightUnits: 230,
        bottomY: WarayaConfig.horizonY + 4,
        visibleWorldRect: view,
        priority: -30,
      ),
      GroundPlane(
        // The horizon end carries the same haze the bands fade into; the near
        // end is the shadow the road sits in right under the camera.
        horizonColor: const Color(0xFF3D2609),
        nearColor: const Color(0xFF0E0805),
        span: 40000,
        priority: -20,
      ),
      // Behind the walker, at the character's own depth.
      GroundDetail(
        color: const Color(0xFF1A1009),
        span: 40000,
        baseY: WarayaConfig.horizonY + 14,
        density: 300,
        seed: 29,
        priority: -18,
      ),
      // In front of the walker: the closest thing in the scene, so it sells
      // the speed of everything behind it.
      GroundDetail(
        color: const Color(0xFF0D0705),
        span: 40000,
        baseY: WarayaConfig.horizonY + 178,
        scale2: 3.4,
        density: 230,
        seed: 31,
        priority: 200,
      ),
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
