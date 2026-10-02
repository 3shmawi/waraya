import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/level/props.dart';

/// The shadow counter on trial (`docs/phase-11-feel.md` §4.2): the mark says
/// where your past will be a second from now, and is right.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<LevelGame>(
    'the mark is where the shadow stands one second later',
    () => LevelGame(levels: [Levels.pressItEarly], inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      expect(game.settings.showForecast, isFalse, reason: 'off for players');
      final forecast = game.world.children.whereType<ShadowForecast>().single;
      final run = Playthrough(game, game.input.sources.first as ScriptedInput)
        ..play(const [Move.right(1.2), Move.left(1.0), Move(0.6)]);
      final said = forecast.point!;
      run.play(const [Move(1.0)]);
      expect(game.shadow.x, closeTo(said.dx, 1), reason: run.where);
      expect(game.shadow.y, closeTo(said.dy, 1));
    },
  );
}
