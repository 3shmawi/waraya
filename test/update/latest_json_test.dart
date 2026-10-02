import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two workflows write latest.json with one script, so the web and the
/// releases can never describe themselves differently.
void main() {
  test('both workflows write latest.json with tool/latest_json.sh', () {
    for (final workflow in ['pages', 'release']) {
      expect(
        File('.github/workflows/$workflow.yml').readAsStringSync(),
        contains('tool/latest_json.sh'),
        reason: workflow,
      );
    }
  });

  test('and both check out the history the automatic notes are made from', () {
    for (final workflow in ['pages', 'release']) {
      expect(
        File('.github/workflows/$workflow.yml').readAsStringSync(),
        contains('fetch-depth: 0'),
        reason: workflow,
      );
    }
  });

  test('every installed build is stamped with its build number', () {
    final release = File('.github/workflows/release.yml').readAsStringSync();
    for (final target in ['apk', 'appbundle', 'linux', 'windows', 'macos']) {
      final line = release
          .split('\n')
          .firstWhere((l) => l.contains('flutter build $target'));
      expect(line, contains('WARAYA_BUILD_NUMBER'), reason: target);
    }
  });
}
