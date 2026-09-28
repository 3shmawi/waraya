import '../input/input.dart';
import '../level/playthrough.dart';

/// Turns a frame of any length into whole fixed steps of [Playthrough.dt].
///
/// The game on screen runs at whatever rate the screen does — 46 frames a
/// second on a tired laptop, 144 on a gaming monitor — and the gate replays
/// at exactly sixty. A run recorded frame by frame is therefore a different
/// run from the one the gate plays: the jump comes out a fraction shorter, the
/// shadow reaches the plate a step after the door shut, and the gate says the
/// solution fails on a level you just finished in front of your own eyes.
///
/// So while a run is being recorded the game is not given the frame. It is
/// given the steps the frame adds up to, each exactly as long as the gate's,
/// and whatever is left over waits for the next frame.
class FixedSteps {
  FixedSteps({this.mostPerFrame = 4});

  static const double step = Playthrough.dt;

  /// Ceiling on catch-up in one frame. Past it the leftover is dropped, and
  /// the game runs slower than the clock for a moment — which costs nothing,
  /// because what is being recorded is the steps, not the seconds.
  final int mostPerFrame;

  double _owed = 0;

  /// How many steps [dt] seconds pays for.
  int take(double dt) {
    _owed += dt;
    // A hair under a step counts as one: sixty frames of 1/60 must be sixty
    // steps, not fifty-nine and a rounding error.
    var steps = 0;
    while (_owed >= step - 1e-9) {
      _owed -= step;
      steps++;
      if (steps >= mostPerFrame) {
        _owed = 0;
        break;
      }
    }
    return steps;
  }

  void reset() => _owed = 0;
}

/// Writes down what drove the game, one fixed step at a time, and hands it
/// back as recorded moves.
///
/// It sits between the keyboard and the game ([InputController.shape]), so it
/// can make sure the game is driven only by steps a [Move] can say. Two things
/// a keyboard can do that a move cannot:
///
/// - a press released before the step that reads it, which would be a jump
///   that is not held for even a step; it is held for that one step instead;
/// - a hold with no press, which is a key already down when recording began;
///   it is not a jump until it is pressed.
///
/// Both are shaped *before* the game sees them, so what is played is what is
/// written down, and [Playthrough.movesOf] folds it into moves that
/// [Playthrough] replays step for step.
class RunRecorder {
  final List<InputIntent> steps = [];

  bool _held = false;

  InputIntent take(InputIntent raw) {
    final press = raw.jump;
    final held = press || (raw.jumpHeld && _held);
    _held = held;
    final kept = InputIntent(
      moveAxis: raw.moveAxis.clamp(-1.0, 1.0),
      jump: press,
      jumpHeld: held,
      crouch: raw.crouch,
    );
    steps.add(kept);
    return kept;
  }

  /// How long the run is so far.
  double get seconds => steps.length * Playthrough.dt;

  List<Move> get moves => Playthrough.movesOf(steps);
}
