/// Drives a callback on a fixed interval out of a variable-rate `update(dt)`.
///
/// The shadow buffer only means something in seconds if the ticks it holds are
/// all the same length. Recording once per rendered frame would make the delay
/// drift with the frame rate — 3 seconds on a 120Hz iPad and 6 on a struggling
/// browser tab — so recording is decoupled from rendering here.
class FixedTicker {
  FixedTicker({this.tickRate = defaultTickRate, this.maxTicksPerFrame = 8});

  /// 60Hz. Three seconds of delay is 180 snapshots, which is nothing.
  static const double defaultTickRate = 1 / 60;

  final double tickRate;

  /// Ceiling on catch-up work in a single frame.
  ///
  /// Without it, a tab that was backgrounded for a minute arrives with a
  /// dt of 60s and tries to run 3600 ticks at once, which stalls the frame and
  /// makes the next dt worse — the classic spiral of death. Dropping the
  /// backlog instead means the shadow skips ahead, which is the right failure:
  /// a paused game has no meaningful shadow history anyway.
  ///
  /// At the default 60Hz this only bites on frames longer than 133ms — under
  /// 8fps, where nothing about the game works anyway.
  final int maxTicksPerFrame;

  double _accumulator = 0;

  /// How far into the current tick we are, in [0, 1). This is the blend factor
  /// interpolation would use — Phase 2 does not interpolate yet (see the plan:
  /// look first, only smooth if the stepping actually shows).
  double get alpha => _accumulator / tickRate;

  /// Runs [onTick] once per elapsed [tickRate], returning how many ran.
  int advance(double dt, void Function() onTick) {
    _accumulator += dt;
    var ticks = 0;
    while (_accumulator >= tickRate) {
      _accumulator -= tickRate;
      onTick();
      ticks++;
      if (ticks >= maxTicksPerFrame) {
        _accumulator = 0;
        break;
      }
    }
    return ticks;
  }

  void reset() => _accumulator = 0;
}
