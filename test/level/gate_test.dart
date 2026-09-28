// The gate's row handling. What a level must be is `level_check_test.dart`;
// this is only what the gate adds on top: which row, and what to write back.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/gate.dart';
import 'package:waraya/level/level.dart';
import 'package:waraya/level/levels.dart';

/// A campaign level under a new id, as the gate fetches it: `{id, data}`.
Map<String, Object?> row(Level level, String id, {String? dataId}) {
  final data = jsonDecode(jsonEncode(level.toJson())) as Map<String, Object?>
    ..['id'] = dataId ?? id;
  return {'id': id, 'data': data};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a good level is published, with nothing to say', () async {
    final [decision] = await judgeRows([
      row(Levels.standOnYourself, 'submitted'),
    ]);
    expect(decision.toJson(), {
      'id': 'submitted',
      'status': 'published',
      'verdict': null,
    });
  });

  test('a broken one is rejected with the reason written down', () async {
    final broken = row(Levels.standOnYourself, 'broken');
    ((broken['data']! as Map)['solution']! as List).removeLast();

    final [decision] = await judgeRows([broken]);
    expect(decision.status, 'rejected');
    expect(decision.verdict, contains('solutionFails'));
  });

  test('a row and the level inside it must agree on the id', () async {
    final [decision] = await judgeRows([
      row(Levels.standOnYourself, 'the-row', dataId: 'the-level'),
    ]);
    expect(decision.status, 'rejected');
    expect(decision.verdict, contains('"the-level"'));
  });

  test('an id the campaign already uses is rejected', () async {
    final [decision] = await judgeRows([
      row(Levels.standOnYourself, Levels.goInLow.id),
    ]);
    expect(decision.status, 'rejected');
    expect(decision.verdict, contains('campaign'));
  });

  test('every row gets an answer, whatever the others were', () async {
    final decisions = await judgeRows([
      {'id': 'not-a-level', 'data': 'nonsense'},
      row(Levels.goInLow, 'fine'),
      {'no': 'id'},
    ]);
    expect(
      {for (final d in decisions) d.id: d.status},
      {'not-a-level': 'rejected', 'fine': 'published'},
    );
  });
}
