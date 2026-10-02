import 'dart:convert';

import 'package:flutter/services.dart';

import 'level.dart';
import 'level_source.dart';

/// The `levels/` folder, as it was when the app was built.
///
/// For the bench on the web, which has no disk: [FileLevels] cannot read a
/// folder there, so the published bench (`/lab/` on the site) would open on
/// the tuning level alone — and that one has nothing recorded, so the gate
/// refuses it and there would be nothing to send. This is the same folder,
/// frozen into the build.
///
/// Chosen with `--dart-define=WARAYA_LEVELS=bundled`. Nothing ships it to
/// players: the game reads the campaign in Dart and the server, never this.
class BundledLevels implements LevelSource {
  const BundledLevels({this.bundle, this.onSkipped, this.accepts});

  /// Where to read from. The app's own bundle unless a test hands in another.
  final AssetBundle? bundle;

  final void Function(LevelUnsupportedException skipped)? onSkipped;

  /// The mechanics to play, or null for [Level.knownMechanics]. The bench
  /// passes [Level.benchMechanics], so a level on trial opens there and
  /// nowhere else (`docs/lab.md` §1).
  final Set<String>? accepts;

  @override
  String get label => 'bundled levels/';

  @override
  Future<List<Level>> load() async {
    final assets = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    final files =
        manifest
            .listAssets()
            .where((key) => key.startsWith('levels/') && key.endsWith('.json'))
            .toList()
          ..sort();
    return [
      for (final file in files)
        ...levelsFromJson(
          jsonDecode(await assets.loadString(file)),
          onSkipped: onSkipped,
          accepts: accepts,
        ),
    ];
  }
}
