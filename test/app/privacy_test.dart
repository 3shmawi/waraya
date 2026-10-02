import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/attempts.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/ui/words.dart';

/// `site/privacy.html` names every field the game sends, by the key it is
/// sent under, in both languages.
///
/// A store asks for this page, and the page is only worth anything while it
/// is true. The day someone adds a field to [Attempt.toJson] — which is the
/// easy change, one line — this is what says the page has to move with it.
void main() {
  final page = File('site/privacy.html').readAsStringSync();
  final english = page.substring(page.indexOf('class="en"'));
  final arabic = page.substring(0, page.indexOf('class="en"'));

  final sent = {
    ...const Attempt(
      attemptId: 'a',
      levelId: 'l',
      delays: [1],
      outcome: 'finished',
      seconds: 1,
      reloads: 0,
      deaths: [],
    ).toJson().keys,
    // Added by SupabaseAttempts.record, next to the attempt's own fields.
    'device_id',
  };

  for (final key in sent) {
    test('the privacy page names `$key`', () {
      expect(arabic, contains('<code>$key</code>'), reason: 'Arabic half');
      expect(english, contains('<code>$key</code>'), reason: 'English half');
    });
  }

  // The store forms call the statistics optional, and the page says where
  // to turn them off. Named by the words on the switch itself, so renaming
  // the switch without the page is a failure rather than a dead direction.
  test('the page says where statistics are turned off', () {
    expect(arabic, contains(const Words(Lang.ar).stats));
    expect(english, contains(const Words(Lang.en).stats));
  });

  test('the landing page links to it', () {
    expect(
      File('site/index.html').readAsStringSync(),
      contains('href="privacy.html"'),
    );
  });
}
