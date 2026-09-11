import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'game/waraya_game.dart';

void main() {
  runApp(const WarayaApp());
}

class WarayaApp extends StatelessWidget {
  const WarayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // No MaterialApp: the game owns the whole surface, and skipping Material
    // keeps the web bundle a little smaller.
    return GameWidget.controlled(gameFactory: WarayaGame.new);
  }
}
