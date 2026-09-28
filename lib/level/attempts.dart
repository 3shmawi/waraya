import 'dart:math';

import 'level.dart';

/// One go at one level, as it stood when it was sent.
///
/// The question this exists to answer is the one a solo project cannot
/// answer by watching: **which level is unfair?** A level people restart
/// twelve times to finish, one that four in ten leave unfinished, the one
/// spot everybody dies in — each is a number here and a guess anywhere else.
class Attempt {
  const Attempt({
    required this.attemptId,
    required this.levelId,
    required this.delays,
    required this.outcome,
    required this.seconds,
    required this.reloads,
    required this.deaths,
  });

  /// The same for every row one go sends. A go can be sent more than once —
  /// when the app is put away and again when the level is finished — and the
  /// last row per id is the go.
  final String attemptId;
  final String levelId;
  final List<double> delays;

  /// `finished`, `left` (another level was picked), or `hidden` (the app was
  /// put away mid-level, and may yet come back to it).
  final String outcome;

  /// Game time, not wall time: a paused game, an open menu and a phone in a
  /// pocket are not the level being hard.
  final double seconds;

  final int reloads;

  /// Where the body was each time the level was put back — a death, a fall,
  /// or the retry button — rounded to whole world units.
  final List<(int, int)> deaths;

  Map<String, Object?> toJson() => {
    'attempt_id': attemptId,
    'level_id': levelId,
    'delays': delays,
    'outcome': outcome,
    'seconds': double.parse(seconds.toStringAsFixed(2)),
    'reloads': reloads,
    'deaths': [
      for (final (x, y) in deaths) [x, y],
    ],
  };
}

/// Where attempts go. Told, never asked: nothing in the game waits on it.
abstract interface class AttemptSink {
  void record(Attempt attempt);
}

/// Follows the level being played and reports each go at it.
///
/// The game tells it four things — a level went up, time passed, the level
/// was put back, the level was finished — and the entry point tells it a
/// fifth, that the app was put away. It never touches the game, and a game
/// without one plays exactly the same.
class AttemptLog {
  AttemptLog(this.sink, {Random? random}) : _random = random ?? Random.secure();

  final AttemptSink sink;
  final Random _random;

  /// Past this, deaths stop being written down. A number that large already
  /// says everything the list would.
  static const int mostDeaths = 200;

  Level? _level;
  String _id = '';
  double _seconds = 0;
  final List<(int, int)> _deaths = [];
  int _reloads = 0;
  bool _open = false;

  /// A level went up. Whatever was being played and not finished was left.
  void started(Level level) {
    if (_open) _send('left');
    _level = level;
    _id = uuid4(_random);
    _seconds = 0;
    _reloads = 0;
    _deaths.clear();
    _open = true;
  }

  void tick(double dt) {
    if (_open) _seconds += dt;
  }

  void reloaded(double x, double y) {
    if (!_open) return;
    _reloads++;
    if (_deaths.length < mostDeaths) _deaths.add((x.round(), y.round()));
  }

  void finished() {
    if (!_open) return;
    _send('finished');
    _open = false;
  }

  /// The app went into the background. Sent now because it may never come
  /// back; the go stays open in case it does.
  void hidden() {
    if (_open) _send('hidden');
  }

  void _send(String outcome) {
    final level = _level!;
    sink.record(
      Attempt(
        attemptId: _id,
        levelId: level.id,
        delays: level.delays,
        outcome: outcome,
        seconds: _seconds,
        reloads: _reloads,
        deaths: List.of(_deaths),
      ),
    );
  }
}

/// A random (version 4) UUID, without a package for eight lines.
String uuid4(Random random) {
  final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')]
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
