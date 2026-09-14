import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'game/waraya_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  runApp(const WarayaApp());
}

/// Declares the bundled font's licence to Flutter, so it appears wherever the
/// app lists its open-source licences.
///
/// The SIL Open Font License requires the licence and copyright notice to be
/// distributed with the font. The text ships as an asset and is read here
/// rather than pasted into source, so the two cannot drift apart.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'LiberationMono',
    ], await rootBundle.loadString('assets/fonts/LiberationMono-LICENSE.txt'));
  });
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
