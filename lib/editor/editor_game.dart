import 'package:flame/components.dart';

import '../game/config.dart';
import '../input/input.dart';
import '../level/level.dart';
import '../level/level_check.dart';
import '../level/level_game.dart';
import '../level/playthrough.dart';
import 'run_recorder.dart';

/// What the editor's game is doing.
enum EditorMode {
  /// Stopped, with the camera wherever the author put it. The level is drawn
  /// exactly as it will be played, because it is being played — frozen.
  editing,

  /// Being played, as the game plays it. Nothing is written down.
  playing,

  /// Being played in fixed steps, with every step written down.
  recording,

  /// A recorded run being played back, in the same fixed steps the gate uses.
  replaying,
}

/// Which recording is being made.
enum RunKind { solution, wrongIdea }

/// How a recording or a replay ended.
class RunEnded {
  const RunEnded({
    required this.moves,
    required this.finished,
    this.kind,
    this.at,
  });

  /// The run, as it will be saved. Empty for a replay.
  final List<Move> moves;

  /// Whether it reached the goal.
  final bool finished;

  /// What was being recorded, or null for a replay.
  final RunKind? kind;

  /// Seconds into the run the goal was touched, when it was.
  final double? at;
}

/// The editor's game: [LevelGame] itself, with one thing added — control over
/// **when** it steps.
///
/// Not a second game and not a second renderer. Every rectangle on screen
/// while editing is drawn by the same components that draw it in play, and
/// pressing play is the same class carrying on. That is the whole reason the
/// editor is inside the bench rather than beside it (`docs/phase-9-editor.md`):
/// an editor that drew levels its own way would be an editor where a level
/// looks one way while you build it and another while you play it.
///
/// What it overrides is [update], and only to choose the step:
///
/// - editing: a step of nothing, so the level is up and nothing moves;
/// - playing: the frame, as the game always has;
/// - recording and replaying: whole steps of [Playthrough.dt] and no other
///   length ([FixedSteps]), because that is the only step the gate replays
///   and a run recorded at any other is a different run.
class EditorGame extends LevelGame {
  EditorGame({required Level level, super.settings, super.audio, super.inputs})
    : super(levels: [level]);

  EditorMode get mode => _mode;
  EditorMode _mode = EditorMode.editing;

  /// Told when a recording or a replay stops, for whatever reason.
  void Function(RunEnded ended)? onRunEnded;

  final FixedSteps _clock = FixedSteps();
  RunRecorder? _recorder;
  RunKind? _kind;
  bool _tapeDone = false;
  int _steps = 0;

  /// Where the editing camera looks, and how close. Null until first used,
  /// then taken from wherever play left the camera.
  Vector2? editCenter;
  double editZoom = 1;

  /// How long the run in progress has lasted, in seconds of game time.
  double get runSeconds => _steps * Playthrough.dt;

  static InputIntent _still(InputIntent _) => InputIntent.none;

  /// Puts [level] up to be edited, without moving the camera.
  ///
  /// Called on every frame of a drag. The rebuilds are queued rather than
  /// overlapped — one that started while the last was still adding its
  /// pieces would find nothing to take away and leave two of everything — and
  /// only the newest waiting level is built, so a fast drag costs one rebuild
  /// per rebuild's worth of time, not one per pointer event.
  Future<void> edit(Level level) async {
    _enterEditing();
    _waiting = level;
    if (_building != null) return _building;
    _building = _buildWaiting();
    await _building;
  }

  Level? _waiting;

  /// False from a rebuild until the first editing frame has mounted it and
  /// stood the body on the floor. A body frozen the instant it was put down
  /// is a body in mid-air, and it is drawn falling.
  bool _settled = false;
  Future<void>? _building;

  Future<void> _buildWaiting() async {
    try {
      for (var level = _waiting; level != null; level = _waiting) {
        _waiting = null;
        await replaceLevels([level], quietly: true);
        // Mount it now. A level's pieces are only the world's children once
        // mounted, and the next rebuild empties the world by its children —
        // so two rebuilds with no frame between them left two of everything.
        input.shape = _still;
        super.update(0);
        _settled = false;
      }
    } finally {
      _building = null;
    }
  }

  /// Plays [level] as the game would, from the start.
  Future<void> play(Level level) async {
    await _fresh(level, EditorMode.playing);
    input.shape = null;
  }

  /// Plays [level] from the start and writes down every step.
  ///
  /// A solution stops itself at the goal. A wrong idea stops when told to
  /// ([stop]) — or at the goal as well, which means it was not a wrong idea.
  Future<void> record(Level level, RunKind kind) async {
    await _fresh(level, EditorMode.recording);
    final recorder = RunRecorder();
    _recorder = recorder;
    _kind = kind;
    input.shape = recorder.take;
  }

