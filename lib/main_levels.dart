import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'licenses.dart';
import 'level/level.dart';
import 'level/level_game.dart';
import 'level/level_source.dart';

/// The puzzles, in teaching order.
///
/// ```sh
/// flutter run -t lib/main_levels.dart
/// ```
///
/// A third entry point rather than a mode: `main.dart` is the finished
/// environment, `main_lab.dart` is the bench with all the sliders, and this is
/// the campaign with none of them. Nothing here can be tuned mid-play on
/// purpose — a level is meant to be beaten at the numbers it was designed
/// around.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  // Where the levels come from is one line, and today it is the ones that
  // ship in the app. When there is a server, it becomes:
  //
  //   LevelsThenExtras(const BuiltInLevels(), SupabaseLevels(...))
  //
  // and nothing below this line changes. See docs/backend-plan.md.
  const source = BuiltInLevels();
  runApp(WarayaLevels(levels: await source.load()));
}

class WarayaLevels extends StatelessWidget {
  const WarayaLevels({super.key, required this.levels});

  final List<Level> levels;

  @override
  Widget build(BuildContext context) {
    // No MaterialApp: the game owns the whole surface, and skipping Material
    // keeps the web bundle a little smaller.
    return GameWidget.controlled(
      gameFactory: () => LevelGame(
        levels: levels,
        audio: FlameAudioOut(),
        // The puzzles are played in the scene from Phase 1, not on the bench's
        // grey boxes. Same class, same geometry, same numbers — only the paint
        // differs. `main_lab.dart` keeps the grey deliberately: art flatters a
        // mechanic, and the bench exists to find out whether one holds up
        // without help.
        look: LevelLook.silhouette,
      ),
    );
  }
}
