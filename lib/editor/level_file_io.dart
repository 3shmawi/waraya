import 'dart:io';

/// Writes [json] to [fileName] in [folder] — the folder the bench was
/// pointed at, so the folder button reads it straight back — or in the
/// working directory when it was not pointed at one.
Future<String> saveLevelFile(
  String fileName,
  String json, {
  String? folder,
}) async {
  // Pointed at one file rather than a folder: next to it.
  final dir = folder == null
      ? Directory.current.path
      : Directory(folder).existsSync()
      ? folder
      : File(folder).existsSync()
      ? File(folder).parent.path
      : Directory.current.path;
  final file = File('$dir${Platform.pathSeparator}$fileName');
  await file.writeAsString('$json\n');
  return 'saved ${file.path}';
}

/// A desktop build opens levels through `WARAYA_LEVELS` and the folder
/// button, which it already has.
Future<String?> pickLevelFile() async => null;

const bool canPickLevelFile = false;
