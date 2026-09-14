import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/config.dart';
import 'package:waraya/lab/lab_scene.dart';

/// The grey-box scene is not decoration — its measurements are the puzzle.
/// Each of these pins one of the three Friday tests to the character's actual
/// jump, so a later tweak to jump height or to a platform cannot quietly turn
/// "you need the shadow" into "you don't", which would make a Friday session
/// prove nothing.
void main() {
  // v^2 / 2g: how far a jump rises before gravity wins.
  const jumpHeight =
      WarayaConfig.jumpSpeed *
      WarayaConfig.jumpSpeed /
      (2 * WarayaConfig.gravity);
  const bodyHeight = 96.0;

  test('a jump clears about 136 units', () {
    expect(jumpHeight, closeTo(136, 1));
  });

  test('test 2: the low platform is reachable on your own', () {
    expect(LabScene.floorTop - LabScene.lowPlatform.top, lessThan(jumpHeight));
  });

  test('test 2: the ledge is not reachable without the shadow', () {
    // Not from the floor, and not from the low platform either.
    expect(LabScene.floorTop - LabScene.ledge.top, greaterThan(jumpHeight));
    expect(
      LabScene.lowPlatform.top - LabScene.ledge.top,
      greaterThan(jumpHeight),
    );
  });

  test('test 2: the ledge is reachable off a shadow on the low platform', () {
    final shadowHead = LabScene.lowPlatform.top - bodyHeight;
    expect(shadowHead - LabScene.ledge.top, lessThan(jumpHeight));
    // And the jump across has to be short enough to actually cross. Rise and
    // fall are no longer symmetric — Phase 3 made the way down faster — so
    // the airtime is the sum of the two halves, not twice one of them.
    final gap = LabScene.ledge.left - LabScene.lowPlatform.right;
    final rise = WarayaConfig.jumpSpeed / WarayaConfig.gravity;
    final height =
        WarayaConfig.jumpSpeed *
        WarayaConfig.jumpSpeed /
        (2 * WarayaConfig.gravity);
    final fall = sqrt(2 * height / WarayaConfig.fallGravity);
    expect(gap, lessThan(WarayaConfig.walkSpeed * (rise + fall)));
  });

  test('test 1: the door cannot be jumped over', () {
    expect(LabScene.floorTop - LabScene.door.top, greaterThan(jumpHeight));
  });

  test('test 1: the plate is far enough from the door to need the delay', () {
    final walk = (LabScene.plate.center.dx - LabScene.door.center.dx).abs();
    // At walking speed, crossing this takes longer than the shortest delay the
    // panel offers — so at the low end of the slider the puzzle is impossible
    // and at the high end it is a wait. That range is the thing being tested.
    expect(walk / WarayaConfig.walkSpeed, greaterThan(1.5));
  });

  test('test 3: the corridor takes a crouched body and nothing taller', () {
    final gap = LabScene.floorTop - LabScene.corridorCeiling.bottom;
    expect(
      gap,
      greaterThan(bodyHeight * WarayaConfig.crouchHeightFactor),
      reason: 'ducking has to get you through',
    );
    expect(gap, lessThan(bodyHeight), reason: 'walking through must not');
  });

  test('the shadow-platform goal sits on the ledge, not floating', () {
    expect(LabScene.goalOnLedge.bottom, LabScene.ledge.top);
    expect(LabScene.goalOnLedge.left, greaterThan(LabScene.ledge.left));
    expect(LabScene.goalOnLedge.right, lessThan(LabScene.ledge.right));
  });

  test('the door goal is behind the door', () {
    expect(LabScene.goalBehindDoor.right, lessThan(LabScene.door.left));
    expect(LabScene.goalBehindDoor.left, greaterThan(LabScene.floor.left));
  });
}
