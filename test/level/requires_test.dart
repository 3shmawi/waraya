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

  test('a level declares exactly what it holds, and nothing else', () {
    for (final level in Levels.campaign) {
      // Rectangles, plates, doors, one delay: the baseline, and none of it is
      // named. The seven levels written before this vocabulary existed still
      // declare nothing, which is what keeps them readable by any build.
      final expected = <String>{
        if (level.toggles.isNotEmpty) 'toggles',
        if (level.plates.any((plate) => plate.inverts)) 'inverted-plates',
      };
      expect(level.requires, expected, reason: level.id);
      expect(level.toJson()['requires'], expected.toList()..sort());
      expect(
        level.requires.difference(Level.knownMechanics),
        isEmpty,
        reason: '${level.id} asks this build for something it has not got',
      );
    }
    expect(
      Levels.campaign.where((l) => l.requires.contains('toggles')).map(
        (l) => l.id,
      ),
      ['close-what-you-opened'],
      reason: 'the level the key was added for is the one that declares it',
    );
  });

  test('a level is refused by name when it asks for what is not here', () {
    // `lights` is the next mechanic in the plan and is not built. A name from
    // the plan rather than a nonsense one on purpose: this is exactly the
    // shape of the accident — a level authored against a newer build.
    expect(
      () => levelFromJson(jsonOf(sample, requires: ['lights'])),
      throwsA(
        isA<LevelUnsupportedException>()
            .having((e) => e.levelId, 'levelId', sample.id)
            .having((e) => e.missing, 'missing', {'lights'}),
      ),
    );
  });

  test('and is not refused for something this build does have', () {
    // A name joins `knownMechanics` in the same commit as the code that plays
    // it, never before: a name here without the code behind it means a level
    // is accepted and then played wrong, which is the whole failure this
    // guards against.
    expect(Level.knownMechanics, {'toggles', 'inverted-plates'});
    expect(levelFromJson(jsonOf(sample, requires: const [])).id, sample.id);
    expect(
      levelFromJson(jsonOf(Levels.closeWhatYouOpened)).toggles,
      hasLength(1),
      reason: 'the level that needs the key reads back with the key on it',
    );
  });

  test('a build without the key would have refused the level, not thinned it',
      () {
    // What this is all for, spelled out. Strip `toggles` from the set — which
    // is what an older build *is* — and the level that is entirely about a key
    // no longer parses at all. The alternative, and the reason any of this
    // exists, is the same JSON quietly becoming a level with a door nothing
    // can open and no word said anywhere.
    final json = jsonOf(Levels.closeWhatYouOpened);
    expect(json['requires'], contains('toggles'));
    expect(json['toggles'], hasLength(1));

    final older = {...json, 'requires': ['toggles', 'something-else']};
    expect(
      () => levelFromJson(older),
      throwsA(
        isA<LevelUnsupportedException>().having(
          (e) => e.missing,
          'missing',
          {'something-else'},
        ),
      ),
    );
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
