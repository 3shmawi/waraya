/// Nowhere to save to. See `level_file.dart`.
Future<String> saveLevelFile(
  String fileName,
  String json, {
  String? folder,
}) async => throw UnsupportedError('no files here — it is on the clipboard');

/// Nothing to open from.
Future<String?> pickLevelFile() async => null;

/// Whether [pickLevelFile] can do anything here.
const bool canPickLevelFile = false;
