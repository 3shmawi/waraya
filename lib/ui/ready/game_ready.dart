/// Telling the page the game is ready to be seen.
///
/// The web splash (`web/index.html`) used to lift on Flutter's first frame,
/// which is not the game: the level was still loading its scenery and sounds,
/// and for a second or two the player looked at an empty dark-blue sky.
/// Reported from playing. Now the splash waits for this.
library;

export 'game_ready_stub.dart' if (dart.library.js_interop) 'game_ready_web.dart';
