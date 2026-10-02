import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/lang.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/levels.dart';

/// A level's English (`docs/phase-11-feel.md` §4.3): words, not play.
void main() {
  test('every level in the campaign has its name and line in English', () {
    for (final level in Levels.campaign) {
      expect(level.nameEn, isNotNull, reason: level.id);
      expect(level.teachesEn, isNotNull, reason: level.id);
      expect(level.speaks(Lang.en), isTrue);
    }
  });

  test('the lines are short enough to read in one look', () {
    // The first review was "I did not understand the line". A line that
    // wraps on a phone is a paragraph, and nobody reads a paragraph over a
    // level they are trying to play.
    for (final level in Levels.campaign) {
      expect(level.teaches.length, lessThanOrEqualTo(60), reason: level.id);
      expect(level.teachesEn!.length, lessThanOrEqualTo(80), reason: level.id);
    }
  });

  test('a level with no English shows its Arabic to everyone', () {
    final json = Levels.pressItEarly.toJson()
      ..remove('nameEn')
      ..remove('teachesEn');
    final level = levelFromJson(jsonDecode(jsonEncode(json)));
    expect(level.nameIn(Lang.en), level.name);
    expect(level.teachesIn(Lang.en), level.teaches);
    expect(level.speaks(Lang.en), isFalse);
    // And reads back without inventing any.
    expect(level.toJson().containsKey('nameEn'), isFalse);
  });

  test('English is never a mechanic', () {
    // An older build that drops it shows the Arabic over the same level,
    // which plays the same — so no level is refused for having it.
    final withIt = Levels.pressItEarly;
    final json = withIt.toJson()
      ..remove('nameEn')
      ..remove('teachesEn');
    expect(levelFromJson(json).requires, withIt.requires);
  });
}
