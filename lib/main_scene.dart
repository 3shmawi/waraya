import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'game/waraya_game.dart';
import 'licenses.dart';

/// The Phase 1 scene with nothing to solve in it — one walker, one horizon.
///
/// ```sh
/// flutter run -t lib/main_scene.dart
/// ```
///
/// It was `main.dart` until Phase 10, which made it the default build target:
/// a store build with no `-t` shipped this instead of the game.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  runApp(const WarayaApp());
}

class WarayaApp extends StatelessWidget {
  const WarayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No MaterialApp: the game owns the whole surface, and skipping Material
    // keeps the web bundle a little smaller.
    return GameWidget.controlled(
      gameFactory: () => WarayaGame(audio: FlameAudioOut()),
    );
  }
}
