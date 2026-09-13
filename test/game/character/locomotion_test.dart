import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/character/locomotion.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/input/input.dart';

/// A body on a flat floor, so the locomotion can be exercised without a game.
class Body {
  final Locomotion locomotion = Locomotion();

  /// Feet position; 0 is the floor, negative is in the air.
  double y = 0;
  double x = 0;
  bool grounded = true;
  double lastImpact = 0;

  void step(InputIntent intent, {int frames = 1, double dt = 1 / 60}) {
    for (var i = 0; i < frames; i++) {
      locomotion.step(dt, intent: intent, grounded: grounded);
      x += locomotion.horizontalVelocity * dt;
      y += locomotion.verticalVelocity * dt;
      if (y >= 0) {
        y = 0;
        final impact = locomotion.land();
        if (!grounded) lastImpact = impact;
        grounded = true;
      } else {
        grounded = false;
      }
    }
  }

  /// Walks off a ledge: a couple of frames standing on it first — coyote time
  /// is measured from the last frame the body was actually supported — then
  /// airborne with a drop underneath, and no jump spent.
  void leaveGround() {
    step(InputIntent.none, frames: 2);
    y = -400;
    grounded = false;
  }
}

const held = InputIntent(jumpHeld: true);
const pressed = InputIntent(jump: true, jumpHeld: true);
const tapped = InputIntent(jump: true);

