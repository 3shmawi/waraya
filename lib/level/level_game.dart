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
import '../ui/level_fade.dart';
import '../ui/level_hud.dart';
import '../ui/level_title.dart';
import '../ui/reset_flash.dart';
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
    int startAt = 0,
    this.onBeaten,
    this.onCampaignFinished,
    this.onMenuRequested,
    this.readoutDetail = true,
  }) : settings = settings ?? LabSettings(),
       _index = startAt.clamp(0, levels.length - 1),
       assert(levels.isNotEmpty, 'a game needs at least one level');

  /// Played in order. One entry is a bench; several is a campaign.
  ///
  /// Not final only so [replaceLevels] can swap it. Nothing else writes it.
  List<Level> levels;

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

  /// Called with the level that was just finished, before the next one loads.
  ///
  /// The game does not know what saving is and should not: it reports, and
  /// whatever built it decides whether that is worth writing down.
  final void Function(Level level)? onBeaten;

  /// Called once the last level in the list has been finished and there is
  /// nowhere left to advance to.
  final void Function()? onCampaignFinished;

  /// Called when the player asks for the level list from the keyboard.
  final void Function()? onMenuRequested;

  /// Whether the corner readout prints its developer lines. See [LevelHud].
  final bool readoutDetail;

  /// One per delay, nearest first, all fed the same snapshot every tick.
  ///
  /// Two buffers rather than one buffer with two taps: 7 seconds at 60Hz is
  /// 420 small objects, and the cost of the second copy is nothing next to the
  /// cost of a delay line that has to answer two questions at once.
  final List<ShadowRecorder> recorders = [ShadowRecorder()];

  /// One per recorder, nearest first.
  final List<ShadowFigure> shadows = [];

  /// The nearest shadow's delay line. What "the shadow" means everywhere that
  /// only ever had one — the readout, the trail, the bench.
  ShadowRecorder get recorder => recorders.first;

  final FixedTicker ticker = FixedTicker();
  final ScreenShake shake = ScreenShake();
  final StepDetector steps = StepDetector();
  final ResetFlash resetFlash = ResetFlash();
  final LevelFade fade = LevelFade();

  late final InputController input;
  late Player player;

  /// The nearest shadow.
  ShadowFigure get shadow => shadows.first;

  final List<PressurePlate> plates = [];
  final List<Toggle> toggles = [];
  final List<Door> doors = [];
  final List<Goal> goals = [];

  int _index;
  int get levelIndex => _index;
  Level get level => levels[_index];

  /// True while the nearest shadow is standing in one of the level's lit
  /// rectangles, where it is not a thing: not solid, pressing nothing, killing
  /// nobody.
  ///
  /// Decided on the fixed tick rather than per frame, and by the centre of the
  /// body rather than by an overlap. Both for the same reason: what a shadow
  /// does has to be exactly what was recorded, replayed the same way every
  /// time, and a rule evaluated on the render frame is a rule that answers
  /// differently on a 120Hz screen.
  bool get shadowInLight => shadow.inLight;

  /// Every shadow that is both arrived and out of the light — the ones the
  /// level can actually feel.
  Iterable<ShadowFigure> get liveShadows =>
      shadows.where((s) => s.isActive && !s.inLight);

  /// How far down a recorded pose has to be folded before it counts as ducked.
  ///
  /// Not zero. The crouch eases in and out over a few frames, so a body that
  /// merely brushed the key on its way past records a sliver of one — and a
  /// sliver of a crouch that makes a step is a step the player did not mean
  /// to leave, which is the entire thing [ShadowSolidity.crouched] exists to
  /// stop. Three quarters is comfortably past anything accidental and
  /// comfortably short of the pose you hold on purpose.
  static const double _duckedEnough = 0.75;

  /// The shadows you can put your feet on this frame.
  ///
  /// In an ordinary level that is all of them. In a [ShadowSolidity.crouched]
  /// level it is only the ones that were ducked, which is what turns the
  /// staircase from a side effect of walking into something the player chose
  /// to leave.
  Iterable<ShadowFigure> get standableShadows => switch (level.solidWhen) {
    ShadowSolidity.always => liveShadows,
    ShadowSolidity.crouched => liveShadows.where(
      (s) => s.crouch >= _duckedEnough,
    ),
  };

  /// True once the player has touched the level's way out.
  bool get completed => _completed;
  bool _completed = false;

  /// Seconds left before the next level replaces this one. Gives the goal a
  /// beat to fill in, so finishing reads as finishing rather than as a cut.
  double _advanceIn = 0;

  /// The beat between touching the goal and the next level replacing it.
  ///
  /// Public so a test can check it is still longer than the fade that has to
  /// fit inside it: if the cover ever starts the moment the goal is touched,
  /// the one piece of feedback that says *you did it* is never seen.
  static const double advanceDelay = 0.9;

  /// Longest frame the simulation will believe, in seconds.
  ///
  /// A browser tab that spent ten seconds loading hands the first frame a `dt`
  /// of ten seconds. Unclamped, gravity integrates that in one step and the
  /// player teleports thousands of units below the floor — past it, not onto
  /// it, because collision here is an overlap test and an overlap test cannot
  /// see a body that jumped the whole obstacle in one frame.
  static const double maxFrameSeconds = 1 / 15;

  /// How much of its usual opacity a shadow keeps while it is in the light.
  static const double _litShadowOpacity = 0.28;

  /// And while it is standing up in a level where only a ducked body is solid.
  ///
  /// Nearly twice the light's number, for a plain reason: in the light there
  /// is a beam behind the shadow holding it up against the sky, and here
  /// there is nothing. At 0.28 on open ground the body simply is not there —
  /// rendered and checked — and a past you cannot see is not a past that is
  /// ghostly, it is a past that looks like a bug. Faint enough to say *not
  /// this one*, solid enough to be a body walking past.
  static const double _standingShadowOpacity = 0.5;

  /// And while it is the ducked one, in the same level.
  ///
  /// Above one on purpose: this is the only body in such a level you can put
  /// your feet on, so it is drawn **harder than an ordinary shadow**, not
  /// merely left undimmed. The two states have to be one glance apart — the
  /// whole level is the player deciding where to leave a step, and a step
  /// they have to squint for is a step they will not trust. Clamped where it
  /// lands past opaque.
  static const double _duckedShadowOpacity = 1.7;

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
    await add(_Hotkeys(onReload: reload, onMenu: onMenuRequested));

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
    final hud = LevelHud(game: this, detail: readoutDetail);
    await camera.viewport.addAll([
      resetFlash,
      hud,
      LevelTitle(game: this, hud: hud),
      fade,
    ]);
  }

  /// Tears the current level down and puts the next one up.
  Future<void> _build() async {
    world.removeWhere((_) => true);
    plates.clear();
    toggles.clear();
    doors.clear();
    goals.clear();
    ticker.reset();
    steps.reset();
    shake.reset();
    _completed = false;
    _advanceIn = 0;
    resetFlash.clear();

    // One delay line and one figure per delay, nearest first. Rebuilt rather
    // than reused: a level can have a different number of shadows from the one
    // before it, and a buffer that survived would be replaying somebody else's
    // level.
    recorders
      ..clear()
      ..addAll(
        level.delays.map((seconds) => ShadowRecorder(delaySeconds: seconds)),
      );
    shadows
      ..clear()
      ..addAll([
        for (final (i, _) in level.delays.indexed)
          ShadowFigure(
            color: _lit ? SilhouettePalette.shadowColor : Palette.shadowColor,
            opacity: settings.shadowOpacity,
            // The mark's own ladder, so a level with one shadow looks exactly
            // as it always did and a second one is visibly further back.
            fade: pastFades[min(i, pastFades.length - 1)],
            // Nearer in front. Which one is in front matters when they stand
            // in the same place, which is exactly when the player most needs
            // to be able to tell them apart.
            priority: 90 - i,
          ),
      ]);

    // The level seeds the tunables; the debug panel can still override them
    // live, which is the whole point of the panel.
    settings.delaySeconds = level.delaySeconds;
    settings.shadowIsSolid = level.shadowIsSolid;
    settings.shadowKills = level.shadowKills;

    plates.addAll(level.plates.map((spec) => PressurePlate(spec, look: look)));
    toggles.addAll(level.toggles.map((spec) => Toggle(spec, look: look)));
    doors.addAll(level.doors.map((spec) => Door(spec, look: look)));
    goals
      ..add(Goal(area: level.goal, look: look))
      ..addAll(
        level.markers.map(
          (area) => Goal(area: area, endsLevel: false, look: look),
        ),
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
      ...level.lights.map((area) => LightZone(area, look: look)),
      ...plates,
      ...toggles,
      ...doors,
      ...goals,
      ShadowTrail(
        recorder: recorder,
        enabled: () => settings.showTrail,
        look: look,
      ),
      ...shadows,
      player,
    ]);

    _frameVertically();
    camera.follow(player, horizontalOnly: true);
    // Whatever put this level up — the level before it finishing, or the menu
    // — the new one arrives out of the dark rather than appearing in it.
    fade.reveal();
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
    // The panel drives the nearest one; the rest keep the delays their level
    // gave them, because the gap between two shadows is the puzzle and a
    // slider that closed it would be a slider that deletes the level.
    recorder.delaySeconds = settings.delaySeconds;
    for (final ghost in shadows) {
      // Every one of these is a fraction of whatever the panel is set to
      // rather than a value of its own: this and the fade ladder are the two
      // things on screen saying which past is which and whether it is there
      // at all, and both have to survive the opacity slider being moved.
      //
      // What the player is being told, in one glance:
      //   in the light        — not here at all
      //   standing, in a      — here, but not something to stand on
      //     crouched level
      //   ducked, in one      — *this* is the step you left
      //   anything else       — your past, as every other level means it
      //
      // A rule you cannot see is a rule that reads as a bug the first time
      // you fall through your own shoulders.
      final crouchedLevel =
          level.solidWhen == ShadowSolidity.crouched && settings.shadowIsSolid;
      final ducked = ghost.crouch >= _duckedEnough;
      ghost.opacity =
          (settings.shadowOpacity *
                  ghost.fade *
                  switch ((ghost.inLight, crouchedLevel, ducked)) {
                    (true, _, _) => _litShadowOpacity,
                    (false, true, false) => _standingShadowOpacity,
                    (false, true, true) => _duckedShadowOpacity,
                    _ => 1,
                  })
              .clamp(0.0, 1.0);
    }

    // Record and replay before the world moves, so the shadow's rect is
    // already in place when the player collides with it this frame.
    ticker.advance(step, _fixedTick);
    super.update(step);
    _resolveInteractions();

    for (final ghost in shadows) {
      ghost.alpha = ticker.alpha;
    }
    _reactToLanding(step);
    _playMovementSounds();
    _advance(step);
  }

  void _fixedTick() {
    final pose = player.capture();
    for (final (i, line) in recorders.indexed) {
      line.record(pose);
      final due = line.current;
      final ghost = shadows[i];
      if (due == null) {
        ghost.inLight = false;
        continue;
      }
      ghost.apply(due);
      ghost.inLight = _standsInLight(ghost.bounds);
    }
    // A player standing on a shadow travels with it. Without this, a shadow
    // that walks out from under the player leaves them hanging in the air,
    // which reads as a bug rather than as a moving platform. With two of them
    // it also has to be the right one: the other is somewhere else entirely.
    if (player.isOnShadow) player.carryX += _carrier()?.lastStepX ?? 0;
  }

  /// Which shadow the player is standing on, if any.
  ///
  /// By the feet, not by overlap: the player is *on* the one whose top their
  /// feet are resting on, and with two shadows in the same place only one of
  /// them is holding anybody up.
  ShadowFigure? _carrier() {
    for (final ghost in liveShadows) {
      final top = ghost.bounds;
      if ((player.y - top.top).abs() > 2) continue;
      if (player.x + 22 < top.left || player.x - 22 > top.right) continue;
      return ghost;
    }
    return null;
  }

  void _resolveInteractions() {
    // The floor ends somewhere, and walking off the end of a level is a dead
    // state that looks like a crash. Put them back instead.
    if (player.y > WarayaConfig.worldHeight + 240) {
      reload();
      return;
    }

    final playerBox = player.bounds;
    // What the rest of the level can see. In the light there is nothing there
    // to press a plate, throw a key or catch anybody — a lit shadow is still
    // drawn, faintly, but that is all it is.
    final ghosts = [for (final ghost in liveShadows) ghost.bounds];

    for (final plate in plates) {
      final wasPressed = plate.isPressed;
      plate.pressedByPlayer = _standsOn(playerBox, plate.trigger);
      plate.pressedByShadow = ghosts.any(
        (ghost) => _standsOn(ghost, plate.trigger),
      );
      if (plate.isPressed != wasPressed) audio.play(Sfx.plate, volume: 0.5);
    }

    for (final toggle in toggles) {
      // Contacts in, not state: the key decides for itself whether an arrival
      // happened, because the edge is the whole of what it is.
      final clicked = toggle.touch(
        player: _standsOn(playerBox, toggle.trigger),
        shadow: ghosts.any((ghost) => _standsOn(ghost, toggle.trigger)),
      );
      // Louder than a plate. A plate's click is a question being answered and
      // will be answered again in a moment; this one is the only announcement
      // the door's state ever gets, and the body that made it is often walking
      // away from the door at the time.
      if (clicked) audio.play(Sfx.plate, volume: 0.7);
    }

    for (final door in doors) {
      final mine = plates.where((plate) => plate.opens == door.id);
      // The order is the rule. An inverted plate under a body beats a plate
      // held, a key thrown, and the linger — see `Door.hold`.
      final forcedShut = mine.any((plate) => plate.inverts && plate.isPressed);
      final open =
          mine.any((plate) => !plate.inverts && plate.isPressed) ||
          toggles.any(
            (toggle) => toggle.flips == door.id && toggle.flipped,
          );
      // The grace is your past's, not yours: a door held open by nothing but
      // the body you are standing in shuts the moment you step off it.
      final lingers =
          mine.any((plate) => !plate.inverts && plate.pressedByShadow) ||
          toggles.any((toggle) => toggle.flips == door.id && toggle.flipped);
      if (door.hold(open, forcedShut: forcedShut, lingers: lingers)) {
        audio.play(Sfx.door, volume: 0.4);
      }
    }

    for (final goal in goals) {
      if (goal.reached || !playerBox.overlaps(goal.area)) continue;
      goal.reached = true;
      if (goal.endsLevel) {
        _completed = true;
        _advanceIn = advanceDelay;
        onBeaten?.call(level);
      }
    }

    // Not once the level is won. The shadow is still walking during the beat
    // between touching the goal and the next level loading, and being caught
    // in that beat used to wipe the finish and put you back at the start.
    if (settings.shadowKills &&
        !_completed &&
        ghosts.any(playerBox.overlaps)) {
      reload();
    }
  }

  /// Whether a body is in a lit rectangle.
  ///
  /// Any of it. This used to be the body's middle, on the argument that half
  /// a body in the light is something the player can see is half in the
  /// light, so "the middle decides" is the version they can predict from the
  /// floor — and that an overlap test fires while the shadow is visibly still
  /// mostly in the dark.
  ///
  /// Reported from playing, and it is the other half of that argument: "the
  /// light shows the shadow if part of it is outside the light." A body
  /// straddling the edge was drawn at full strength and was solid, sitting
  /// visibly inside a beam that is supposed to erase it. The rule was right
  /// and the picture said otherwise, and the picture is what the player has.
  ///
  /// So: if the beam touches your past, your past is not there — and it is
  /// drawn faint the instant that becomes true, which is what makes the new
  /// rule readable where the old one was not. The cost is real and worth
  /// knowing when drawing a level: the reach is half a body (22) wider than
  /// the lit rectangle on each side, because it is the body that has to be
  /// clear of the beam, not the body's middle.
  bool _standsInLight(Rect body) =>
      level.lights.any((light) => light.overlaps(body));

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

  /// Moves on once the goal has had its beat.
  ///
  /// The beat is in two halves: the goal fills in, and then the screen goes
  /// dark over the rest of it, so the swap itself happens on a black frame.
  void _advance(double dt) {
    if (_advanceIn <= 0) return;
    _advanceIn -= dt;
    if (_advanceIn <= LevelFade.startsAt) fade.cover();
    if (_advanceIn > 0) return;
    _advanceIn = 0;
    if (_index + 1 >= levels.length) {
      // Nothing left to build, so nothing is going to call `reveal` — and a
      // screen left black under whatever the campaign's ending puts up is a
      // screen that stays black if that ending is ever dismissed.
      fade.reveal();
      onCampaignFinished?.call();
      return;
    }
    _index++;
    _build();
  }

  /// Swaps the whole list under a running game, for the authoring loop.
  ///
  /// Keeps your place **by id**, not by position — the same reason saving does
  /// (`Progress`). While a level is being written the list is exactly what is
  /// churning: one gets inserted, another renamed, a third deleted, and an
  /// index means you land somewhere else every time you press reload. An id
  /// means you land back in the level you are editing.
  ///
  /// An empty list is ignored rather than obeyed. It means the folder was
  /// emptied or every level in it was refused, and a game with no level is a
  /// crash; keeping the last good one on screen is the answer that lets you
  /// fix the file and press the button again.
  Future<void> replaceLevels(List<Level> next) async {
    if (next.isEmpty) return;
    final wasOn = level.id;
    levels = next;
    final found = next.indexWhere((level) => level.id == wasOn);
    _index = found < 0 ? 0 : found;
    reloads = 0;
    _advanceIn = 0;
    fade.blackout();
    await _build();
  }

  /// Jumps to a level by position, from a menu. Everything is rebuilt, so the
  /// buffer, the shadow and the doors all start where a fresh level expects
  /// to find them.
  Future<void> goTo(int index) async {
    _index = index.clamp(0, levels.length - 1);
    reloads = 0;
    _advanceIn = 0;
    // Straight to black first: picking from the menu is not the end of a
    // level, so there is no cover already running — but the level still
    // arrives out of the dark, the same way every other one does.
    fade.blackout();
    await _build();
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
    oneWay: [
      if (settings.shadowIsSolid)
        for (final ghost in standableShadows) ghost.bounds,
    ],
  );

  /// The whole death-and-retry system for this phase: put everything back.
  ///
  /// The history goes with it. A shadow that survived the reset would replay a
  /// past the player no longer has, and would be standing on a plate for
  /// reasons nobody could see.
  void reload() {
    for (final line in recorders) {
      line.clear();
    }
    ticker.reset();
    for (final ghost in shadows) {
      ghost.clear();
      ghost.inLight = false;
    }
    player.resetToSpawn();
    for (final door in doors) {
      door.reset();
    }
    for (final plate in plates) {
      plate.reset();
    }
    for (final toggle in toggles) {
      toggle.reset();
    }
    for (final goal in goals) {
      goal.reset();
    }
    steps.reset();
    shake.reset();
    _completed = false;
    _advanceIn = 0;
    reloads++;
    // Seen and heard. Being put back used to happen between two frames with
    // nothing to mark it, which reads as the game glitching rather than as
    // dying.
    resetFlash.show();
    audio.play(Sfx.reset, volume: 0.45);
  }
}

/// R reloads the level, escape asks for the level list. Kept out of
/// `InputSource` deliberately: neither is a movement, and the shared input
/// abstraction should not learn about them and then have to carry them
/// forever.
class _Hotkeys extends Component with KeyboardHandler {
  _Hotkeys({required this.onReload, this.onMenu});

  final void Function() onReload;
  final void Function()? onMenu;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return true;
    if (event.logicalKey == LogicalKeyboardKey.keyR) onReload();
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.keyM) {
      onMenu?.call();
    }
    return true;
  }
}
