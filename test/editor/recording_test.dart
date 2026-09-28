// The one test the editor cannot be without (`docs/phase-9-editor.md` §٣).
//
// A person plays at whatever rate their screen runs; the gate replays at
// exactly sixty steps a second. If what the editor writes down while you play
// is not the run the gate replays, then every level made in the editor is a
// level whose solution "fails" on a run its author just finished — and the
// editor is lying about the one thing it is for.
//
// So: a player who knows a level's solution plays it in real time, at 30, 46
// and 144 frames a second and at a rate that will not sit still, and whatever
// the editor recorded goes to the gate itself.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_game.dart';
import 'package:waraya/editor/run_recorder.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

/// A keyboard, as far as the game can tell: state that changes between
/// frames, and a press that is gone once read.
class _Hands implements InputSource {
  @override
  String get label => 'hands';

  @override
  bool hasBeenUsed = true;

  double axis = 0;
  bool held = false;
  bool crouch = false;
  bool _pressed = false;

  void press() => _pressed = true;

  @override
  InputIntent poll() {
    final intent = InputIntent(
      moveAxis: axis,
      jump: _pressed,
      jumpHeld: held,
      crouch: crouch,
    );
    _pressed = false;
    return intent;
  }
}

/// Someone playing [moves] off a clock on the wall — not off the game's
/// steps, which is the whole difference being tested.
class _Player {
  _Player(this.moves, this.hands);

  final List<Move> moves;
  final _Hands hands;
  int _at = -1;

  void at(double seconds) {
    var index = 0;
    var start = 0.0;
    while (index < moves.length && seconds >= start + moves[index].seconds) {
      start += moves[index].seconds;
      index++;
    }
    if (index >= moves.length) {
      hands
        ..axis = 0
        ..held = false
        ..crouch = false;
      return;
    }
    final move = moves[index];
    if (index != _at && move.jump) hands.press();
    _at = index;
    hands
      ..axis = move.axis
      ..held = move.jump
      ..crouch = move.crouch;
  }
}

/// Frame lengths that come round in turn.
const Map<String, List<double>> _rates = {
  '30 fps': [1 / 30],
  '46 fps': [1 / 46],
  '144 fps': [1 / 144],
  'a rate that will not sit still': [1 / 30, 1 / 144, 1 / 50, 1 / 90, 1 / 20],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moves and steps', () {
    test('every recorded run in the campaign folds back to itself', () {
      for (final level in Levels.campaign) {
        for (final run in [level.solution, ...level.wrongIdeas]) {
          final steps = Playthrough.intentsOf(run).toList();
          final again = Playthrough.intentsOf(Playthrough.movesOf(steps));
          expect(
            again.map((i) => i.toString()).toList(),
            steps.map((i) => i.toString()).toList(),
            reason: level.id,
          );
        }
      }
    });

    test('a frame pays for exactly as many steps as it lasted', () {
      final clock = FixedSteps(mostPerFrame: 1000);
      var steps = 0;
      for (var i = 0; i < 144; i++) {
        steps += clock.take(1 / 144);
      }
      expect(steps, 60);
    });

    test('a tap shorter than a step is still a jump the moves can say', () {
      final recorder = RunRecorder();
      recorder.take(const InputIntent(moveAxis: 1, jump: true));
      recorder.take(const InputIntent(moveAxis: 1));
      expect(recorder.moves, [
        const Move(0.017, axis: 1, jump: true),
        const Move(0.017, axis: 1),
      ]);
    });

    test('a key already held when recording starts is not a jump', () {
      final recorder = RunRecorder();
      recorder.take(const InputIntent(jumpHeld: true));
      recorder.take(const InputIntent(jumpHeld: true));
      expect(recorder.moves, [const Move(0.033)]);
    });
  });

  for (final level in [
    Levels.pressItEarly,
    Levels.standOnYourself,
    Levels.closeWhatYouOpened,
    Levels.twoNotOne,
  ]) {
    group('recorded by hand, replayed by the gate: ${level.id}', () {
      for (final MapEntry(key: rate, value: frames) in _rates.entries) {
        final hands = _Hands();
        testWithGame<EditorGame>(
          rate,
          () => EditorGame(level: level, inputs: [hands]),
          (game) async {
            RunEnded? ended;
            game.onRunEnded = (run) => ended = run;
            await game.record(level, RunKind.solution);
            final player = _Player(level.solution, hands);
            var clock = 0.0;
            for (var i = 0; ended == null && clock < 60; i++) {
              final dt = frames[i % frames.length];
              clock += dt;
              player.at(clock);
              game.update(dt);
            }
            expect(ended, isNotNull, reason: 'the recording never stopped');
            expect(ended!.finished, isTrue, reason: 'the take did not finish');

            final recorded = Level(
              id: level.id,
              name: level.name,
              teaches: level.teaches,
              delays: level.delays,
              spawnX: level.spawnX,
              floorTop: level.floorTop,
              goal: level.goal,
              blocks: level.blocks,
              plates: level.plates,
              toggles: level.toggles,
              doors: level.doors,
              lights: level.lights,
              markers: level.markers,
              solution: ended!.moves,
              wrongIdeas: level.wrongIdeas,
            );
            final verdict = await checkLevel(
              recorded,
              cheapIsTheLesson: Levels.cheapByDesign.contains(level.id),
            );
            expect(verdict.accepted, isTrue, reason: '$verdict');
          },
        );
      }
    });
  }
}
