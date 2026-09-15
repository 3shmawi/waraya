import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'audio/flame_audio_out.dart';
import 'level/level_game.dart';
import 'level/levels.dart';
import 'ui/lab_controls.dart';

/// The tuning bench — the shadow, on grey boxes, with every number exposed.
///
/// ```sh
/// flutter run -t lib/main_lab.dart
/// ```
///
/// A second entry point rather than a mode inside `main.dart`, so the shipping
/// app never carries the debug sliders and the finished Phase 1 scene is not
/// touched at all by this phase.
void main() => runApp(const ShadowLabApp());

class ShadowLabApp extends StatelessWidget {
  const ShadowLabApp({super.key});

  /// Unlike `main.dart`, this one needs Material: `Slider` and `Switch` want a
  /// Material ancestor, and the extra bundle weight does not matter in a build
  /// that is never shipped.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'waraya · shadow lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: GameWidget<LevelGame>.controlled(
        gameFactory: () =>
            LevelGame(levels: [Levels.lab], audio: FlameAudioOut()),
        overlayBuilderMap: {
          'controls': (context, game) =>
              LabControls(settings: game.settings, onReload: game.reload),
        },
        initialActiveOverlays: const ['controls'],
      ),
    );
  }
}
