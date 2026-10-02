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

  testWithGame<LevelGame>(
    'and only in the level that teaches the step',
    () => LevelGame(levels: [Levels.goInLow], inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      // Its own solution ducks and climbs: a step is there, and not marked.
      final input = game.input.sources.first as ScriptedInput;
      var ducked = false;
      for (final intent in Playthrough.intentsOf(Levels.goInLow.solution)) {
        input.next = intent;
        game.update(Playthrough.dt);
        if (game.standableShadows.isNotEmpty) ducked = true;
        expect(game.shadow.standable, isFalse);
      }
      expect(ducked, isTrue, reason: 'the level does use a step');
    },
  );

  for (final id in Levels.showsSteps) {
    final level = Levels.campaign.firstWhere((l) => l.id == id);
    testWithGame<LevelGame>(
      '$id is marked because its solution stands on a past',
      () => LevelGame(levels: [level], inputs: [ScriptedInput()]),
      (game) async {
        await game.ready();
        final input = game.input.sources.first as ScriptedInput;
        var stood = false;
        for (final intent in Playthrough.intentsOf(level.solution)) {
          input.next = intent;
          game.update(Playthrough.dt);
          if (game.player.isOnShadow) stood = true;
        }
        expect(stood, isTrue);
      },
    );
  }
}