  /// Plays [moves] into [level] from the start, exactly as the gate would.
  Future<void> replay(Level level, List<Move> moves) async {
    await _fresh(level, EditorMode.replaying);
    final tape = Playthrough.intentsOf(moves).iterator;
    _tapeDone = false;
    input.shape = (_) {
      if (tape.moveNext()) return tape.current;
      _tapeDone = true;
      return InputIntent.none;
    };
  }

  /// Ends whatever is running and goes back to editing, reporting a run in
  /// progress as unfinished.
  void stop() {
    switch (_mode) {
      case EditorMode.recording || EditorMode.replaying:
        _end(finished: false);
      case EditorMode.playing:
        _enterEditing();
      case EditorMode.editing:
        break;
    }
  }

  /// The level exactly as a fresh game has it, the way the gate starts one:
  /// built, mounted with a step of nothing, then put back to its start.
  Future<void> _fresh(Level level, EditorMode mode) async {
    input.shape = _still;
    _mode = mode;
    _recorder = null;
    _starting = true;
    _waiting = null;
    camera.viewfinder.zoom = WarayaConfig.zoomFor(size.x, size.y);
    try {
      await _building;
      await replaceLevels([level], quietly: true);
      super.update(0);
      reload();
    } finally {
      _starting = false;
    }
    _steps = 0;
    _clock.reset();
  }

  /// True while [_fresh] is waiting on the rebuild. A frame that lands in
  /// that gap must not step a level that is about to be put back anyway.
  bool _starting = false;

  void _enterEditing() {
    if (_mode != EditorMode.editing) {
      editCenter = camera.viewfinder.position.clone();
      editZoom = camera.viewfinder.zoom;
    }
    _mode = EditorMode.editing;
    input.shape = _still;
    _recorder = null;
    fade.reveal();
  }

  void _end({required bool finished}) {
    final ended = RunEnded(
      moves: _recorder?.moves ?? const [],
      finished: finished,
      kind: _kind,
      at: finished ? runSeconds : null,
    );
    final wasRecording = _mode == EditorMode.recording;
    _kind = null;
    _enterEditing();
    onRunEnded?.call(
      wasRecording
          ? ended
          : RunEnded(moves: const [], finished: finished, at: ended.at),
    );
  }

  @override
  void update(double dt) {
    if (_starting) return;
    switch (_mode) {
      case EditorMode.editing:
        // Once per rebuild: mount what it added, and let the body settle onto
        // whatever it is standing on — two steps, with the input held still,
        // well short of any shadow arriving. Then nothing moves at all.
        if (!_settled && _building == null) {
          input.shape = _still;
          super.update(0);
          super.update(FixedSteps.step);
          super.update(FixedSteps.step);
          _settled = true;
        }
        fade.update(dt);
        _holdEditCamera();
      case EditorMode.playing:
        super.update(dt);
      case EditorMode.recording || EditorMode.replaying:
        for (var n = _clock.take(dt); n > 0; n--) {
          super.update(FixedSteps.step);
          _steps++;
          if (_afterStep()) break;
        }
    }
  }

  /// Whether the run in progress has just ended.
  bool _afterStep() {
    if (_mode == EditorMode.replaying) {
      if (completed || _tapeDone) {
        _end(finished: completed);
        return true;
      }
      return false;
    }
    // A solution ends at the goal, and so does a wrong idea — one that gets
    // there is a second solution, and the editor says so at once rather than
    // saving it as a wrong idea the gate will refuse.
    if (completed) {
      _end(finished: true);
      return true;
    }
    // Past what the gate will replay, there is nothing worth keeping.
    if (runSeconds >= CheckLimits.longestRun) {
      _end(finished: false);
      return true;
    }
    return false;
  }

  void _holdEditCamera() {
    final center = editCenter ??= Vector2(
      player.x,
      WarayaConfig.viewpointY(level.floorTop, size.y, camera.viewfinder.zoom),
    );
    camera.stop();
    camera.viewfinder
      ..zoom = editZoom
      ..position = center;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (editCenter == null && size.x > 0 && size.y > 0) {
      editZoom = WarayaConfig.zoomFor(size.x, size.y);
    }
  }

  /// Leaves the camera where the author put it while editing.
  @override
  void aimCamera() {
    if (_mode != EditorMode.editing) super.aimCamera();
  }

  /// R mid-recording starts the take again — a key pressed halfway through
  /// is not something a recording can hold, and starting over is what the
  /// person pressing it wants. Mid-replay it does nothing.
  @override
  void retry() {
    switch (_mode) {
      case EditorMode.recording:
        final kind = _kind!;
        record(level, kind);
      case EditorMode.replaying:
        break;
      case EditorMode.editing || EditorMode.playing:
        super.retry();
    }
  }
}
