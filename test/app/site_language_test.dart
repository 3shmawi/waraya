import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/settings/game_settings.dart';

/// The landing page, the splash and the game agree on one language, by
/// reading and writing the game's own setting where shared_preferences keeps
/// it on the web: localStorage, "flutter." + the key.
void main() {
  // shared_preferences' prefix on the web, then SettingsKeeper's own.
  const stored = 'flutter.waraya.settings.language';

  test('the setting is still called what the pages read', () {
    expect(const GameSettings().toJson().containsKey('language'), isTrue);
    expect(
      File('lib/settings/game_settings.dart').readAsStringSync(),
      contains("_prefix = 'waraya.settings.'"),
    );
  });

  for (final page in ['site/index.html', 'web/index.html']) {
    test('$page reads the game\'s language', () {
      expect(File(page).readAsStringSync(), contains(stored));
    });
  }

  test('the landing page has a language button, and both languages', () {
    final whole = File('site/index.html').readAsStringSync();
    expect(whole, contains('id="langswitch"'));
    // The text, not the stylesheet's selectors.
    final page = whole.substring(whole.indexOf('</head>'));
    // Elements carrying a language, by tag: every Arabic one has an English
    // twin of the same kind.
    Map<String, int> count(String lang) {
      final tags = <String, int>{};
      for (final m in RegExp('<(\\w+)[^>]*lang="$lang"').allMatches(page)) {
        tags.update(m.group(1)!, (n) => n + 1, ifAbsent: () => 1);
      }
      return tags;
    }

    expect(count('en'), count('ar'));
    expect(count('ar').values.fold<int>(0, (a, b) => a + b), greaterThan(40));
  });
}
