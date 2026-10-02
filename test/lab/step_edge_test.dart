import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

/// Which past you can stand on is drawn, not guessed: a ducked one gets the
/// lit top every floor has, a standing one does not. Reported from playing:
/// "it needs to be clear which shadow is a step".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<LevelGame>(
    'the edge is on the past you can stand on, and only that one',
    () => LevelGame(levels: [Levels.standOnYourself], inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      final delay = Levels.standOnYourself.delaySeconds;
      final run = Playthrough(game, game.input.sources.first as ScriptedInput)
        ..play(const [Move.right(0.6), Move(2.0, crouch: true), Move(0.2)])
        // Into the stretch where the past is walking, standing up.
        ..play([Move(delay - 2.8 + 0.3)]);
      expect(game.shadow.isActive, isTrue, reason: run.where);
      expect(game.shadow.crouch, lessThan(0.5));
      expect(game.shadow.standable, isFalse, reason: 'walking: no step');

      // And into the stretch where it is ducked.
      run.play(const [Move(1.0)]);
      expect(game.shadow.crouch, greaterThan(0.9), reason: run.where);
      expect(game.shadow.standable, isTrue, reason: 'ducked: a step');
    },
  );
}
