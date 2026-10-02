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

  // The pad's middle on a 900x420 screen: margin 26 + radius 54 in from the
  // bottom left.
  final pad = Vector2(80, 340);

  test('the pad walks the way the thumb is from its middle', () {
    final touch = controls();
    touch.debugDown(1, pad.clone());
    expect(touch.poll().moveAxis, 0, reason: 'the middle is standing still');

    touch.debugMove(1, pad + Vector2(30, 4));
    expect(touch.poll().moveAxis, 1);

    touch.debugMove(1, pad + Vector2(-30, -4));
    expect(touch.poll().moveAxis, -1);

    touch.debugUp(1);
    expect(touch.poll().moveAxis, 0);
  });

  test('the pad stays where it is drawn', () {
    // Reported from playing: the first version followed the thumb.
    final touch = controls();
    final before = touch.stickCentre;
    touch.debugDown(1, pad + Vector2(-40, 10));
    expect(touch.poll().moveAxis, -1, reason: 'pressing left of it walks');
    touch.debugMove(1, pad + Vector2(300, 0));
    touch.debugMove(1, pad + Vector2(20, 0));
    expect(touch.poll().moveAxis, 1, reason: 'no ring dragged along behind');
    expect(touch.stickCentre, before);
  });

  test('crouch is the button, and only the button', () {
    // Two ways to crouch were one too many: an accidental crouch is an
    // accidental step left for your past.
    final touch = controls();
    touch.debugDown(1, pad.clone());
    touch.debugMove(1, pad + Vector2(30, 60));
    final intent = touch.poll();
    expect(intent.moveAxis, 1);
    expect(intent.crouch, isFalse, reason: 'dragging down does not duck');

    // The crouch button: left of jump, a little lower.
    touch.debugDown(2, Vector2(900 - 72 - 100, 420 - 72 + 10));
    expect(touch.poll().crouch, isTrue);
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
    touch.debugDown(1, pad + Vector2(30, 0));
    touch.debugDown(2, Vector2(900 - 72, 420 - 72));
    final intent = touch.poll();
    expect(intent.moveAxis, 1);
    expect(intent.jump, isTrue);
  });

  test('nowhere but the pad walks', () {
    final touch = controls();
    touch.debugDown(1, Vector2(400, 150));
    touch.debugMove(1, Vector2(500, 150));
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
    touch.debugDown(1, pad.clone());
    touch.debugMove(1, pad + Vector2(40, 0));
    expect(touch.poll().isIdle, isTrue);
  });
}
