import 'package:shared_preferences/shared_preferences.dart';

import 'progress.dart';

/// Progress kept where the platform keeps things: `localStorage` in a browser
/// under `flutter.waraya.beaten`, preferences on a phone or a desktop.
///
/// **If this ever starts throwing `MissingPluginException` on the web, the
/// build is stale, not the code.** Adding a plugin does not invalidate an
/// existing web build's plugin registrant, so `flutter build web` keeps
/// shipping a bundle that registers the plugins the app had *before*. It cost
/// an afternoon once. `flutter clean` fixes it; see `docs/building.md`.
///
/// Every method swallows storage failures and carries on against the copy it
/// holds in memory. A private window, a browser with site data blocked, a
/// platform channel that is not there — none of those should stop someone
/// playing, and all of them would if this threw.
class StoredProgress implements Progress {
  StoredProgress._(this._prefs, this._beaten);

  /// Reads what was stored. Never throws: a store it could not open becomes an
  /// empty one, and the session plays fine and forgets afterwards.
  static Future<Progress> open() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StoredProgress._(prefs, {...?prefs.getStringList(_key)});
    } catch (_) {
      return MemoryProgress();
    }
  }

  static const String _key = 'waraya.beaten';

  final SharedPreferences _prefs;
  final Set<String> _beaten;

  @override
  Future<Set<String>> beaten() async => {..._beaten};

  @override
  Future<void> record(String levelId) async {
    if (!_beaten.add(levelId)) return;
    await _save();
  }

  @override
  Future<void> clear() async {
    _beaten.clear();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _prefs.setStringList(_key, _beaten.toList()..sort());
    } catch (_) {
      // Kept in memory for this session either way.
    }
  }
}
