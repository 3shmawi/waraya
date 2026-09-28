import 'level_check.dart';
import 'levels.dart';

/// What the gate decided about one row of the `levels` table.
class GateDecision {
  const GateDecision({
    required this.id,
    required this.status,
    this.verdict,
  });

  /// The row's primary key, which is what gets updated.
  final String id;

  /// `published` or `rejected`.
  final String status;

  /// Why not, for the author to read. Null when published.
  final String? verdict;

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status,
    'verdict': verdict,
  };
}

/// Judges rows as the `levels` table holds them — `{"id": …, "data": {…}}` —
/// and says what each one's status should become.
///
/// All the judging is [checkLevelJson], the same function the client runs on
/// every level it is sent; this adds only what is about the *row* rather than
/// the level inside it:
///
/// - the row's id and the level's own id must be the same, or the table and
///   the game disagree about which level this is;
/// - the id must not be one the campaign already uses. The client would
///   ignore it anyway (`LevelsThenExtras`), so publishing it would publish a
///   level nobody can ever reach.
///
/// It needs no network and no key. The workflow fetches the rows, runs this
/// with no secret in its environment, and only then writes the answers back —
/// the step that replays strangers' levels is the step that holds nothing
/// worth stealing.
Future<List<GateDecision>> judgeRows(List<Object?> rows) async {
  final builtIn = {for (final level in Levels.campaign) level.id};
  final decisions = <GateDecision>[];
  for (final row in rows) {
    if (row is! Map || row['id'] is! String) continue;
    final id = row['id'] as String;
    final data = row['data'];

    final problems = <String>[];
    final levelId = data is Map ? data['id'] : null;
    if (levelId != id) {
      problems.add('the row is "$id" but the level inside says "$levelId"');
    }
    if (builtIn.contains(id)) {
      problems.add('"$id" is a level in the campaign already');
    }
    final verdict = await checkLevelJson(data);
    problems.addAll(verdict.findings.map((finding) => '$finding'));

    decisions.add(
      GateDecision(
        id: id,
        status: problems.isEmpty ? 'published' : 'rejected',
        verdict: problems.isEmpty ? null : problems.join('\n'),
      ),
    );
  }
  return decisions;
}
