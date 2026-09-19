import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_source.dart';
import 'package:waraya/level/levels.dart';

/// A level saying what it needs, and being refused when this build has not
/// got it.
///
/// The danger is not uploading a level — it is a level reaching a copy of the
/// game older than the mechanic it uses. The old parser's instinct with a
/// field it has never heard of is to **ignore it in silence**, which puts up a
/// level that is either unsolvable or solvable without touching the thing the
/// puzzle is about, and says nothing either way. Refusing the level is the
/// only honest answer, and the cost of adding this is only low *before* the
/// first level is published.
void main() {
  Map<String, Object?> jsonOf(Level level, {List<String>? requires}) {
    final json = level.toJson();
    if (requires != null) json['requires'] = requires;
    return json;
  }

  final sample = Levels.campaign.first;

  test('a level written today needs nothing beyond the baseline', () {
    for (final level in Levels.campaign) {
      expect(level.requires, isEmpty);
      expect(level.toJson()['requires'], isEmpty);
    }
  });

  test('a level is refused by name when it asks for what is not here', () {
    expect(
      () => levelFromJson(jsonOf(sample, requires: ['toggles'])),
      throwsA(
        isA<LevelUnsupportedException>()
            .having((e) => e.levelId, 'levelId', sample.id)
            .having((e) => e.missing, 'missing', {'toggles'}),
      ),
    );
  });

  test('and is not refused for something this build does have', () {
    // Nothing is past the baseline yet, so the empty declaration is the whole
    // of what can be honestly asked for. When a mechanic lands, its name joins
    // `knownMechanics` in the same commit — never before it works.
    expect(Level.knownMechanics, isEmpty);
    expect(levelFromJson(jsonOf(sample, requires: const [])).id, sample.id);
  });

  test('one level ahead of this build does not take the batch with it', () {
    final ahead = jsonOf(
      Levels.campaign[1],
      requires: ['lights'],
    )..['id'] = 'from-the-future';

    final skipped = <LevelUnsupportedException>[];
    final levels = levelsFromJson([
      jsonOf(sample),
      ahead,
      jsonOf(Levels.campaign[2]),
    ], onSkipped: skipped.add);

    expect(
      levels.map((l) => l.id),
      [sample.id, Levels.campaign[2].id],
      reason: 'the two this build can play are still there',
    );
    expect(skipped.single.levelId, 'from-the-future');
  });

  test('the server can only ever add, and never a level that will not run',
      () async {
    final source = LevelsThenExtras(
      const BuiltInLevels(),
      JsonLevels(
        jsonEncode([
          jsonOf(sample)..['id'] = 'needs-what-is-not-here',
          // ...and the same id as a built-in, which is refused for a different
          // reason: a bad upload must not replace a level known to be solvable.
        ].map((json) => json..['requires'] = ['crates']).toList()),
      ),
    );

    expect((await source.load()).map((l) => l.id), Levels.campaign.map((l) => l.id));
  });

  test('a malformed level is still an error, not a skip', () {
    expect(
      () => levelsFromJson([
        {'id': 'broken', 'name': 'broken'},
      ]),
      throwsA(isA<LevelFormatException>()),
    );
  });

  test('one level on its own reads as well as a list of them', () {
    expect(levelsFromJson(jsonOf(sample)).single.id, sample.id);
  });
}
