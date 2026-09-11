import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/input/input_controller.dart';

/// Stands in for a real backend so the controller can be tested without a
/// keyboard, a finger, or a game loop.
class _FakeSource implements InputSource {
  _FakeSource(this.label);

  @override
  final String label;

  InputIntent next = InputIntent.none;
  int pollCount = 0;

  @override
  bool hasBeenUsed = false;

  @override
  InputIntent poll() {
    pollCount++;
    final intent = next;
    next = InputIntent.none; // edge-triggered, like the real sources
    return intent;
  }
}

void main() {
  test('merges every source once per refresh', () {
    final keys = _FakeSource('keyboard')..next = const InputIntent(jump: true);
    final touch = _FakeSource('touch')..next = const InputIntent(moveAxis: -1);
    final controller = InputController([keys, touch]);

    controller.refresh();

    expect(controller.intent.jump, isTrue);
    expect(controller.intent.moveAxis, -1);
    expect(keys.pollCount, 1);
    expect(touch.pollCount, 1);
  });

  test('edge-triggered jump clears on the next frame', () {
    final keys = _FakeSource('keyboard')..next = const InputIntent(jump: true);
    final controller = InputController([keys]);

    controller.refresh();
    expect(controller.intent.jump, isTrue);

    controller.refresh();
    expect(controller.intent.jump, isFalse);
  });

  test('activeLabel reports only schemes actually used', () {
    final keys = _FakeSource('keyboard');
    final touch = _FakeSource('touch');
    final controller = InputController([keys, touch]);

    expect(controller.activeLabel, 'waiting for input');

    touch.hasBeenUsed = true;
    expect(controller.activeLabel, 'touch');

    keys.hasBeenUsed = true;
    expect(controller.activeLabel, 'keyboard + touch');
  });
}
