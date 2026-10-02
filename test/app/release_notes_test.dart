import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "What's new" and "what to test" go to the stores from files in fastlane/,
/// and each store has a limit that it only enforces at upload time — at the
/// end of a release run, after every build. So the limits are checked here,
/// where an edit that breaks one fails in a minute.
void main() {
  // Play's limit is the tighter of the two stores': 500 per language. The
  // App Store allows 4000.
  for (final language in const ['ar', 'en']) {
    test('release_notes/$language.txt is there and fits Play', () {
      final file = File('fastlane/release_notes/$language.txt');
      expect(file.existsSync(), isTrue);
      final text = file.readAsStringSync().trim();
      expect(text, isNotEmpty);
      expect(text.length, lessThanOrEqualTo(500));
    });
  }

  test('what_to_test.txt fits TestFlight', () {
    final text = File('fastlane/what_to_test.txt').readAsStringSync().trim();
    expect(text, isNotEmpty);
    expect(text.length, lessThanOrEqualTo(4000));
  });
}
