import '../input/input.dart';
import 'level_game.dart';

/// One held input, for a length of time.
///
/// [jump] presses on the first frame of the move and stays held for the rest
/// of it, because the jump is variable-height: a press with no hold is a hop.
///
/// This lives in `lib` rather than in the tests because a recorded run is part
/// of a level now, not part of a test: a level arriving from outside carries
/// its own solution and its own wrong ideas, and whatever decides whether to
/// accept it has to be able to read them.
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

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.seconds == seconds &&
      other.axis == axis &&
      other.jump == jump &&
      other.crouch == crouch;

  @override
  int get hashCode => Object.hash(seconds, axis, jump, crouch);

  @override
  String toString() =>
      'Move(${seconds}s'
      '${axis == 0 ? '' : ' axis $axis'}'
      '${jump ? ' jump' : ''}${crouch ? ' crouch' : ''})';
}

/// Replays a recorded run into a real game and reports when the level was
/// finished, or null if it never was.
///
/// This is what makes a level's design changeable. A puzzle whose solution is
/// only in the designer's head quietly stops being solvable the first time
/// somebody changes a jump height, and nobody finds out until they try to play
/// it. Here the level fails its own test instead.
///
/// It is deliberately one implementation, in one place. The tests run it, the
/// clip renderer runs it to film the game, and the gate that decides whether a
/// level from outside can be published runs it too — three things that have to
/// agree about what "finishable" means.
class Playthrough {
  Playthrough(this.game, this.source);

  final LevelGame game;
  final ScriptedInput source;

  static const double dt = 1 / 60;

  double elapsed = 0;

  /// When each level was finished. A list rather than a single time because
  /// the campaign run-through finishes ten of them in one sitting.
  final List<double> finishes = [];

  /// When the first level was finished, or null if none was.
  double? get finishedAt => finishes.isEmpty ? null : finishes.first;

  bool _wasComplete = false;

  /// Feeds [moves] to the game one frame at a time.
  ///
  /// With [stopWhenComplete], input stops the moment the level is finished —
  /// which is what a player does, and what keeps a solution that overruns its
  /// own ending from walking the *next* level's player away from their spawn
  /// before that level has started.
  void play(List<Move> moves, {bool stopWhenComplete = false}) {
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
        if (game.completed && !_wasComplete) finishes.add(elapsed);
        _wasComplete = game.completed;
        if (stopWhenComplete && game.completed) return;
      }
    }
  }

  /// Where the body is, for tuning a run that does not work yet.
  String get where =>
      't=${elapsed.toStringAsFixed(2)} '
      'x=${game.player.x.toStringAsFixed(0)} '
      'y=${game.player.y.toStringAsFixed(0)} '
      'reloads=${game.reloads}';
}

/// An [InputSource] a recorded run can be fed through, frame by frame.
class ScriptedInput implements InputSource {
  @override
  String get label => 'scripted';

  @override
  bool hasBeenUsed = true;

  InputIntent next = InputIntent.none;

  @override
  InputIntent poll() => next;
}
