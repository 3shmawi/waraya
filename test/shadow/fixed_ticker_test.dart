import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/shadow/fixed_ticker.dart';

void main() {
  group('FixedTicker', () {
    test('runs one tick per tickRate regardless of frame length', () {
      final ticker = FixedTicker(tickRate: 1 / 60);
      var ticks = 0;

      // Sixty tiny frames and ten fat ones both cover one second, so both
      // must record the same amount of history.
      for (var i = 0; i < 60; i++) {
        ticker.advance(1 / 60, () => ticks++);
      }
      expect(ticks, 60);

      ticks = 0;
      for (var i = 0; i < 10; i++) {
        ticker.advance(0.1, () => ticks++);
      }
      expect(ticks, 60);
    });

    test('carries the remainder into the next frame', () {
      final ticker = FixedTicker(tickRate: 1 / 60);
      var ticks = 0;

      // Half a tick twice is one tick, not zero.
      ticker.advance(1 / 120, () => ticks++);
      expect(ticks, 0);
      ticker.advance(1 / 120, () => ticks++);
      expect(ticks, 1);
    });

    test('does not try to catch up an unbounded backlog', () {
      // A backgrounded tab hands us a dt of minutes. Running every tick it
      // asks for would freeze the frame and make the next dt worse.
      final ticker = FixedTicker(tickRate: 1 / 60, maxTicksPerFrame: 8);
      var ticks = 0;

      ticker.advance(60, () => ticks++);

      expect(ticks, 8);
      // And the backlog is dropped rather than paid off later.
      ticker.advance(1 / 60, () => ticks++);
      expect(ticks, 9);
    });

    test('alpha reports progress through the current tick', () {
      final ticker = FixedTicker(tickRate: 1 / 60);
      ticker.advance(1 / 120, () {});
      expect(ticker.alpha, closeTo(0.5, 1e-9));
    });
  });
}
