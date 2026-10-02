import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Full screen, then landscape. True if the browser agreed to both.
///
/// Must be called from a tap: both requests are refused without one. Each
/// failure is swallowed — a browser that will not turn is answered by the
/// "play upright" button next to this one, not by an error.
Future<bool> turnScreenSideways() async {
  try {
    if (web.document.fullscreenElement == null) {
      await web.document.documentElement?.requestFullscreen().toDart;
    }
    await web.window.screen.orientation.lock('landscape').toDart;
    return true;
  } catch (_) {
    return false;
  }
}

/// Whether the browser has the call at all. Safari on an iPhone does not
/// lock, and offering a button that never works is worse than not offering it.
bool get canTurnScreen {
  try {
    return web.window.screen.orientation.isDefinedAndNotNull &&
        web.document.documentElement != null;
  } catch (_) {
    return false;
  }
}
