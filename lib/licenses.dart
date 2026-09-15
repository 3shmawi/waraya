import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Declares the bundled fonts' licences to Flutter, so they appear wherever
/// the app lists its open-source licences.
///
/// The SIL Open Font License requires the licence and copyright notice to be
/// distributed with the font. Both licence texts ship as assets and are read
/// here rather than pasted into source, so the two cannot drift apart.
///
/// Every entry point calls this. It used to live in `main.dart` alone, which
/// meant the lab and the levels shipped a font without its licence.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in const {
      'LiberationMono': 'assets/fonts/LiberationMono-LICENSE.txt',
      'Cairo': 'assets/fonts/Cairo-LICENSE.txt',
    }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
}

/// The font the game writes Arabic in.
const String arabicFontFamily = 'Cairo';

/// The font the game writes numbers and debug readouts in.
const String monoFontFamily = 'LiberationMono';

/// Never let a missing family fail silently into empty boxes in a release
/// build: this is the list the asset bundle is expected to carry.
@visibleForTesting
const List<String> bundledFontFamilies = [arabicFontFamily, monoFontFamily];
