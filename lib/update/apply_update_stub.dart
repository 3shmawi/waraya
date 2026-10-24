import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'play_update.dart';

import 'update_check.dart';

/// An installed build cannot replace itself: it opens the page the new one
/// comes from — the store's, for a build from a store, or the release's.
Future<void> applyUpdate(Update update) async {
  // On Android, from Play: Play's own update screen over the game. Its page
  // only if that did not happen.
  if (update.route == UpdateRoute.store &&
      defaultTargetPlatform == TargetPlatform.android &&
      await takeFromPlay()) {
    return;
  }
  try {
    await launchUrl(
      update.page ?? UpdateChecker.releasePage,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // Nowhere to open it. The card stays, so the player still knows.
  }
}
