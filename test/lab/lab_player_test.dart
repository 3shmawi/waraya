import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/input/input.dart';
import 'package:waraya/input/input_controller.dart';
import 'package:waraya/lab/lab_player.dart';
import 'package:waraya/lab/lab_scene.dart';
import 'package:waraya/shadow/snapshot.dart';

class ScriptedSource implements InputSource {
  @override
  String get label => 'scripted';

  @override
  bool hasBeenUsed = true;

  InputIntent next = InputIntent.none;

  @override
  InputIntent poll() => next;
}

/// Steps the player the way the game does: refresh input, then update.
void step(
  LabPlayer player,
  InputController input,
  ScriptedSource source, {
  InputIntent intent = InputIntent.none,
  int frames = 1,
  double dt = 1 / 60,
}) {
  for (var i = 0; i < frames; i++) {
    source.next = intent;
    input.refresh();
    player.update(dt);
  }
}

void main() {
  late ScriptedSource source;
  late InputController input;

  setUp(() {
    source = ScriptedSource();
    input = InputController([source]);
  });

  LabPlayer playerWith(LabSolids solids) =>
      LabPlayer(input: input, solids: () => solids);

  group('LabPlayer collision', () {
    test('settles on the floor and stays grounded', () {
      final player = playerWith(const LabSolids(blocking: [LabScene.floor]));

      step(player, input, source, frames: 30);

      expect(player.y, closeTo(LabScene.floorTop, 0.001));
      expect(player.isGrounded, isTrue);
      expect(player.verticalVelocity, 0);
    });

    test('is stopped by a wall instead of walking through it', () {
      const wall = Rect.fromLTRB(200, 400, 260, 700);
      final player = playerWith(
        const LabSolids(blocking: [LabScene.floor, wall]),
      );

      step(
        player,
        input,
        source,
        intent: const InputIntent(moveAxis: 1),
        frames: 120,
      );

      expect(player.bounds.right, closeTo(wall.left, 0.001));
    });

    test('lands on a one-way surface from above', () {
      const ledge = Rect.fromLTRB(-100, 400, 100, 460);
      final player = playerWith(
        const LabSolids(blocking: [LabScene.floor], oneWay: [ledge]),
      );
      // Drop it in from above the ledge.
      player.position.y = 300;

      step(player, input, source, frames: 60);

      expect(player.y, closeTo(ledge.top, 0.001));
      expect(player.isOnShadow, isTrue, reason: 'one-way means the shadow');
      expect(player.isGrounded, isTrue);
    });

    test('jumps up through a one-way surface, then lands on it', () {
      // A shadow overhead must not act as a ceiling on the way up, and must
      // still be a platform on the way down.
      const overhead = Rect.fromLTRB(-100, 560, 100, 600);
      final player = playerWith(
        const LabSolids(blocking: [LabScene.floor], oneWay: [overhead]),
      );
      step(player, input, source, frames: 2);

      step(player, input, source, intent: const InputIntent(jump: true));
      var apex = player.y;
      for (var i = 0; i < 24; i++) {
        step(player, input, source);
        if (player.y < apex) apex = player.y;
      }

      expect(apex, lessThan(overhead.top), reason: 'the jump carried through');

      step(player, input, source, frames: 40);
      expect(player.y, closeTo(overhead.top, 0.001));
      expect(player.isOnShadow, isTrue);
    });

    test('a one-way surface appearing around the player does not trap it', () {
      // The shadow does not travel: it is placed from the buffer, so it can
      // appear straddling the player. If that snapped the player onto its
      // roof, or blocked them sideways, the mechanic would feel broken in
      // exactly the way the plan warns about.
      const straddling = Rect.fromLTRB(-100, 560, 100, 640);
      final player = playerWith(
        const LabSolids(blocking: [LabScene.floor], oneWay: [straddling]),
      );

      step(player, input, source, frames: 5);
      expect(player.y, closeTo(LabScene.floorTop, 0.001));
      expect(player.isOnShadow, isFalse);

      step(
        player,
        input,
        source,
        intent: const InputIntent(moveAxis: 1),
        frames: 30,
      );
      expect(player.x, greaterThan(50), reason: 'still free to walk out');
      expect(player.y, closeTo(LabScene.floorTop, 0.001));
    });

    test('rides along when the surface under it moves', () {
      const ledge = Rect.fromLTRB(-100, 400, 100, 460);
      final player = playerWith(
        const LabSolids(blocking: [LabScene.floor], oneWay: [ledge]),
      );
      player.position.y = 300;
      step(player, input, source, frames: 60);
      expect(player.isOnShadow, isTrue);

      final before = player.x;
      player.carryX = 12;
      step(player, input, source);

      expect(player.x, closeTo(before + 12, 0.001));
      expect(player.carryX, 0, reason: 'carry is consumed, not accumulated');
    });
  });

  group('LabPlayer.capture', () {
    test('reports the pose the figure is drawing', () {
      final player = playerWith(const LabSolids(blocking: [LabScene.floor]));

      step(player, input, source, frames: 5);
      expect(player.capture().state, PoseState.idle);

      step(player, input, source, intent: const InputIntent(moveAxis: -1));
      final walking = player.capture();
      expect(walking.state, PoseState.walk);
      expect(walking.facing, -1);

      step(player, input, source, intent: const InputIntent(jump: true));
      expect(player.capture().state, PoseState.jump);

      // Up, over the top, and on the way back down.
      step(player, input, source, frames: 40);
      expect(player.capture().state, PoseState.fall);
    });

    test('the jump flag is an edge, recorded once', () {
      final player = playerWith(const LabSolids(blocking: [LabScene.floor]));
      step(player, input, source, frames: 5);

      step(player, input, source, intent: const InputIntent(jump: true));
      expect(player.capture().jumpPressed, isTrue);
      expect(player.capture().jumpPressed, isFalse);
    });

    test('records position, not input', () {
      // The distinction the whole approach rests on: what comes out is where
      // the body ended up after collision, not what the player asked for.
      const wall = Rect.fromLTRB(60, 400, 120, 700);
      final player = playerWith(
        const LabSolids(blocking: [LabScene.floor, wall]),
      );

      step(
        player,
        input,
        source,
        intent: const InputIntent(moveAxis: 1),
        frames: 60,
      );

      final snapshot = player.capture();
      expect(snapshot.x, closeTo(wall.left - 22, 0.001));
      expect(
        snapshot.x,
        lessThan(WarayaConfig.walkSpeed),
        reason: 'a second of held right, but the wall had the last word',
      );
    });
  });
}
