import 'dart:convert';
import 'dart:io';

import 'level.dart';
import 'level_source.dart';

/// Levels read off the disk, for authoring.
///
/// This is what makes "a level is data, not code" true in practice rather
/// than on paper. A level being JSON is worth nothing on its own if seeing
/// your edit means a rebuild: the loop has to be *edit the file, alt-tab,
/// look*. So the bench reads from here and can be told to read again while it
/// is running.
///
/// Not for the shipped game. The campaign that ships is written in Dart
/// (`levels.dart`) where the compiler checks it and the tests can name it, and
/// anything from elsewhere arrives over the network. This is the third case:
/// the file you have open in an editor right now.
class FileLevels implements LevelSource {
  const FileLevels(this.path, {this.onSkipped});

  /// A `.json` file, or a folder of them read in filename order.
  ///
  /// A folder because a level per file is how they are actually worked on —
  /// one open in the editor, the rest left alone — and because the order then
  /// comes from the names, which is something you can change without touching
  /// any of the files.
  final String path;

  /// Told about each level left out because it needs a mechanic this build
  /// does not have. See [Level.knownMechanics].
  final void Function(LevelUnsupportedException skipped)? onSkipped;

  @override
  String get label => 'file $path';

  @override
  Future<List<Level>> load() async {
    final levels = <Level>[];
    final from = <String, String>{};

    for (final file in _files()) {
      for (final level in _read(file)) {
        final already = from[level.id];
        if (already != null) {
          throw LevelFormatException(
            'two levels are called "${level.id}": $already and ${file.path}',
          );
        }
        from[level.id] = file.path;
        levels.add(level);
      }
    }
    return levels;
  }

  List<File> _files() {
    if (FileSystemEntity.isDirectorySync(path)) {
      return Directory(path)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    }
    final file = File(path);
    if (file.existsSync()) return [file];
    throw LevelFormatException('$path is not a file or a folder');
  }

  /// Reads one file, which may hold a single level or a list of them.
  ///
  /// Every failure names the file. Half the point of authoring in JSON is that
  /// a mistake is a typo rather than a compile error, and a typo you cannot
  /// locate is worse than either.
  List<Level> _read(File file) {
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (error) {
      throw LevelFormatException(
        '${file.path} is not valid JSON: ${error.message}',
      );
    }
    try {
      return levelsFromJson(decoded, onSkipped: onSkipped);
    } on LevelFormatException catch (error) {
      throw LevelFormatException('${file.path}: ${error.message}');
    }
  }
}
