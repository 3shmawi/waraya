import 'package:url_launcher/url_launcher.dart';

import 'update_check.dart';

/// An installed build cannot replace itself: it opens the page the new one
/// is downloaded from, in the browser.
Future<void> applyUpdate(Update update) async {
  try {
    await launchUrl(
      UpdateChecker.releasePage,
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // Nowhere to open it. The card stays, so the player still knows.
  }
}
