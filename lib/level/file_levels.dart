/// [FileLevels], where the platform has files.
///
/// A conditional export rather than a plain `dart:io` import, so that adding
/// this to a file the web build reaches cannot break the web build. The stub's
/// `load` throws instead, which is the correct answer on a platform with no
/// disk to read.
library;

export 'file_levels_stub.dart'
    if (dart.library.io) 'file_levels_io.dart';
