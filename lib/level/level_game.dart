import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';
import '../audio/step_detector.dart';
import '../game/config.dart';
import '../game/scenery.dart';
import '../game/screen_shake.dart';
import '../input/input.dart';
import '../input/input_controller.dart';
import '../input/keyboard_input_source.dart';
import '../input/touch_input_source.dart';
import '../lab/lab_settings.dart';
import '../shadow/fixed_ticker.dart';
import '../shadow/shadow_figure.dart';
import '../shadow/shadow_recorder.dart';
import '../ui/level_hud.dart';
import '../ui/level_title.dart';
import 'level.dart';
import 'player.dart';
import 'props.dart';

/// One game that plays any [Level].
///
/// The loop is small enough to state in full:
///
/// 1. every fixed tick, the player's pose is pushed into [ShadowRecorder];
/// 2. once the buffer holds `delaySeconds` worth, the oldest pose comes out
///    the far end and the shadow puts itself there;
/// 3. everything else — the plate, the door, standing on the shadow, dying to
///    it — is collision against where the shadow ended up.
///
/// The tuning bench and the puzzles run on this same class, given different
/// levels. That is deliberate: the numbers argued with in the lab are the
/// numbers the puzzles are played at, and there is no second implementation
/// for them to drift apart from.
class LevelGame extends FlameGame with HasKeyboardHandlerComponents {
  LevelGame({
    required this.levels,
    LabSettings? settings,
    this.audio = const SilentAudio(),
    this.inputs,
    this.look = LevelLook.greyBox,
  }) : settings = settings ?? LabSettings(),
       assert(levels.isNotEmpty, 'a game needs at least one level');

  /// Played in order. One entry is a bench; several is a campaign.
  final List<Level> levels;

  final LabSettings settings;

  /// Silent unless an entry point hands it a voice, so tests make no noise and
  /// no scene depends on an audio backend existing.
  final AudioOut audio;

  /// Overrides the keyboard and touch backends when supplied. Tests use it to
  /// replay a recorded solution through the real game; nothing else should.
  final List<InputSource>? inputs;

  /// Grey boxes, or the photographed environment.
  ///
  /// The geometry is identical either way — same rectangles, same numbers, one
  /// class. Only the paint changes, which is the point: the bench stays ugly
  /// and measurable while the campaign runs in the real scene, and neither is
  /// a second implementation that can drift.
  final LevelLook look;

  bool get _lit => look == LevelLook.silhouette;

  final ShadowRecorder recorder = ShadowRecorder();
  final FixedTicker ticker = FixedTicker();
  final ScreenShake shake = ScreenShake();
  final StepDetector steps = StepDetector();

  late final InputController input;
  late Player player;
  late ShadowFigure shadow;

  final List<PressurePlate> plates = [];
  final List<Door> doors = [];
  final List<Goal> goals = [];

  int _index = 0;
  int get levelIndex => _index;
  Level get level => levels[_index];

  /// True once the player has touched the level's way out.
  bool get completed => _completed;
  bool _completed = false;

  /// Seconds left before the next level replaces this one. Gives the goal a
  /// beat to fill in, so finishing reads as finishing rather than as a cut.
  double _advanceIn = 0;
  static const double _advanceDelay = 0.9;

  /// Longest frame the simulation will believe, in seconds.
  ///
  /// A browser tab that spent ten seconds loading hands the first frame a `dt`
  /// of ten seconds. Unclamped, gravity integrates that in one step and the
  /// player teleports thousands of units below the floor — past it, not onto
  /// it, because collision here is an overlap test and an overlap test cannot
  /// see a body that jumped the whole obstacle in one frame.
  static const double maxFrameSeconds = 1 / 15;

  /// Bumped on every reload, shown in the readout. The only "death" system
  /// this phase gets: no respawn animation, no lives, no checkpoints.
  int reloads = 0;

  @override
  Color backgroundColor() =>
      _lit ? const Color(0xFF1B2A4A) : Palette.background;

  @override
  Future<void> onLoad() async {
    await audio.preload();
    final sources = inputs;
    if (sources != null) {
      input = InputController(sources);
      await add(input);
    } else {
      final keyboard = KeyboardInputSource();
      final touch = TouchInputSource();
      input = InputController([keyboard, touch]);
      await addAll([input, keyboard]);
      await camera.viewport.add(touch);
    }
    await add(_Hotkeys(reload));

    // The scene the levels stand in, added once. The world half is rebuilt per
    // level — `_build` empties the world — but the sky and the air do not
    // change between levels, so they are not torn down with them.
    if (_lit) {
      final scenery = _scenery();
      await scenery.preload();
      await camera.backdrop.add(scenery.sky());
      await camera.viewport.addAll(scenery.air());
    }

    await _build();
    final hud = LevelHud(game: this);
    await camera.viewport.addAll([hud, LevelTitle(game: this, hud: hud)]);
  }

