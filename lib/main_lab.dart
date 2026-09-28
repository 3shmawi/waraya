import 'package:flutter/material.dart';

import 'audio/flame_audio_out.dart';
import 'editor/editor_screen.dart';
import 'level/bundled_levels.dart';
import 'level/file_levels.dart';
import 'level/level.dart';
import 'level/level_source.dart';
import 'level/level_upload.dart';
import 'level/levels.dart';
import 'level/supabase_backend.dart';
import 'licenses.dart';

/// The tuning bench — the shadow, on grey boxes — and the level editor.
///
/// ```sh
/// flutter run -t lib/main_lab.dart
///
/// # or, to work on levels that are not in the code:
/// flutter run -t lib/main_lab.dart --dart-define=WARAYA_LEVELS=levels/
///
/// # or the same folder as it was at build time — the web, which has no disk:
/// flutter run -t lib/main_lab.dart --dart-define=WARAYA_LEVELS=bundled
/// ```
///
/// A second entry point rather than a mode inside `main.dart`, so the shipping
/// app never carries the editor or the debug sliders.
///
/// It opens editing (`docs/phase-9-editor.md`): the level stands still with
/// its pieces outlined, you drag them about, and Tab puts you in it — the same
/// `LevelGame`, not a preview of one. From here a level is recorded (its
/// solution and its wrong ideas, in the gate's own fixed steps), checked by
/// the gate's own rules as you work, saved as JSON, and sent to be published.
/// Signing in is here and nowhere else — an account is for sending a level,
/// never for playing one.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  final authoring = _authoring;
  LevelUpload? upload;
  try {
    upload = LevelUpload(await SupabaseBackend.start());
  } catch (error) {
    // The bench works without it; only the cloud button goes away.
    debugPrint('no uploading this session: $error');
  }
  runApp(
    ShadowLabApp(
      authoring: authoring,
      upload: upload,
      // Read once before the first frame: a bench that opens on a spinner and
      // then a level is two things to look at where there should be one.
      levels: authoring == null ? null : await authoring.load(),
    ),
  );
}

/// Where the bench reads levels from, or null for the one written in Dart.
LevelSource? get _authoring {
  const path = String.fromEnvironment('WARAYA_LEVELS');
  if (path.isEmpty) return null;
  return path == 'bundled' ? const BundledLevels() : FileLevels(path);
}

class ShadowLabApp extends StatelessWidget {
  const ShadowLabApp({super.key, this.authoring, this.levels, this.upload});

  /// Set when the bench was pointed at a file or folder, so the editor can
  /// offer to read it again — and save next to it.
  final LevelSource? authoring;

  /// What was on the disk at startup. Null means the bench level in the code.
  final List<Level>? levels;

  /// Where the cloud button sends a level. Null hides the button.
  final LevelUpload? upload;

  /// Unlike the campaign, this one needs Material: the editor's panels are
  /// text boxes, switches and menus, and the extra bundle weight does not
  /// matter in a build that is never shipped.
  @override
  Widget build(BuildContext context) {
    final authoring = this.authoring;
    final disk = levels ?? const <Level>[];
    return MaterialApp(
      title: 'waraya · shadow lab',
      debugShowCheckedModeBanner: false,
      // The bundled monospace, not Material's Roboto: Roboto is fetched from
      // Google's CDN on the web, and on a connection that cannot reach it the
      // upload dialog came up with every word of it missing.
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        fontFamily: 'LiberationMono',
        // The monospace has no Arabic, and a level's name and lesson are
        // Arabic. Without the bundled face behind it the editor's boxes and
        // menus drew them as rows of empty squares.
        fontFamilyFallback: const [arabicFontFamily],
      ),
      home: Scaffold(
        body: EditorScreen(
          startFrom: disk.isEmpty ? Levels.lab : disk.first,
          extraLevels: disk,
          upload: upload,
          audio: FlameAudioOut(),
          onReread: authoring?.load,
          saveFolder: authoring is FileLevels ? authoring.path : null,
        ),
      ),
    );
  }
}
