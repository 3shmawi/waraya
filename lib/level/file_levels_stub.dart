import 'level.dart';
import 'level_source.dart';

/// The no-disk stand-in. See `file_levels.dart`.
class FileLevels implements LevelSource {
  const FileLevels(this.path, {this.onSkipped});

  final String path;
  final void Function(LevelUnsupportedException skipped)? onSkipped;

  @override
  String get label => 'file $path';

  @override
  Future<List<Level>> load() async =>
      throw UnsupportedError('there is no filesystem to read $path from');
}
