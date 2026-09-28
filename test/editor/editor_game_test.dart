// The editor's game: the modes, and the promises each one keeps.
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/editor/editor_doc.dart';
import 'package:waraya/editor/editor_game.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/level/props.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final level = Levels.standOnYourself;

  /// Frames of one length until something reports, or a minute passes.
  RunEnded? runFor(EditorGame game, double dt, {double seconds = 60}) {
    RunEnded? ended;
    game.onRunEnded = (run) => ended = run;
    for (var t = 0.0; ended == null && t < seconds; t += dt) {
      game.update(dt);
    }
    return ended;
  }

  testWithGame<EditorGame>(
    'editing moves nothing, however long it is left',
    () => EditorGame(level: level),
    (game) async {
      game.update(1 / 60);
      final x = game.player.x;
      final y = game.player.y;
      for (var i = 0; i < 600; i++) {
        game.update(1 / 60);
      }
      expect(game.mode, EditorMode.editing);
      expect((game.player.x, game.player.y), (x, y));
      expect(game.shadow.isActive, isFalse, reason: 'no past piles up');
      expect(game.player.isGrounded, isTrue, reason: 'stood, not hanging');
    },
  );

  testWithGame<EditorGame>(
    'a replay of the solution finishes, in the gate\'s time',
    () => EditorGame(level: level),
    (game) async {
      await game.replay(level, level.solution);
      final ended = runFor(game, 1 / 37);
      expect(ended?.finished, isTrue);
      expect(game.mode, EditorMode.editing, reason: 'and hands back');
    },
  );

  testWithGame<EditorGame>(
    'a replay of a wrong idea runs out without finishing',
    () => EditorGame(level: level),
    (game) async {
      await game.replay(level, level.wrongIdeas.first);
      final ended = runFor(game, 1 / 90);
      expect(ended, isNotNull);
      expect(ended!.finished, isFalse);
    },
  );

  final hands = _Scripted();
  testWithGame<EditorGame>(
    'a "wrong idea" that reaches the goal is stopped there and called what it '
    'is',
    () => EditorGame(level: Levels.pressItEarly, inputs: [hands]),
    (game) async {
      await game.record(Levels.pressItEarly, RunKind.wrongIdea);
      final steps = Playthrough.intentsOf(
        Levels.pressItEarly.solution,
      ).toList();
      RunEnded? ended;
      game.onRunEnded = (run) => ended = run;
      for (final step in steps) {
        hands.next = step;
        game.update(1 / 60);
        if (ended != null) break;
      }
      expect(ended?.kind, RunKind.wrongIdea);
      expect(ended?.finished, isTrue);
    },
  );

  testWithGame<EditorGame>(
    'a burst of edits builds the level once, not once per edit on top of each '
    'other',
    () => EditorGame(level: level),
    (game) async {
      final doc = EditorDoc.fromLevel(level);
      final edits = <Future<void>>[];
      for (var i = 0; i < 6; i++) {
        doc.spawnX += 10;
        edits.add(game.edit(doc.toLevel()));
      }
      await Future.wait(edits);
      game.update(1 / 60);
      expect(game.world.children.whereType<Blocks>().length, 1);
      expect(game.level.spawnX, doc.spawnX, reason: 'and it is the last one');
    },
  );
}

class _Scripted implements InputSource {
  @override
  String get label => 'scripted';

  @override
  bool hasBeenUsed = true;

  InputIntent next = InputIntent.none;

  @override
  InputIntent poll() => next;
}
