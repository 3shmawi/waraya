import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_game.dart';
import 'package:waraya/level/levels.dart';

import 'package:waraya/level/playthrough.dart';
import 'package:waraya/ui/level_fade.dart';

/// The environment is paint, not geometry.
///
/// The campaign runs inside the photographed scene and the bench runs on grey
/// boxes, but it is one class and one set of rectangles — the look only
/// chooses colours and adds layers behind everything. The way to keep that
/// true is to play the whole campaign again with the scenery switched on and
/// require the same recorded solutions to still work: if dressing a level ever
/// starts moving something the player can touch, this fails.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWithGame<LevelGame>(
    'the campaign plays identically in the lit scene',
    () => LevelGame(
      levels: Levels.campaign,
      inputs: [ScriptedInput()],
      look: LevelLook.silhouette,
    ),
    (game) async {
      await game.ready();
      final run = Playthrough(game, game.input.sources.first as ScriptedInput);

      for (final (i, level) in Levels.campaign.indexed) {
        expect(
          game.level.id,
          level.id,
          reason: 'expected to be on ${level.id} by now (${run.where})',
        );
        // And in its own place: a chapter's levels are played in the
        // chapter's scene, with the same rectangles as everywhere else.
        expect(game.shownPlace, level.place, reason: level.id);
        run.play(level.solution, stopWhenComplete: true);
        expect(
          game.completed,
          isTrue,
          reason: '${level.id} was not finished lit (${run.where})',
        );
        // The beat to the next level, and a chapter's card on top of it when
        // the next one is somewhere else.
        final next = i + 1 < Levels.campaign.length
            ? Levels.campaign[i + 1]
            : null;
        final card = next != null && next.place != level.place
            ? LevelFade.chapterSeconds
            : 0.0;
        run.play([Move(1.2 + card)]);
      }

      expect(run.finishes, hasLength(Levels.campaign.length));
      expect(game.reloads, 0);
    },
  );
}
