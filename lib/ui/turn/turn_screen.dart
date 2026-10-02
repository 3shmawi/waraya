/// Asking the screen to turn itself sideways, where the platform can.
///
/// Only a browser can be asked, and only from a tap: it goes full screen and
/// then locks the orientation, which Android's Chrome allows and iOS Safari
/// does not. Everywhere else this answers false and changes nothing — a
/// phone build is already locked sideways by its manifest.
library;

export 'turn_screen_stub.dart'
    if (dart.library.js_interop) 'turn_screen_web.dart';
