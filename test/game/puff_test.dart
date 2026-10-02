import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/puff.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

/// Dust, which is paint and nothing else (`docs/phase-11-feel.md` §5).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Iterable<Puff> puffs(LevelGame game) => game.world.children.whereType<Puff>();

  testWithGame<LevelGame>(
    'a death comes apart into dust, a reset does not, and the dust goes',
    () => LevelGame(
      levels: [Levels.notTheSameWayBack],
      inputs: [ScriptedInput()],
    ),
    (game) async {
      await game.ready();
      game.retry();
      game.reload();
      game.update(1 / 60);
      expect(puffs(game), isEmpty, reason: 'a button, or the editor');

      game.die();
      game.update(1 / 60);
      expect(puffs(game), hasLength(1));

      for (var i = 0; i < 90; i++) {
        game.update(1 / 60);
      }
      expect(puffs(game), isEmpty, reason: 'still there after 1.5s');
    },
  );
}
