import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import '../game/config.dart';
import '../input/input_controller.dart';
import '../input/keyboard_input_source.dart';
import '../input/touch_input_source.dart';
import '../shadow/fixed_ticker.dart';
import '../shadow/shadow_figure.dart';
import '../shadow/shadow_recorder.dart';
import '../ui/lab_hud.dart';
import 'lab_player.dart';
import 'lab_props.dart';
import 'lab_scene.dart';
import 'lab_settings.dart';

/// Phase 2: the delayed-shadow prototype, on grey boxes.
///
/// A separate game from `WarayaGame` on purpose. The plan bans touching the
/// finished environment during this phase — partly to protect it, mostly
/// because a pretty scene makes any mechanic feel better than it is, and the
/// only question Phase 2 asks is whether *this mechanic* is fun. Run it with:
///
/// ```sh
/// flutter run -t lib/main_lab.dart
/// ```
///
/// The loop is small enough to state in full:
///
/// 1. every fixed tick, the player's pose is pushed into [ShadowRecorder];
/// 2. once the buffer holds `delaySeconds` worth, the oldest pose comes out
///    the far end and the shadow puts itself there;
/// 3. everything else — the plate, the door, standing on the shadow, dying to
///    it — is just collision against where the shadow ended up.
class ShadowLabGame extends FlameGame with HasKeyboardHandlerComponents {
  ShadowLabGame({LabSettings? settings})
    : settings = settings ?? LabSettings();

  final LabSettings settings;

  final ShadowRecorder recorder = ShadowRecorder();
  final FixedTicker ticker = FixedTicker();

  late final InputController input;
  late final LabPlayer player;
  late final ShadowFigure shadow;
  late final PressurePlate plate;
  late final LabDoor door;
  late final LabGoal doorGoal;
  late final LabGoal ledgeGoal;

  /// Longest frame the simulation will believe, in seconds.
  ///
  /// A browser tab that spent ten seconds loading hands the first frame a `dt`
  /// of ten seconds. Unclamped, gravity integrates that in one step and the
  /// player teleports thousands of units below the floor — past it, not onto
  /// it, because collision here is an overlap test and an overlap test cannot
  /// see a body that jumped the whole obstacle in one frame. That is exactly
  /// what happened the first time this ran in a real browser: an empty scene
  /// with the character somewhere under the world.
  ///
  /// Clamping means a stuttering machine runs the game in slow motion instead
  /// of breaking it, which is the right trade for a prototype.
  static const double maxFrameSeconds = 1 / 15;

  /// Bumped on every reload, shown in the HUD. The only "death" system this
  /// phase gets: no respawn animation, no lives, no checkpoint.
  int reloads = 0;

  @override
  Color backgroundColor() => LabScene.background;

  @override
  Future<void> onLoad() async {
    final keyboard = KeyboardInputSource();
    final touch = TouchInputSource();
    input = InputController([keyboard, touch]);
    await addAll([input, keyboard, _LabHotkeys(reload)]);
    await camera.viewport.add(touch);

    plate = PressurePlate();
    door = LabDoor();
    doorGoal = LabGoal(area: LabScene.goalBehindDoor);
    ledgeGoal = LabGoal(area: LabScene.goalOnLedge);
    shadow = ShadowFigure(
      color: LabScene.bodyColor,
      opacity: settings.shadowOpacity,
    );
    player = LabPlayer(input: input, solids: _solids);

    await world.addAll([
      LabBlocks(),
      plate,
      door,
      doorGoal,
      ledgeGoal,
      ShadowTrail(recorder: recorder, enabled: () => settings.showTrail),
      shadow,
      player,
    ]);

    await camera.viewport.add(LabHud(game: this));

    camera.viewfinder.position = Vector2(0, WarayaConfig.worldHeight / 2);
    camera.follow(player, horizontalOnly: true);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Same viewport rule as the real game: pin the world height, let the width
    // be whatever the device gives us.
    if (size.y > 0) {
      camera.viewfinder.zoom = size.y / WarayaConfig.worldHeight;
    }
  }

  @override
  void update(double dt) {
    final step = dt > maxFrameSeconds ? maxFrameSeconds : dt;
    input.refresh();
    // The tunables are read every frame rather than pushed on change, so the
    // sliders can be dragged mid-jump and take effect immediately.
    recorder.delaySeconds = settings.delaySeconds;
    shadow.opacity = settings.shadowOpacity;

    // Record and replay before the world moves, so the shadow's rect is
    // already in place when the player collides with it this frame.
    ticker.advance(step, _fixedTick);
    super.update(step);
    _resolveInteractions();
  }

  void _fixedTick() {
    recorder.record(player.capture());
    final due = recorder.current;
    if (due == null) return;
    shadow.apply(due);
    // A player standing on the shadow travels with it. Without this, a shadow
    // that walks out from under the player leaves them hanging in the air,
    // which reads as a bug rather than as a moving platform.
    if (player.isOnShadow) player.carryX += shadow.lastStepX;
  }

  void _resolveInteractions() {
    // The floor ends somewhere, and walking off the end of a test scene is a
    // dead state that looks like a crash. Put them back instead.
    if (player.y > WarayaConfig.worldHeight + 240) {
      reload();
      return;
    }

    final playerBox = player.bounds;
    final shadowBox = shadow.isActive ? shadow.bounds : null;

    plate.pressedByPlayer = playerBox.overlaps(LabScene.plateTrigger);
    plate.pressedByShadow =
        shadowBox != null && shadowBox.overlaps(LabScene.plateTrigger);
    door.wantsOpen = plate.isPressed;

    if (playerBox.overlaps(doorGoal.area)) doorGoal.reached = true;
    if (playerBox.overlaps(ledgeGoal.area)) ledgeGoal.reached = true;

    if (settings.shadowKills &&
        shadowBox != null &&
        playerBox.overlaps(shadowBox)) {
      reload();
    }
  }

  /// What the player can collide with this frame.
  LabSolids _solids() => LabSolids(
    blocking: [...LabScene.blocking, if (door.isSolid) door.bounds],
    oneWay: [
      if (settings.shadowIsSolid && shadow.isActive) shadow.bounds,
    ],
  );

  /// The whole death-and-retry system for this phase: put everything back.
  ///
  /// The history goes with it. A shadow that survived the reset would replay a
  /// past the player no longer has, and would be standing on the plate for
  /// reasons nobody could see.
  void reload() {
    recorder.clear();
    ticker.reset();
    shadow.clear();
    player.resetToSpawn();
    door.reset();
    plate
      ..pressedByPlayer = false
      ..pressedByShadow = false;
    doorGoal.reset();
    ledgeGoal.reset();
    reloads++;
  }
}

/// R reloads the scene. Kept out of `InputSource` deliberately: reloading is a
/// debug affordance for this phase, not something the shared input
/// abstraction should learn about and then have to carry forever.
class _LabHotkeys extends Component with KeyboardHandler {
  _LabHotkeys(this.onReload);

  final void Function() onReload;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR) {
      onReload();
    }
    return true;
  }
}
