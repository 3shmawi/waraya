import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/licenses.dart';

/// The bundled fonts are under the SIL Open Font License, which requires the
/// licence and copyright notice to travel with the font. Nothing about that is
/// enforced by the compiler: delete the licence asset and the game still
/// builds, still runs, and is quietly in breach.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();

  test('every declared font family ships a font file that exists', () {
    for (final family in bundledFontFamilies) {
      expect(
        pubspec,
        contains('family: $family'),
        reason: '$family is used in code but not declared in pubspec.yaml',
      );
    }

    final assets = RegExp(
      r'- asset: (assets/fonts/\S+)',
    ).allMatches(pubspec).map((m) => m.group(1)!);
    expect(assets, isNotEmpty);
    for (final asset in assets) {
      expect(
        File(asset).existsSync(),
        isTrue,
        reason: '$asset is declared but not in the repository',
      );
    }
  });

  test('every font ships its licence, as the OFL requires', () {
    for (final family in bundledFontFamilies) {
      final licence = File('assets/fonts/$family-LICENSE.txt');
      expect(
        licence.existsSync(),
        isTrue,
        reason: 'no licence file for $family',
      );
      expect(
        licence.readAsStringSync(),
        contains('SIL Open Font License'),
        reason: '${licence.path} does not look like the OFL',
      );
      expect(
        pubspec,
        contains(licence.path),
        reason:
            '${licence.path} exists but is not bundled as an asset, so it '
            'will not ship with the app',
      );
    }
  });
}
