import 'package:in_app_update/in_app_update.dart';

/// What Google Play has for this install, asked on the phone itself
/// (Play Core, through `in_app_update`).
///
/// Play has no public lookup like the App Store's, so this is the only way
/// to know it is serving the new build rather than still reviewing it — and
/// it answers only for a copy that Play installed.
class PlayServing {
  const PlayServing({required this.newer, this.versionCode = 0});

  /// Whether Play has a newer build of the game than this one.
  final bool newer;

  /// That build's version code — `release.yml`'s run number, the same
  /// number as `latest.json`'s `buildNumber`. 0 for not known.
  final int versionCode;
}

/// Asks Play, or null when it cannot say: not installed from Play (a
/// downloaded APK), no Play on the phone, or offline.
Future<PlayServing?> askPlay() async {
  try {
    final info = await InAppUpdate.checkForUpdate();
    return switch (info.updateAvailability) {
      UpdateAvailability.updateAvailable => PlayServing(
        newer: true,
        versionCode: info.availableVersionCode ?? 0,
      ),
      UpdateAvailability.updateNotAvailable => const PlayServing(newer: false),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

/// Play's own update screen, over the game. False when it did not happen —
/// refused, cancelled, or not possible — and the store's page is next.
Future<bool> takeFromPlay() async {
  try {
    return await InAppUpdate.performImmediateUpdate() ==
        AppUpdateResult.success;
  } catch (_) {
    return false;
  }
}
