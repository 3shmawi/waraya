import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:waraya/game/screen_shake.dart';

void main() {
  group('ScreenShake', () {
    test('is still until something hits it', () {
      final shake = ScreenShake(random: Random(1));
      shake.advance(1 / 60);
      expect(shake.offset, Vector2.zero());
      expect(shake.isShaking, isFalse);
    });

    test('displaces by no more than the strength it was hit with', () {
      final shake = ScreenShake(random: Random(2))..hit(6);
      for (var i = 0; i < 5; i++) {
        shake.advance(1 / 60);
        expect(shake.offset.x.abs(), lessThanOrEqualTo(6));
        expect(shake.offset.y.abs(), lessThanOrEqualTo(6));
      }
    });

    test('dies away on its own', () {
      final shake = ScreenShake(random: Random(3))..hit(6);
      for (var i = 0; i < 120; i++) {
        shake.advance(1 / 60);
      }

      expect(shake.isShaking, isFalse);
      expect(shake.offset, Vector2.zero());
    });

    test('a second knock does not stack on top of the first', () {
      final shake = ScreenShake(random: Random(4))..hit(6);
      shake.advance(1 / 60);
      shake.hit(2);
      shake.advance(1 / 60);

      // The small knock is swallowed by the big one still in flight, rather
      // than adding to it: two bad landings in a row must not be twice as
      // violent as one.
      expect(shake.offset.x.abs(), lessThanOrEqualTo(6));
    });

    test('reset stops it dead', () {
      final shake = ScreenShake(random: Random(5))..hit(9);
      shake.advance(1 / 60);
      shake.reset();

      expect(shake.isShaking, isFalse);
      expect(shake.offset, Vector2.zero());
    });
  });
}
