import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/audio/haptics.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';
import 'package:waraya/ui/level_title.dart';

class _Felt implements HapticsOut {
  final List<Buzz> buzzes = [];

  @override
  void buzz(Buzz strength) => buzzes.add(strength);
}

/// The level's name on screen, and the buzz in the hand
/// (`docs/phase-11-feel.md` §3 and §2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LevelTitle titleOf(LevelGame game) =>
      game.camera.viewport.children.whereType<LevelTitle>().single;

  void run(LevelGame game, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      game.update(1 / 60);
    }
  }

  testWithGame<LevelGame>(
    'the name arrives in the middle, then settles in its corner',
    () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      game.onGameResize(Vector2(1200, 600));
      game.update(1 / 60);
      final title = titleOf(game);
      expect(title.settled, 0);
      expect(title.position.x, lessThan(1000), reason: 'not in the corner');

      run(game, LevelTitle.holdSeconds + LevelTitle.settleSeconds + 0.1);
      expect(title.settled, 1);
      expect(title.position.x, closeTo(1200 - 16, 0.5));

      // A death is not a new level: the name stays where it is.
      game.reload();
      game.update(1 / 60);
      expect(title.settled, 1);

      // The next level is, and it makes its entrance again.
      await game.goTo(1);
      game.update(1 / 60);
      expect(title.settled, 0);
    },
  );

  testWithGame<LevelGame>(
    'the clips and store pictures keep the title in its corner',
    () => LevelGame(
      levels: Levels.campaign,
      inputs: [ScriptedInput()],
      titleIntro: false,
    ),
    (game) async {
      await game.ready();
      game.onGameResize(Vector2(1200, 600));
      game.update(1 / 60);
      expect(titleOf(game).settled, 1);
    },
  );

  testWithGame<LevelGame>(
    'the title keeps out of the buttons in the corner',
    () => LevelGame(
      levels: Levels.campaign,
      inputs: [ScriptedInput()],
      titleIntro: false,
    ),
    (game) async {
      await game.ready();
      game.reservedTopRight = const Size(150, 54);
      for (final width in const [1600.0, 900.0, 640.0]) {
        game.onGameResize(Vector2(width, 400));
        game.update(1 / 60);
        final title = titleOf(game);
        final right = title.position.x;
        final top = title.position.y;
        // Either left of the buttons, or below them.
        expect(
          right <= width - 150 || top >= 54,
          isTrue,
          reason: 'at $width wide the title sits on the buttons',
        );
      }
    },
  );

  testWithGame<LevelGame>(
    'the title speaks the game\'s language, and Arabic where there is no other',
    () => LevelGame(levels: Levels.campaign, inputs: [ScriptedInput()]),
    (game) async {
      await game.ready();
      game.lang = Lang.en;
      game.update(1 / 60);
      final texts = titleOf(game).children.whereType<TextComponent>().toList();
      expect(texts.first.text, Levels.campaign.first.nameEn);
      expect(texts.last.text, Levels.campaign.first.teachesEn);
    },
  );

  testWithGame<LevelGame>(
    'a death buzzes, and asking to start over does not',
    () => LevelGame(
      levels: [Levels.notTheSameWayBack],
      inputs: [ScriptedInput()],
      haptics: _felt,
    ),
    (game) async {
      await game.ready();
      _felt.buzzes.clear();
      game.reload();
      expect(_felt.buzzes, [Buzz.heavy]);
      game.retry();
      expect(_felt.buzzes, [Buzz.heavy], reason: 'the button you pressed');
    },
  );
}

final _Felt _felt = _Felt();
