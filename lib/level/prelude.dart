import '../input/input.dart';
import '../input/input_controller.dart';
import '../shadow/shadow_figure.dart';
import 'player.dart';
import 'playthrough.dart';

/// A past the player never lived, walked in front of them before they move
/// (`Level.prelude`, `docs/phase-11-feel.md` §4.1).
///
/// A body of its own — a [Player] nobody can see, driven by the level's
/// recorded moves — and a [ShadowFigure] drawn where that body is, exactly as
/// a real past is drawn. **Nothing reads it.** It is not in the shadows the
/// level feels: it presses no plate, holds no door, carries nobody and kills
/// nobody. Which is what lets it exist at all without touching a single
/// recorded solution.
///
/// It loops until the player moves, then fades and is gone; a reload brings
/// it back, because the level is back where it started.
class Prelude {
  Prelude({
    required this.moves,
    required this.figure,
    required this.solids,
    required this.spawnX,
    required this.floorTop,
  }) : _steps = Playthrough.intentsOf(moves).toList();

  final Solids Function() solids;
  final double spawnX;
  final double floorTop;

  final ScriptedInput _input = ScriptedInput();

  late final Player _body = Player(
    input: InputController([_input]),
    solids: solids,
    spawnX: spawnX,
    floorTop: floorTop,
  );

  final List<Move> moves;
  final ShadowFigure figure;

  /// What [moves] ask for, one fixed step each — the same reading of a move
  /// the gate and the editor use, so the showing is the run that was written.
  final List<InputIntent> _steps;

  /// Steps into the moves, and seconds the figure has been fading.
  int _at = 0;
  double _fading = -1;

  /// A beat of nothing between one showing and the next, in steps, so the
  /// loop reads as starting over rather than as a teleport.
  static const int rest = 48;

  /// How long the figure takes to go once the player moves.
  static const double fadeSeconds = 0.4;

  /// Whether it is still on screen at all.
  bool get showing => _fading < fadeSeconds;

  /// How visible it is, 1 while playing down to 0 once faded.
  double get strength =>
      _fading < 0 ? 1 : (1 - _fading / fadeSeconds).clamp(0.0, 1.0);

  /// From the top: a level has just gone up or been put back.
  void restart() {
    _at = 0;
    _fading = -1;
    _body.resetToSpawn();
    figure.clear();
  }

  /// The player moved. The demonstration is over; their own past is next.
  void dismiss() {
    if (_fading < 0) _fading = 0;
  }

  /// One fixed tick of [dt] seconds.
  void tick(double dt) {
    if (_fading >= 0) {
      _fading += dt;
      if (!showing) figure.clear();
      return;
    }
    if (_at >= _steps.length + rest) {
      _at = 0;
      _body.resetToSpawn();
      figure.clear();
    }
    if (_at < _steps.length) {
      _input.next = _steps[_at];
      _body.input.refresh();
      _body.update(dt);
      figure.apply(_body.capture());
    } else {
      // Resting: the body has finished and is not drawn until it starts over.
      figure.clear();
    }
    _at++;
  }
}
