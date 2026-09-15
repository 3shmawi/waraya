import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'level/level_game.dart';
import 'level/levels.dart';

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
void main() => runApp(const WarayaLevels());

class WarayaLevels extends StatelessWidget {
  const WarayaLevels({super.key});

  @override
  Widget build(BuildContext context) {
    // No MaterialApp: the game owns the whole surface, and skipping Material
    // keeps the web bundle a little smaller.
    return GameWidget.controlled(
      gameFactory: () =>
          LevelGame(levels: Levels.campaign, audio: FlameAudioOut()),
    );
  }
}
