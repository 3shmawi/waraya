import 'package:url_launcher/url_launcher.dart';

import 'update_check.dart';

/// An installed build cannot replace itself: it opens the page the new one
/// comes from — the store's, for a build from a store, or the release's.
Future<void> applyUpdate(Update update) async {
  try {
    await launchUrl(
      update.page ?? UpdateChecker.releasePage,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // Nowhere to open it. The card stays, so the player still knows.
  }
}
