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

  /// When each level was finished. A list rather than a single time because
  /// the campaign run-through finishes five of them in one sitting.
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

/// The recorded solutions, one per level.
///
/// They live here rather than inside a test because two tests need them: the
/// per-level ones, which prove each puzzle can be finished, and the campaign
/// run-through, which proves they can be finished one after another in the
/// real game with the real level list.
const walkthroughs = <String, List<Move>>{
  'press-it-early': [
    Move.right(1.8), // out to the plate, the wrong way from the door
    Move(1.2), // stand on it
    Move.left(4.8), // all the way to the door, and wait there
  ],
  'stand-on-yourself': [
    Move.left(3.3), // out to the mark, under the ledge
    Move(2.5), // stand there long enough to leave a solid shadow
    Move.right(0.9), // get out of your own way
    Move(0.8), // wait for it to appear
    Move.left(0.45), // run at it
    Move.left(0.55, jump: true), // up onto its head
    Move.left(0.6, jump: true), // and off the head onto the ledge
    Move.left(1.5), // along to the way out
  ],
  'not-the-same-way-back': [
    Move.left(1.9), // into the corridor, onto the plate
    Move(1.0), // hold it down
    Move.left(0.5), // on to the dead end
    Move.left(0.5, jump: true), // up onto the step
    Move(0.25),
    Move.right(0.3), // a run at the gap
    Move.right(0.75, jump: true), // across onto the upper lane
    Move.right(1.7), // home, above your own footprints
    Move.right(2.5), // down off the end and through the door
  ],
  'take-it-with-you': [
    Move.right(1.9), // out to the plate, away from the drop
    Move(2.5), // stand on it long enough to be worth something
    Move.left(2.9), // back along the shelf
    Move.left(0.7), // off the end, committing
    Move.left(1.0), // to the door at the bottom
    Move.left(1.2), // through it, once your past opens it
  ],
  'both-at-once': [
    Move.left(1.1), // back to the plate
    Move(1.2), // hold it
    Move.right(2.0), // to the door, and wait at it
    Move.right(1.2), // through, once the shadow takes over the plate
    Move.right(0.6), // out to the mark, short of the ledge
    Move(2.0), // stand there: this is the second job
    Move.left(0.9), // out of your own way
    Move(0.6),
    Move.right(0.45), // run at what you left behind
    Move.right(0.55, jump: true), // onto its head
    Move.right(0.6, jump: true), // and off the head onto the ledge
    Move.right(1.5), // along to the way out
  ],
  'go-in-low': [
    Move.left(0.5), // out to the mouth of the roof
    Move.left(2.9, crouch: true), // under it, bent over, all the way to the gap
    Move(2.0), // stand up: the only place in the level you are allowed to
    Move.left(1.2, crouch: true), // back under the roof, out of your own way
    Move(0.8), // wait for it
    Move.right(1.2, crouch: true), // back to the mouth of the gap
    Move(0.2),
    Move.right(0.5, jump: true), // up onto your own head
    Move.right(0.6, jump: true), // and off it onto the roof
    Move.right(1.2), // along to the way out
  ],
  'hold-your-own-door': [
    Move.left(2.1), // out to the plate, the wrong way from everything
    Move(3.0), // hold it. this is how long the door will be open for
    Move.left(0.6), // on past it, into the open, out of your own way
    Move(1.6), // and wait there for yourself to arrive
    Move.right(0.75, jump: true), // a running jump onto your own head
    Move(0.2),
    Move.right(0.75, jump: true), // off it onto the shelf
    Move.right(1.6), // along the shelf, through the door you are holding open
    Move.right(1.5), // to the way out
  ],
  'close-what-you-opened': [
    // The whole level, and it is two keys. The thinking is in knowing not to
    // wait: the door has been open since the moment the key was touched, and
    // the only thing that shuts it is the body four and a half seconds behind
    // coming to touch it again.
    Move.left(1.7), // out to the key — the opposite way from the door
    Move.right(2.8), // straight back, and through, before your past arrives
  ],
  'your-shadow-is-not-here': [
    // The mark is one body's width left of where the beam ends. Further in is
    // a shadow that does not exist; much further out is a jump that does not
    // reach.
    Move.left(1.58), // out to the mark, past the lit ground
    Move(2.2), // stand there, leaving something to climb
    Move.left(0.6), // out of your own way
    Move(1.3), // and wait for yourself to arrive
    Move.right(0.12), // a short run — any longer and you sail over your head
    Move.right(0.55, jump: true), // onto it
    Move(0.1),
    Move.right(0.6, jump: true), // off it onto the shelf
    Move.right(1.6), // along to the way out
  ],
  'two-not-one': [
    // The gate wants both plates held at the same moment, and the only pair of
    // hands that can do that is the two of you that are already four seconds
    // apart. So the far plate first — it is the one the seven-second shadow
    // comes back for — and the near one after, and the gap between the two
    // has to fit inside the gap between them.
    Move.left(3.1), // out to the far plate, past the near one
    Move(1.8), // stand on it: this is how wide the window will be
    Move.right(2.5), // back to the near plate
    Move(1.8), // and stand on that one
    Move.right(1.3), // up to the gate
    Move(1.6), // wait for both of you to arrive
    Move.right(1.6), // through, while both of them are standing
  ],
};
