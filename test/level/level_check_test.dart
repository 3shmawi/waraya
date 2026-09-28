// The gate, before there is anything for it to guard.
//
// `checkLevel` is what decides whether a level somebody else wrote may be
// played. It has to say yes to every level in the campaign — they are the
// levels that have been played by hand and solved — and it has to say no to
// broken copies of them **for the right reason**. A gate that refuses a level
// with a broken solution because of its door height is a gate that happens to
// be right, and it will publish the next one.
//
// The broken copies go through JSON on purpose: that is what a submission is,
// and `checkLevelJson` is the entry point the gate will call.
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/level_check.dart';
import 'package:waraya/level/levels.dart';
import 'package:waraya/level/playthrough.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the campaign passes its own gate', () {
    for (final level in Levels.campaign) {
      test(level.id, () async {
        final verdict = await checkLevel(
          level,
          cheapIsTheLesson: Levels.cheapByDesign.contains(level.id),
        );
        expect(verdict.accepted, isTrue, reason: '$verdict');
      });
    }

    test('and the bench does not — it has nothing to replay', () async {
      final verdict = await checkLevel(Levels.lab);
      expect(verdict.refusals, {Refusal.cannotBeChecked});
    });
  });

  /// A level as a submission would carry it: decoded JSON, freshly copied so
  /// each test can break its own.
  Map<String, Object?> asSubmitted(Level level) =>
      jsonDecode(jsonEncode(level.toJson())) as Map<String, Object?>;

  /// A run as the JSON carries it, through the real encoder.
  List<Object?> movesOf(List<Move> moves) =>
      asSubmitted(
            Level(
              id: 'carrier',
              name: 'carrier',
              teaches: 'carrier',
              delaySeconds: 1,
              spawnX: 0,
              goal: const Rect.fromLTRB(0, 0, 1, 1),
              solution: moves,
            ),
          )['solution']!
          as List<Object?>;

  Future<Set<Refusal>> refusalsFor(Map<String, Object?> json) async {
    final verdict = await checkLevelJson(json);
    expect(verdict.accepted, isFalse, reason: 'expected a refusal');
    return verdict.refusals;
  }

  group('a submission', () {
    test('exactly as the campaign has it is accepted', () async {
      // Two shadows, so it also carries a `requires` that has to survive.
      final verdict = await checkLevelJson(asSubmitted(Levels.twoNotOne));
      expect(verdict.accepted, isTrue, reason: '$verdict');
      expect(verdict.levelId, Levels.twoNotOne.id);
    });

    test('with no solution cannot be checked', () async {
      final json = asSubmitted(Levels.standOnYourself)..['solution'] = [];
      expect(await refusalsFor(json), {Refusal.cannotBeChecked});
    });

    test('with no wrong idea cannot be checked', () async {
      final json = asSubmitted(Levels.standOnYourself)..['wrongIdeas'] = [];
      expect(await refusalsFor(json), {Refusal.cannotBeChecked});
    });

    test('whose solution stops short is refused for it', () async {
      final level = Levels.standOnYourself;
      final json = asSubmitted(level)
        ..['solution'] = movesOf(
          level.solution.take(level.solution.length - 1).toList(),
        );
      expect(await refusalsFor(json), {Refusal.solutionFails});
    });

    test('whose wrong idea is its solution is refused for it', () async {
      final level = Levels.standOnYourself;
      final json = asSubmitted(level)
        ..['wrongIdeas'] = [
          ...(asSubmitted(level)['wrongIdeas']! as List),
          movesOf(level.solution),
        ];
      final verdict = await checkLevelJson(json);
      expect(verdict.refusals, {Refusal.wrongIdeaFinishes});
      expect(
        verdict.findings.single.detail,
        contains('wrong idea ${level.wrongIdeas.length + 1}'),
        reason: 'the author needs to know which one',
      );
    });

    // The campaign keeps three levels that a terse run finishes, by design.
    // A level from outside has no such list to be on.
    test('that a cheap run finishes is refused for it', () async {
      final verdict = await checkLevel(Levels.pressItEarly);
      expect(verdict.refusals, {Refusal.cheapRunFinishes});
      expect(verdict.findings.single.detail, contains('touch what is behind you'));
    });

    test('that needs a mechanic this build lacks is refused by name', () async {
      final json = asSubmitted(Levels.standOnYourself)
        ..['requires'] = ['crouched-solid', 'pushable-box'];
      final verdict = await checkLevelJson(json);
      expect(verdict.refusals, {Refusal.unsupported});
      expect(verdict.findings.single.detail, contains('pushable-box'));
    });

    // The reverse of the one above, and the one only a gate can catch: this
    // build reads the lights and plays the level right. An older build reads
    // `requires`, sees nothing it lacks, drops the lights in silence, and puts
    // up a different puzzle.
    test('that uses a mechanic without naming it is refused', () async {
      final json = asSubmitted(Levels.yourShadowIsNotHere)
        ..['requires'] = ['crouched-solid'];
      final verdict = await checkLevelJson(json);
      expect(verdict.refusals, {Refusal.understatesRequires});
      expect(verdict.findings.single.detail, contains('lights'));
    });

    test('with a door low enough to climb is refused', () async {
      final json = asSubmitted(Levels.pressItEarly);
      final door = (json['doors']! as List).first as Map;
      final closed = door['closed']! as List;
      closed[1] = (closed[3] as num) - 200;
      expect(await refusalsFor(json), {Refusal.outOfBounds});
    });

    test('with a run too long to replay is refused before it runs', () async {
      final json = asSubmitted(Levels.standOnYourself)
        ..['solution'] = movesOf(const [Move.right(3600)]);
      final watch = Stopwatch()..start();
      expect(await refusalsFor(json), {Refusal.outOfBounds});
      // An hour of game time would take minutes to replay. Refused on the
      // number, it takes nothing.
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test('with a plate for a door that is not there is refused', () async {
      final json = asSubmitted(Levels.pressItEarly);
      ((json['plates']! as List).first as Map)['opens'] = 'nowhere';
      expect(await refusalsFor(json), {Refusal.outOfBounds});
    });

    test('with three shadows is refused', () async {
      final json = asSubmitted(Levels.twoNotOne)..['delays'] = [2, 6, 10];
      expect(await refusalsFor(json), contains(Refusal.outOfBounds));
    });

    test('that is not a level at all is refused, not thrown', () async {
      final verdict = await checkLevelJson({'id': 'half', 'name': 'half'});
      expect(verdict.refusals, {Refusal.malformed});
      expect(verdict.levelId, 'half');
      expect((await checkLevelJson('nonsense')).refusals, {Refusal.malformed});
    });
  });
}
