import 'dart:collection';
import 'dart:math';

import 'fixed_ticker.dart';
import 'snapshot.dart';

/// The delay line: snapshots go in now and come out `delaySeconds` later.
///
/// A [Queue] rather than a fixed ring buffer, because the delay is a live
/// tunable in Phase 2 and the buffer has to grow and shrink with it. Both ends
/// are O(1), and 6 seconds at 60Hz is 360 small objects — the memory argument
/// for a ring buffer does not apply at this size.
class ShadowRecorder {
  ShadowRecorder({
    this.tickRate = FixedTicker.defaultTickRate,
    double delaySeconds = 3,
  }) {
    // Through the setter, so the floor of one tick applies here too.
    this.delaySeconds = delaySeconds;
  }

  final double tickRate;

  final Queue<PoseSnapshot> _buffer = Queue<PoseSnapshot>();

  double _delaySeconds = 3;

  /// How far behind the player the shadow runs. Live-tunable: raising it makes
  /// the shadow pause while the buffer refills, lowering it fast-forwards the
  /// shadow to catch up. Both are the honest behaviour, not a glitch.
  double get delaySeconds => _delaySeconds;
  set delaySeconds(double value) => _delaySeconds = max(tickRate, value);

  /// The delay in whole ticks — at least one, so the shadow is never the
  /// player.
  int get delayTicks => max(1, (_delaySeconds / tickRate).round());

  PoseSnapshot? _current;

  /// What the shadow should be doing right now, or null while the buffer is
  /// still filling and the shadow does not exist yet.
  PoseSnapshot? get current => _current;

  bool get isPlaying => _current != null;

  /// Snapshots recorded but not yet played — literally the shadow's future.
  /// The debug trail draws this.
  Iterable<PoseSnapshot> get pending => _buffer;

  /// Seconds until the shadow appears, or 0 once it has.
  double get secondsUntilPlaying =>
      max(0, (delayTicks - _buffer.length) * tickRate);

  /// Call once per fixed tick with the player's current pose.
  void record(PoseSnapshot snapshot) {
    _buffer.addLast(snapshot);
    // A `while`, not an `if`: lowering the delay mid-play has to discard
    // several ticks at once, and the newest of them is where the shadow lands.
    while (_buffer.length > delayTicks) {
      _current = _buffer.removeFirst();
    }
  }

  /// Wipes the history. Used on scene reload — a shadow that outlived the
  /// reset would replay a life the player no longer had.
  void clear() {
    _buffer.clear();
    _current = null;
  }
}
