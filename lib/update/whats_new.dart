import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../version.dart';
import 'update_check.dart';

/// "What's new in this version", once, after an update.
///
/// The words are the stores' own (`fastlane/release_notes/`), bundled with
/// the game, so the note in the game and the note on Google Play are one
/// text written once. Shown to somebody who had played an earlier version:
/// a first-time player has nothing to compare against, and a list of changes
/// to a game they have not seen yet is noise.
class WhatsNew {
  WhatsNew._();

  static const String _key = 'waraya.seenVersion';

  /// The notes to show now, or null — and remembers that they were shown.
  ///
  /// [playedBefore] covers everyone who played before this existed: they
  /// have no version written down, but they have levels finished.
  static Future<Published?> takeOnce({
    required bool playedBefore,
    AssetBundle? bundle,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getString(_key);
      if (seen == appVersion) return null;
      await prefs.setString(_key, appVersion);
      if (seen == null && !playedBefore) return null;
      // Only forward: someone going back to an older build is not told what
      // is "new" in it.
      if (seen != null && compareVersions(appVersion, seen) <= 0) return null;
      return bundled(bundle: bundle);
    } catch (_) {
      return null;
    }
  }

  /// This version's notes, as shipped.
  static Future<Published?> bundled({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    try {
      final published = Published(
        version: appVersion,
        notesAr: (await assets.loadString(
          'fastlane/release_notes/ar.txt',
        )).trim(),
        notesEn: (await assets.loadString(
          'fastlane/release_notes/en.txt',
        )).trim(),
      );
      return published.notesAr.isEmpty ? null : published;
    } catch (_) {
      return null;
    }
  }
}
