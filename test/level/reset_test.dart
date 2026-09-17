import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/audio/sfx.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'solution.dart';

/// Every sound the game asked for, in order.
class _Heard implements AudioOut {
  final List<Sfx> played = [];

  @override
  Future<void> preload() async {}

  @override
  void play(Sfx sfx, {double volume = 1.0}) => played.add(sfx);
}

/// Being put back has to be something you can see and hear.
///
/// It used to happen between two frames with nothing to mark it: you were
/// somewhere, and then without a frame in between you were at the spawn. That
/// reads as the game glitching rather than as dying, and in the level where
/// the shadow kills you it is genuinely hard to tell anything happened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<LevelGame>(
    'a reload darkens the screen and then clears it',
    () => LevelGame(
      levels: [Levels.notTheSameWayBack],
      inputs: [ScriptedInput()],
    ),
    (game) async {
      await game.ready();
      expect(game.resetFlash.isShowing, isFalse);

      game.reload();
      expect(game.resetFlash.isShowing, isTrue);

      // And it lets go on its own, without anyone clearing it. A second is
      // comfortably past however long the wash is tuned to last — the point is
      // that it ends, not exactly when.
      final run = Playthrough(game, game.input.sources.first as ScriptedInput)
        ..play(const [Move(1.0)]);
      expect(
        game.resetFlash.isShowing,
        isFalse,
        reason: 'still dark a second later: ${run.where}',
      );
    },
  );

  testWithGame<LevelGame>(
    'a reload is audible',
    () => LevelGame(
      levels: [Levels.notTheSameWayBack],
      inputs: [ScriptedInput()],
      audio: _heard,
    ),
    (game) async {
      _heard.played.clear();
      await game.ready();

      game.reload();
      expect(_heard.played, contains(Sfx.reset));
    },
  );

  testWithGame<LevelGame>(
    'moving to another level does not carry the wash over with it',
    () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      game.reload();
      expect(game.resetFlash.isShowing, isTrue);

      await game.goTo(2);
      expect(
        game.resetFlash.isShowing,
        isFalse,
        reason: 'a fresh level must not open in the dark',
      );
    },
  );

  testWithGame<LevelGame>(
    'dying to your own shadow is marked, not silent',
    () => LevelGame(
      levels: [Levels.notTheSameWayBack],
      inputs: [ScriptedInput()],
      audio: _heard,
    ),
    (game) async {
      _heard.played.clear();
      await game.ready();
      final run = Playthrough(game, game.input.sources.first as ScriptedInput)
        // The wrong idea this level pins: back out the way you came in and
        // wait by the door, where your own past is walking.
        ..play(const [
          Move.left(1.9),
          Move(1.0),
          Move.right(2.5),
          Move(4),
        ]);

      expect(game.reloads, greaterThan(0), reason: run.where);
      expect(_heard.played, contains(Sfx.reset));
    },
  );
}

final _heard = _Heard();
