import 'dart:convert';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'audio/flame_audio_out.dart';
import 'level/file_levels.dart';
import 'level/level.dart';
import 'level/level_game.dart';
import 'level/level_source.dart';
import 'level/levels.dart';
import 'licenses.dart';
import 'ui/lab_controls.dart';

/// The tuning bench — the shadow, on grey boxes, with every number exposed.
///
/// ```sh
/// flutter run -t lib/main_lab.dart
///
/// # or, to work on levels that are not in the code:
/// flutter run -t lib/main_lab.dart --dart-define=WARAYA_LEVELS=levels/
/// ```
///
/// A second entry point rather than a mode inside `main.dart`, so the shipping
/// app never carries the debug sliders and the finished Phase 1 scene is not
/// touched at all by this phase.
///
/// Pointed at a file or a folder it becomes the level editor's other half:
/// the folder button re-reads the JSON without restarting, and the code button
/// prints the level on screen as JSON to start a new one from. That loop —
/// edit the file, alt-tab, look — is what makes "a level is data" true in
/// practice; a level being JSON is worth nothing on its own if seeing your
/// edit means a rebuild.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  final authoring = _authoring;
  runApp(
    ShadowLabApp(
      authoring: authoring,
      // Read once before the first frame: a bench that opens on a spinner and
      // then a level is two things to look at where there should be one.
      levels: authoring == null ? null : await authoring.load(),
    ),
  );
}

/// Where the bench reads levels from, or null for the one written in Dart.
LevelSource? get _authoring {
  const path = String.fromEnvironment('WARAYA_LEVELS');
  return path.isEmpty ? null : FileLevels(path);
}

class ShadowLabApp extends StatefulWidget {
  const ShadowLabApp({super.key, this.authoring, this.levels});

  /// Set when the bench was pointed at a file or folder, so the panel can
  /// offer to read it again.
  final LevelSource? authoring;

  /// What was on the disk at startup. Null means the bench level in the code.
  final List<Level>? levels;

  @override
  State<ShadowLabApp> createState() => _ShadowLabAppState();
}

class _ShadowLabAppState extends State<ShadowLabApp> {
  late final LevelGame _game = LevelGame(
    levels: widget.levels ?? [Levels.lab],
    audio: FlameAudioOut(),
  );

  String? _status;

  /// Reads the levels again and swaps them under the running game.
  ///
  /// A failure is reported and nothing else happens: while a level is being
  /// written, a broken file is the normal state of it for a few seconds, and
  /// throwing the level you are looking at away every time you save mid-edit
  /// would make the loop unusable.
  Future<void> _reread() async {
    try {
      final levels = await widget.authoring!.load();
      await _game.replaceLevels(levels);
      setState(() {
        _status = levels.isEmpty
            ? 'nothing to read — keeping ${_game.level.id}'
            : '${levels.length} level(s) · on ${_game.level.id}';
      });
    } catch (error) {
      setState(() => _status = '$error');
    }
  }

  /// Prints the level on screen as JSON.
  ///
  /// The starting point for a new one: nobody types thirty rectangles from
  /// nothing, they take a level that already stands up and move it.
  void _dump() {
    debugPrint(
      const JsonEncoder.withIndent('  ').convert(_game.level.toJson()),
    );
    setState(() => _status = '${_game.level.id} printed to the console');
  }

  /// Unlike `main.dart`, this one needs Material: `Slider` and `Switch` want a
  /// Material ancestor, and the extra bundle weight does not matter in a build
  /// that is never shipped.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'waraya · shadow lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: GameWidget<LevelGame>(
        game: _game,
        overlayBuilderMap: {
          'controls': (context, game) => LabControls(
            settings: game.settings,
            onReload: game.reload,
            onReread: widget.authoring == null ? null : _reread,
            onDump: _dump,
            status: _status,
          ),
        },
        initialActiveOverlays: const ['controls'],
      ),
    );
  }
}