void main() {
  group('weight', () {
    test('takes a moment to reach full speed', () {
      final body = Body();
      body.step(const InputIntent(moveAxis: 1));
      expect(
        body.locomotion.horizontalVelocity,
        lessThan(WarayaConfig.walkSpeed * 0.5),
        reason: 'one frame in',
      );

      body.step(const InputIntent(moveAxis: 1), frames: 30);
      expect(
        body.locomotion.horizontalVelocity,
        closeTo(WarayaConfig.walkSpeed, 0.01),
      );
    });

    test('slides to a stop rather than stopping dead', () {
      final body = Body()..step(const InputIntent(moveAxis: 1), frames: 30);
      final atRelease = body.x;

      body.step(InputIntent.none);
      expect(body.locomotion.horizontalVelocity, greaterThan(0));
      body.step(InputIntent.none, frames: 20);

      expect(body.locomotion.horizontalVelocity, 0);
      expect(body.x, greaterThan(atRelease), reason: 'it carried on a little');
    });

    test('turning around is quicker than setting off', () {
      final fromRest = Body()..step(const InputIntent(moveAxis: 1), frames: 4);
      final turning = Body()..step(const InputIntent(moveAxis: -1), frames: 30);
      turning.step(const InputIntent(moveAxis: 1), frames: 4);

      // Same four frames of holding right: the one that was already moving
      // left has gained more speed in that direction than the one starting
      // from a standstill.
      expect(
        turning.locomotion.horizontalVelocity - (-WarayaConfig.walkSpeed),
        greaterThan(fromRest.locomotion.horizontalVelocity),
      );
    });

    test('keeps its momentum in the air', () {
      final body = Body()..step(const InputIntent(moveAxis: 1), frames: 30);
      body.step(const InputIntent(moveAxis: 1, jump: true, jumpHeld: true));
      final launch = body.locomotion.horizontalVelocity;

      // Let go of the direction in mid-air. Air drag is light, so most of the
      // speed survives.
      body.step(held, frames: 10);
      final inAir = body.locomotion.horizontalVelocity;

      // The same release on the ground loses it almost at once.
      final grounded = Body()
        ..step(const InputIntent(moveAxis: 1), frames: 30)
        ..step(InputIntent.none, frames: 10);

      expect(body.grounded, isFalse);
      expect(inAir, greaterThan(launch * 0.4));
      expect(inAir, greaterThan(grounded.locomotion.horizontalVelocity));
    });

    test('falls faster than it rose, and not past terminal velocity', () {
      final body = Body()..step(pressed);
      var rising = 0;
      while (body.locomotion.isRising) {
        body.step(held);
        rising++;
      }
      var falling = 0;
      while (!body.grounded) {
        body.step(held);
        falling++;
      }

      expect(falling, lessThan(rising), reason: 'the way down is quicker');
      expect(body.lastImpact, lessThanOrEqualTo(WarayaConfig.maxFallSpeed));
    });

    test('terminal velocity holds on a long drop', () {
      final body = Body()..y = -100000;
      body.grounded = false;
      body.step(InputIntent.none, frames: 600);
      expect(
        body.locomotion.verticalVelocity,
        closeTo(WarayaConfig.maxFallSpeed, 0.001),
      );
    });
  });

  group('jump', () {
    double apexOf(Body body) {
      var apex = 0.0;
      while (!body.grounded) {
        if (body.y < apex) apex = body.y;
        body.step(body.locomotion.isRising ? held : InputIntent.none);
      }
      return -apex;
    }

    test('held to the top clears what the level was measured against', () {
      final body = Body()..step(pressed);
      final height = apexOf(body);
      final designed =
          WarayaConfig.jumpSpeed *
          WarayaConfig.jumpSpeed /
          (2 * WarayaConfig.gravity);

      // Within a few units of the analytic height the test scene is measured
      // against. Not exact: a fixed timestep integrates a parabola in steps.
      expect(height, closeTo(designed, 8));
    });

    test('a tap is a hop', () {
      final tap = Body()..step(tapped);
      var apex = 0.0;
      while (!tap.grounded) {
        if (tap.y < apex) apex = tap.y;
        tap.step(InputIntent.none);
      }

      final full = Body()..step(pressed);
      expect(-apex, lessThan(apexOf(full) * 0.5));
      expect(-apex, greaterThan(0), reason: 'it is still a jump');
    });

    test('coyote time: a jump just after the ledge still counts', () {
      final body = Body()..leaveGround();
      body.step(InputIntent.none, frames: 3); // 50ms off the edge
      expect(body.grounded, isFalse);

      body.step(pressed);
      expect(body.locomotion.jumped, isTrue);
      expect(body.locomotion.isRising, isTrue);
    });

    test('coyote time runs out', () {
      final body = Body()..leaveGround();
      body.step(
        InputIntent.none,
        frames: (WarayaConfig.coyoteSeconds * 60).ceil() + 2,
      );

      body.step(pressed);
      expect(body.locomotion.jumped, isFalse);
    });

    test('coyote time cannot be spent twice', () {
      final body = Body()..step(pressed);
      expect(body.locomotion.jumped, isTrue);

      body.step(pressed, frames: 3);
      expect(body.locomotion.jumped, isFalse, reason: 'no free second jump');
    });

    test('a jump pressed just before landing fires on landing', () {
      final body = Body()..step(pressed);
      // Fall until a few frames short of the ground.
      while (body.locomotion.isRising) {
        body.step(held);
      }
      while (body.y < -30) {
        body.step(InputIntent.none);
      }
      expect(body.grounded, isFalse);

      // Press early, then hold nothing but the direction key.
      body.step(pressed);
      expect(body.locomotion.jumped, isFalse, reason: 'still in the air');
      body.step(held, frames: 8);

      expect(
        body.locomotion.jumped || body.locomotion.isRising,
        isTrue,
        reason: 'the press was remembered through the landing',
      );
    });

    test('the buffer expires rather than firing minutes later', () {
      final body = Body()..step(pressed);
      while (body.locomotion.isRising) {
        body.step(held);
      }
      body.step(tapped);
      // Long enough in the air that the press is stale by the time it lands.
      while (!body.grounded) {
        body.step(InputIntent.none);
      }
      body.step(InputIntent.none, frames: 5);

      expect(body.locomotion.verticalVelocity, greaterThanOrEqualTo(0));
    });
  });

  group('collision hand-back', () {
    test('a wall kills horizontal speed', () {
      final body = Body()..step(const InputIntent(moveAxis: 1), frames: 30);
      expect(body.locomotion.horizontalVelocity, greaterThan(0));

      body.locomotion.stopHorizontally();
      expect(body.locomotion.horizontalVelocity, 0);
    });

    test('landing reports the impact and zeroes the fall', () {
      final locomotion = Locomotion()..verticalVelocity = 900;
      expect(locomotion.land(), 900);
      expect(locomotion.verticalVelocity, 0);
    });

    test('a bumped head stops the climb', () {
      final locomotion = Locomotion()..verticalVelocity = -700;
      locomotion.stopRising();
      expect(locomotion.verticalVelocity, 0);
    });
  });

  test('reset puts everything back', () {
    final body = Body()..step(const InputIntent(moveAxis: 1), frames: 10);
    body.step(pressed);

    body.locomotion.reset();

    expect(body.locomotion.horizontalVelocity, 0);
    expect(body.locomotion.verticalVelocity, 0);
    expect(body.locomotion.hasGroundUnderfoot, isFalse);
  });
}
