import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'fresh_files.dart';
import 'update_check.dart';

/// The new game is already on the server; loading the page again is the
/// update — once the files the page runs on have been fetched again past
/// the browser's cache, or the reload runs the old game ([filesToRefresh]).
Future<void> applyUpdate(Update update) async {
  await _refetch();
  web.window.location.reload();
}

/// How long to wait for the files before reloading anyway. A slow phone
/// gets the old game for a few more minutes; it does not get stuck.
const Duration _patience = Duration(seconds: 25);

Future<void> _refetch() async {
  try {
    final loaded = web.window.performance
        .getEntriesByType('resource')
        .toDart
        .map((entry) => entry.name);
    final files = filesToRefresh(loaded, origin: web.window.location.origin);
    await Future.wait([
      for (final url in files) _fetchPastCache(url),
    ]).timeout(_patience);
  } catch (_) {
    // Whatever did not come, the reload asks for in the ordinary way.
  }
}

/// Asks the server for [url] whatever the browser has kept, and reads it to
/// the end — a response is only stored once its body has arrived.
Future<void> _fetchPastCache(String url) async {
  try {
    final response = await web.window
        .fetch(url.toJS, web.RequestInit(cache: 'reload'))
        .toDart;
    await response.arrayBuffer().toDart;
  } catch (_) {
    // One file missing is no reason to hold the others up.
  }
}
