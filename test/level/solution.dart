import 'package:waraya/input/input.dart';
import 'package:waraya/level/level_game.dart';

/// One held input, for a length of time.
///
/// [jump] presses on the first frame of the move and stays held for the rest
/// of it, because the jump is variable-height: a press with no hold is a hop.
class Move {
  const Move(
    this.seconds, {
    this.axis = 0,
    this.jump = false,
    this.crouch = false,
  });

  const Move.left(double seconds, {bool jump = false, bool crouch = false})
    : this(seconds, axis: -1, jump: jump, crouch: crouch);

  const Move.right(double seconds, {bool jump = false, bool crouch = false})
    : this(seconds, axis: 1, jump: jump, crouch: crouch);

  final double seconds;
  final double axis;
  final bool jump;
  final bool crouch;
}

/// Replays a solution into a real game and reports when the level was
/// finished, or null if it never was.
///
/// This is what makes a level's design testable. A puzzle whose solution is
/// only in the designer's head quietly stops being solvable the first time
/// someone changes a jump height, and nobody finds out until they try to play
/// it. Here the level fails its own test instead.
class Playthrough {
  Playthrough(this.game, this.source);

  final LevelGame game;
  final ScriptedInput source;

  static const double dt = 1 / 60;

  double elapsed = 0;
  double? finishedAt;

  void play(List<Move> moves) {
    for (final move in moves) {
      final frames = (move.seconds / dt).round();
      for (var frame = 0; frame < frames; frame++) {
        source.next = InputIntent(
          moveAxis: move.axis,
          jump: move.jump && frame == 0,
          jumpHeld: move.jump,
          crouch: move.crouch,
        );
        game.update(dt);
        elapsed += dt;
        if (game.completed && finishedAt == null) finishedAt = elapsed;
      }
    }
  }

  /// Where the body is, for tuning a solution that does not work yet.
  String get where =>
      't=${elapsed.toStringAsFixed(2)} '
      'x=${game.player.x.toStringAsFixed(0)} '
      'y=${game.player.y.toStringAsFixed(0)} '
      'reloads=${game.reloads}';
}

/// An [InputSource] a test can drive frame by frame.
class ScriptedInput implements InputSource {
  @override
  String get label => 'scripted';

  @override
  bool hasBeenUsed = true;

  InputIntent next = InputIntent.none;

  @override
  InputIntent poll() => next;
}
