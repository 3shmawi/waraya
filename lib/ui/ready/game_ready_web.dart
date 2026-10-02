import 'package:web/web.dart' as web;

/// Fires `waraya-ready` on the window, which the splash is listening for.
void announceGameReady() {
  try {
    web.window.dispatchEvent(web.Event('waraya-ready'));
  } catch (_) {
    // The splash has its own timeout; a failure here only means it waits.
  }
}
