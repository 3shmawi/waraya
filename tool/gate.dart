// The gate: decides which submitted levels get published.
//
// Run: GATE_IN=rows.json GATE_OUT=decisions.json flutter test tool/gate.dart
//
// A test rather than a program because the level check boots the real game —
// `LevelGame`, through `Playthrough` — and that needs the Flutter binding a
// test provides. One copy of the physics decides; see docs/phase-8-server.md.
//
// It reads rows as `.github/workflows/gate.yml` fetched them from the
// `levels` table and writes one decision per row. It touches no network and
// holds no key: fetching and writing back are separate steps of the workflow,
// and only those two see the secret.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/level/gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('judge the submitted levels', () async {
    final input = Platform.environment['GATE_IN'] ?? 'rows.json';
    final output = Platform.environment['GATE_OUT'] ?? 'decisions.json';

    final rows = jsonDecode(File(input).readAsStringSync()) as List<Object?>;
    final decisions = await judgeRows(rows);

    File(output).writeAsStringSync(
      jsonEncode([for (final decision in decisions) decision.toJson()]),
    );
    for (final decision in decisions) {
      // ignore: avoid_print
      print(
        '${decision.id}: ${decision.status}'
        '${decision.verdict == null ? '' : '\n  ${decision.verdict!.replaceAll('\n', '\n  ')}'}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
