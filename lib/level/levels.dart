import 'dart:ui';

import '../lab/lab_scene.dart';
import 'level.dart';

/// The puzzles.
///
/// Every measurement here is set against what the character can actually do —
/// a jump lifts about 130 units and carries about 150 across, a standing body
/// is 96 tall and a crouched one 69, walking is 220 units a second. Those
/// numbers are in `WarayaConfig`, and `test/level/levels_test.dart` checks the
/// consequences rather than trusting the arithmetic in this comment: that the
/// ledge in `standOnYourself` really is out of reach without the shadow, and
/// that each level really is finishable, by replaying a recorded solution
/// through the actual game.
///
/// The order teaches. Each level introduces exactly one idea and then leaves
/// it alone; the fourth will combine them, and does not exist yet.
abstract final class Levels {
  static const double _floor = 620;

  /// Ground from [left] to [right], deep enough that nothing falls through it.
  static Rect _ground(double left, double right) =>
      Rect.fromLTRB(left, _floor, right, 1200);

  /// **Use one: the button.** A plate too far from the door to use yourself.
  ///
  /// The player presses it, sees the door open and shut again as they walk
  /// away, and has to work out that the way to hold it open is to have been
  /// standing on it three seconds ago. Flat ground, no jumping: the only new
  /// thing is the idea.
  static final Level pressItEarly = Level(
    id: 'press-it-early',
    name: 'قبل ما تحتاجه',
    teaches: 'الزرار محتاج حد يقف عليه. مفيش حد غيرك.',
    delaySeconds: 3.5,
    spawnX: 0,
    floorTop: _floor,
    blocks: [_ground(-700, 700)],
    // The plate is the opposite way from the door on purpose. Put it between
    // the player and the door and the level solves itself: you cross it on
    // your way past, and three seconds later your shadow crosses it too and
    // opens the door while you happen to be standing there. A puzzle you beat
    // by holding one key teaches nothing, and a test pins that this one
    // cannot be.
    plates: const [
      PlateSpec(area: Rect.fromLTRB(300, 608, 420, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-200, 430, -174, 620)),
    ],
    goal: const Rect.fromLTRB(-420, 548, -340, 620),
  );

  /// **Use two: the platform.** A ledge nothing can reach.
  ///
  /// The shadow's head is 96 units off the ground and a jump lifts 130, so a
  /// ledge at 430 is reachable from a shadow standing on the floor and from
  /// nowhere else. The player has to stand still somewhere useless, walk away,
  /// and come back to a body that is now furniture.
  static final Level standOnYourself = Level(
    id: 'stand-on-yourself',
    name: 'اوقف على نفسك',
    teaches: 'انت الوحيد اللي ممكن تبقى السلّمة.',
    delaySeconds: 3.5,
    spawnX: 500,
    floorTop: _floor,
    blocks: [_ground(-900, 900), const Rect.fromLTRB(-700, 430, -280, 470)],
    goal: const Rect.fromLTRB(-620, 358, -540, 430),
  );

  /// **Use three: the obstacle.** The way back is the one place you cannot go.
  ///
  /// The shadow kills here, and it is walking the corridor you walked in
  /// along. There is a second lane above it; the plate at the dead end is the
  /// reason to go in, and the door is the reason to come back. Retracing your
  /// steps is the obvious move and it is fatal, which is the lesson.
  static final Level notTheSameWayBack = Level(
    id: 'not-the-same-way-back',
    name: 'مش نفس السكة',
    teaches: 'ظلك جاي في نفس السكة. دوّر على سكة تانية.',
    // Five seconds, and the layout does the forcing rather than the number.
    // The player starts beside the door, so the shadow's first steps are
    // through the one spot you would otherwise stand and wait in: leaving the
    // corridor early and loitering by the door is the obvious plan, and it is
    // the plan that walks you into yourself.
    delaySeconds: 5,
    spawnX: 60,
    floorTop: _floor,
    shadowKills: true,
    blocks: [
      _ground(-600, 600),
      // The roof over the corridor.
      const Rect.fromLTRB(-420, 300, 80, 340),
      // The upper lane: the way home, and the only place to wait. It stops
      // well short of the step, because a lane directly over the step is a
      // ceiling — the body is 44 wide, and a narrower gap than that leaves
      // the head clipping the lane and the jump going nowhere.
      const Rect.fromLTRB(-300, 480, 80, 496),
      // The step up to it, wide enough to take a run at the gap from.
      const Rect.fromLTRB(-470, 550, -380, 620),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-340, 608, -240, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(100, 430, 126, 620)),
    ],
    goal: const Rect.fromLTRB(200, 548, 280, 620),
  );

  /// In teaching order.
  static final List<Level> campaign = [
    pressItEarly,
    standOnYourself,
    notTheSameWayBack,
  ];

  /// The Phase 2 tuning bench, as a level so it runs on the same code as the
  /// puzzles. Not part of the campaign: it is where the numbers get argued
  /// with, not somewhere to be finished.
  static final Level lab = Level(
    id: 'lab',
    name: 'الورشة',
    teaches: 'جرّب الأرقام. R يعيد المشهد.',
    delaySeconds: 2.6,
    spawnX: LabScene.spawnX,
    floorTop: LabScene.floorTop,
    blocks: LabScene.blocking,
    plates: const [PlateSpec(area: LabScene.plate, opens: 'gate')],
    doors: const [DoorSpec(id: 'gate', closed: LabScene.door)],
    goal: LabScene.goalBehindDoor,
    markers: const [LabScene.goalOnLedge],
  );
}