  /// Tears the current level down and puts the next one up.
  Future<void> _build() async {
    world.removeWhere((_) => true);
    plates.clear();
    doors.clear();
    goals.clear();
    recorder.clear();
    ticker.reset();
    steps.reset();
    shake.reset();
    _completed = false;
    _advanceIn = 0;

    // The level seeds the tunables; the debug panel can still override them
    // live, which is the whole point of the panel.
    settings.delaySeconds = level.delaySeconds;
    settings.shadowIsSolid = level.shadowIsSolid;
    settings.shadowKills = level.shadowKills;

    plates.addAll(level.plates.map((spec) => PressurePlate(spec, look: look)));
    doors.addAll(level.doors.map((spec) => Door(spec, look: look)));
    goals
      ..add(Goal(area: level.goal, look: look))
      ..addAll(
        level.markers.map(
          (area) => Goal(area: area, endsLevel: false, look: look),
        ),
      );

    shadow = ShadowFigure(
      color: _lit ? SilhouettePalette.shadowColor : Palette.shadowColor,
      opacity: settings.shadowOpacity,
    );
    player = Player(
      input: input,
      solids: _solids,
      spawnX: level.spawnX,
      floorTop: level.floorTop,
      color: _lit ? SilhouettePalette.bodyColor : Palette.bodyColor,
    );

    await world.addAll([
      if (_lit) ..._scenery().world(),
      Blocks(level.blocks, look: look),
      ...plates,
      ...doors,
      ...goals,
      ShadowTrail(
        recorder: recorder,
        enabled: () => settings.showTrail,
        look: look,
      ),
      shadow,
      player,
    ]);

    _frameVertically();
    camera.follow(player, horizontalOnly: true);
  }

  /// The environment, standing on this level's floor.
  ///
  /// Its ground line is the level's, not Phase 1's horizon: the treeline has
  /// to meet the floor the player is actually walking on, or the scene reads
  /// as a backdrop hung behind the puzzle rather than as the place it is in.
  /// No road either — the level brings its own floor, and a second ground
  /// plane under it is haze in the wrong place.
  Scenery _scenery() => Scenery(
    images: images,
    view: () => camera.visibleWorldRect,
    groundY: _sceneryGround,
    withGround: false,
    withPowerLine: false,
  );

  /// Points the camera so the level's ground lands at the same height on
  /// screen whatever shape the screen is. Only the vertical: the horizontal is
  /// the follow behaviour's, and it writes that every frame.
  void _frameVertically() {
    final zoom = camera.viewfinder.zoom;
    if (zoom <= 0) return;
    camera.viewfinder.position = Vector2(
      camera.viewfinder.position.x,
      WarayaConfig.viewpointY(_sceneryGround, size.y, zoom),
    );
  }

