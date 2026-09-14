import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/input.dart';

void main() {
  group('InputIntent.merge', () {
    test('keeps the stronger axis', () {
      const weak = InputIntent(moveAxis: 0.3);
      const strong = InputIntent(moveAxis: -1.0);
      expect(weak.merge(strong).moveAxis, -1.0);
      expect(strong.merge(weak).moveAxis, -1.0);
    });

    test('jump is sticky so a tap is never swallowed', () {
      const tapped = InputIntent(jump: true);
      expect(InputIntent.none.merge(tapped).jump, isTrue);
      expect(tapped.merge(InputIntent.none).jump, isTrue);
    });

    test('crouch survives a merge from either side', () {
      const held = InputIntent(crouch: true);
      expect(InputIntent.none.merge(held).crouch, isTrue);
      expect(held.merge(InputIntent.none).crouch, isTrue);
    });

    test('a held crouch is not idle', () {
      expect(const InputIntent(crouch: true).isIdle, isFalse);
    });

    test('merging nothing stays idle', () {
      expect(InputIntent.none.merge(InputIntent.none).isIdle, isTrue);
    });
  });
}
