import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';

import '../audio/sfx.dart';
import '../audio/step_detector.dart';
import '../input/input.dart';
import '../input/input_controller.dart';
import '../input/keyboard_input_source.dart';
import '../input/touch_input_source.dart';
import '../ui/debug_hud.dart';
import 'config.dart';
import 'probe_walker.dart';
import 'scenery.dart';
import 'screen_shake.dart';

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
  WarayaGame({this.audio = const SilentAudio()});

  /// Silent unless an entry point hands it a voice.
  final AudioOut audio;

  late final InputController input;
  late final ProbeWalker walker;

  /// The camera's flinch on a hard landing. Same helper as the lab, so the
  /// feel being tuned there is the feel that ships here.
  final ScreenShake shake = ScreenShake();
  final StepDetector steps = StepDetector();

  @override
  Color backgroundColor() => const Color(0xFF1B2A4A);

  @override
  Future<void> onLoad() async {
    await audio.preload();
    final keyboard = KeyboardInputSource();
    final touch = TouchInputSource();
    input = InputController([keyboard, touch]);

    // The controller itself is not a source of events; the two backends are.
    await add(input);
    await add(keyboard);

    final scenery = Scenery(
      images: images,
      view: () => camera.visibleWorldRect,
      groundY: WarayaConfig.horizonY,
    );
    await scenery.preload();

    // The sky goes in the backdrop, not the viewport: the camera renders
    // backdrop -> world -> viewport, so a viewport sky would paint over the
    // whole scene.
    await camera.backdrop.add(scenery.sky());
    await camera.viewport.add(touch);
    // Atmosphere, over the world and under the debug readout.
    await camera.viewport.addAll(scenery.air());
    await camera.viewport.add(
      DebugHud(input: input, visibleWorldRect: () => camera.visibleWorldRect),
    );

    // The photographed bands, the road and the wires, far to near. Depth
    // drives the parallax: 0 is infinitely distant, 1 sits in the world plane
    // with the character.
    await world.addAll(scenery.world());

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

    final impact = walker.takeLandingImpact();
    if (impact > WarayaConfig.landingShakeThreshold) {
      final over = impact - WarayaConfig.landingShakeThreshold;
      final range =
          WarayaConfig.maxFallSpeed - WarayaConfig.landingShakeThreshold;
      final weight = (over / range).clamp(0.0, 1.0);
      shake.hit(WarayaConfig.landingShakeMax * weight);
      audio.play(Sfx.land, volume: 0.35 + 0.5 * weight);
    }

    final footfall = steps.advance(
      walker.stridePhase,
      moving: walker.locomotion.horizontalVelocity.abs() > 1,
      grounded: walker.isGrounded,
    );
    if (footfall != null) {
      audio.play(footfall, volume: 0.35 - 0.15 * walker.crouch);
    }
    if (walker.locomotion.jumped) audio.play(Sfx.jump, volume: 0.45);

    shake.advance(dt);
    // After the follow behaviour, which writes this position every frame.
    if (shake.isShaking) camera.viewfinder.position += shake.offset;
  }
}
