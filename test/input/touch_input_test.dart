import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/input/touch_input_source.dart';

/// The phone's controls, finger by finger (`docs/phase-11-feel.md` §2).
///
/// Whatever they look like, they come out as an `InputIntent` and nothing
/// else — so what is checked here is only that each gesture asks for what it
/// says.
void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  // A phone on its side.
  TouchInputSource controls({double scale = 1}) =>
      TouchInputSource(scale: () => scale)..onGameResize(Vector2(900, 420));

  test('a thumb anywhere on the left walks the way it is dragged', () {
    final touch = controls();
    touch.debugDown(1, Vector2(200, 200));
    expect(touch.poll().moveAxis, 0, reason: 'landing is not a step');

    touch.debugMove(1, Vector2(240, 205));
    expect(touch.poll().moveAxis, 1);

    touch.debugMove(1, Vector2(150, 205));
    expect(touch.poll().moveAxis, -1);

    touch.debugUp(1);
    expect(touch.poll().moveAxis, 0);
  });

  test('a stick dragged far keeps up when the thumb turns back', () {
    final touch = controls();
    touch.debugDown(1, Vector2(200, 200));
    touch.debugMove(1, Vector2(400, 200));
    expect(touch.poll().moveAxis, 1);
    // Back only a little, from far past the ring: the ring followed the
    // thumb, so this is already a walk the other way.
    touch.debugMove(1, Vector2(330, 200));
    expect(touch.poll().moveAxis, -1);
  });

  test('down on the same thumb crouches; a drifting walk does not', () {
    final touch = controls();
    touch.debugDown(1, Vector2(200, 200));
    touch.debugMove(1, Vector2(240, 215));
    var intent = touch.poll();
    expect(intent.moveAxis, 1);
    expect(intent.crouch, isFalse, reason: 'a walk that drifts down a little');

    touch.debugMove(1, Vector2(240, 245));
    intent = touch.poll();
    expect(intent.crouch, isTrue);
    expect(intent.moveAxis, 1, reason: 'walking and ducking at once');
  });

  test('the jump button jumps once per press and holds while held', () {
    final touch = controls();
    // Bottom right, where the jump button is.
    touch.debugDown(2, Vector2(900 - 72, 420 - 72));
    var intent = touch.poll();
    expect(intent.jump, isTrue);
    expect(intent.jumpHeld, isTrue);
    intent = touch.poll();
    expect(intent.jump, isFalse, reason: 'one press is one jump');
    expect(intent.jumpHeld, isTrue);
    touch.debugUp(2);
    expect(touch.poll().jumpHeld, isFalse);
  });

  test('a walk and a jump are two thumbs, and neither loses the other', () {
    final touch = controls();
    touch.debugDown(1, Vector2(200, 200));
    touch.debugMove(1, Vector2(250, 200));
    touch.debugDown(2, Vector2(900 - 72, 420 - 72));
    final intent = touch.poll();
    expect(intent.moveAxis, 1);
    expect(intent.jump, isTrue);
  });

  test('the right half is not a stick', () {
    final touch = controls();
    touch.debugDown(1, Vector2(600, 150));
    touch.debugMove(1, Vector2(700, 150));
    expect(touch.poll().moveAxis, 0);
    expect(touch.stickHeld, isFalse);
  });

  test('bigger buttons are bigger to hit', () {
    // Above a normal jump button and out of its reach; inside a large one.
    final point = Vector2(900 - 72, 420 - 72 - 80);
    final normal = controls()..debugDown(2, point);
    final large = controls(scale: 1.3)..debugDown(2, point);
    expect(normal.poll().jump, isFalse);
    expect(large.poll().jump, isTrue);
  });

  test('nothing on a desktop, where there are no fingers', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final touch = controls();
    touch.debugDown(1, Vector2(200, 200));
    touch.debugMove(1, Vector2(260, 200));
    expect(touch.poll().isIdle, isTrue);
  });
}