  /// The lowest ground in the level, which is where the treeline belongs.
  ///
  /// Not `floorTop`: that is where the player *spawns*, and a level can start
  /// you on a shelf above its real floor. Doing it that way put the whole
  /// treeline up at shelf height in the level with the drop, leaving the
  /// bottom half of it as bare gradient with nothing behind it — reported from
  /// playing as the level still not looking right. A slab that falls off the
  /// bottom of the world is ground; the lowest of those is the horizon.
  double get _sceneryGround {
    var lowest = level.floorTop;
    for (final rect in level.blocks) {
      if (rect.bottom >= WarayaConfig.worldHeight && rect.top > lowest) {
        lowest = rect.top;
      }
    }
    return lowest;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) return;
    camera.viewfinder.zoom = WarayaConfig.zoomFor(size.x, size.y);
    _frameVertically();
  }

  @override
  void update(double dt) {
    final step = dt > maxFrameSeconds ? maxFrameSeconds : dt;
    input.refresh();
    recorder.delaySeconds = settings.delaySeconds;
    shadow.opacity = settings.shadowOpacity;

    // Record and replay before the world moves, so the shadow's rect is
    // already in place when the player collides with it this frame.
    ticker.advance(step, _fixedTick);
    super.update(step);
    _resolveInteractions();

    shadow.alpha = ticker.alpha;
    _reactToLanding(step);
    _playMovementSounds();
    _advance(step);
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
    // The floor ends somewhere, and walking off the end of a level is a dead
    // state that looks like a crash. Put them back instead.
    if (player.y > WarayaConfig.worldHeight + 240) {
      reload();
      return;
    }

    final playerBox = player.bounds;
    final shadowBox = shadow.isActive ? shadow.bounds : null;

    for (final plate in plates) {
      final wasPressed = plate.isPressed;
      plate.pressedByPlayer = _standsOn(playerBox, plate.trigger);
      plate.pressedByShadow =
          shadowBox != null && _standsOn(shadowBox, plate.trigger);
      if (plate.isPressed != wasPressed) audio.play(Sfx.plate, volume: 0.5);
    }

    for (final door in doors) {
      final pressed = plates
          .where((plate) => plate.opens == door.id)
          .any((plate) => plate.isPressed);
      if (door.hold(pressed)) audio.play(Sfx.door, volume: 0.4);
    }

    for (final goal in goals) {
      if (goal.reached || !playerBox.overlaps(goal.area)) continue;
      goal.reached = true;
      if (goal.endsLevel) {
        _completed = true;
        _advanceIn = _advanceDelay;
      }
    }

    // Not once the level is won. The shadow is still walking during the beat
    // between touching the goal and the next level loading, and being caught
    // in that beat used to wipe the finish and put you back at the start.
    if (settings.shadowKills &&
        !_completed &&
        shadowBox != null &&
        playerBox.overlaps(shadowBox)) {
      reload();
    }
  }

  /// Whether [body] is standing on [trigger] rather than touching its edge.
  ///
  /// A body is 44 wide and `Rect.overlaps` is true at a single unit of
  /// contact, so standing *beside* a plate with one edge over the line pressed
  /// it — reported from playing as a door opening while the character was
  /// visibly off the plate. A third of the body has to be over it, or the
  /// whole plate if the plate is narrower than that.
  static const double _footprint = 16;

  static bool _standsOn(Rect body, Rect trigger) {
    if (!body.overlaps(trigger)) return false;
    final overlap =
        min(body.right, trigger.right) - max(body.left, trigger.left);
    return overlap >= min(_footprint, trigger.width);
  }

  /// Moves on once the goal has had its beat. The last level simply stays
  /// finished: where to go after the campaign is a Phase 5 question.
  void _advance(double dt) {
    if (_advanceIn <= 0) return;
    _advanceIn -= dt;
    if (_advanceIn > 0) return;
    _advanceIn = 0;
    if (_index + 1 >= levels.length) return;
    _index++;
    _build();
  }

  void _playMovementSounds() {
    final footfall = steps.advance(
      player.stridePhase,
      moving: player.pose.isMoving,
      grounded: player.isGrounded,
    );
    if (footfall != null) {
      // Quieter the lower the body is: a crouched body is sneaking.
      audio.play(footfall, volume: 0.35 - 0.15 * player.crouch);
    }
    if (player.locomotion.jumped) audio.play(Sfx.jump, volume: 0.45);
  }

  /// Knocks the camera in proportion to how hard the player hit the ground,
  /// then adds the offset on top of wherever the follow behaviour put the
  /// viewfinder. Adding it here rather than as an effect on the viewfinder is
  /// deliberate: the follow behaviour writes that position every frame, and
  /// two things writing one position take turns instead of combining.
  void _reactToLanding(double dt) {
    final impact = player.takeLandingImpact();
    if (impact > WarayaConfig.landingShakeThreshold) {
      final over = impact - WarayaConfig.landingShakeThreshold;
      final range =
          WarayaConfig.maxFallSpeed - WarayaConfig.landingShakeThreshold;
      final weight = (over / range).clamp(0.0, 1.0);
      shake.hit(WarayaConfig.landingShakeMax * weight);
      // The same number drives both, so what you hear and what you feel are
      // the same landing.
      audio.play(Sfx.land, volume: 0.35 + 0.5 * weight);
    }
    shake.advance(dt);
    if (shake.isShaking) camera.viewfinder.position += shake.offset;
  }

  /// What the player can collide with this frame.
  Solids _solids() => Solids(
    blocking: [
      ...level.blocks,
      for (final door in doors)
        if (door.isSolid) door.bounds,
    ],
    oneWay: [if (settings.shadowIsSolid && shadow.isActive) shadow.bounds],
  );

  /// The whole death-and-retry system for this phase: put everything back.
  ///
  /// The history goes with it. A shadow that survived the reset would replay a
  /// past the player no longer has, and would be standing on a plate for
  /// reasons nobody could see.
  void reload() {
    recorder.clear();
    ticker.reset();
    shadow.clear();
    player.resetToSpawn();
    for (final door in doors) {
      door.reset();
    }
    for (final plate in plates) {
      plate.reset();
    }
    for (final goal in goals) {
      goal.reset();
    }
    steps.reset();
    shake.reset();
    _completed = false;
    _advanceIn = 0;
    reloads++;
  }
}

/// R reloads the level. Kept out of `InputSource` deliberately: reloading is a
/// debug affordance, not something the shared input abstraction should learn
/// about and then have to carry forever.
class _Hotkeys extends Component with KeyboardHandler {
  _Hotkeys(this.onReload);

  final void Function() onReload;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR) {
      onReload();
    }
    return true;
  }
}
