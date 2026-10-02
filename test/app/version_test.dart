import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/version.dart';

void main() {
  test('the game knows its own version: the one in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((line) => line.startsWith('version:'));
    final version = RegExp(r'version:\s*(\d+\.\d+\.\d+)').firstMatch(line)!;
    expect(appVersion, version.group(1));
  });

  test('the bump workflow moves lib/version.dart with the pubspec', () {
    // A bump that forgot this file would ship a game that thinks it is the
    // old version, and offers itself as an update forever.
    expect(
      File('.github/workflows/bump.yml').readAsStringSync(),
      contains('lib/version.dart'),
    );
  });
}
