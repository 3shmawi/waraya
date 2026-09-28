/// Saving a level the editor made, and opening one, wherever the editor runs.
///
/// On the web that is a download and a file picker; on a desktop it is a file
/// on the disk. Either way the text is the level's JSON — the same text the
/// bench reads with `WARAYA_LEVELS` and the upload sends.
library;

export 'level_file_stub.dart'
    if (dart.library.js_interop) 'level_file_web.dart'
    if (dart.library.io) 'level_file_io.dart';
