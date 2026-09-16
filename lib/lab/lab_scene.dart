import 'dart:ui';

/// The grey-box test scene, as plain geometry.
///
/// The plan insists the shadow gets tested on **grey blocks, not in the pretty
/// environment**: nice art flatters a mechanic and Phase 2 exists to find out
/// whether the mechanic stands up without help. Nothing in this file is art
/// direction, and none of it should ever move into the real game.
///
/// One scene holds all three Friday tests, laid out left to right:
///
/// ```
///  door    plate        corridor      spawn   platform  ledge
///  -980    -560       -280..-80         0     300..520  560..1000
///  |-- test 1: the plate --|  |- test 3 -|    |--- test 2 ---|
/// ```
///
/// The numbers are chosen against the character's real jump (see
/// [WarayaConfig]: a jump clears about 136 units), so:
///
/// * the low platform is 120 above the floor — reachable alone;
/// * the ledge is 170 above the low platform — *not* reachable alone, and 74
///   above the head of a shadow standing on the low platform, which is;
/// * the door is too tall to jump over, so the plate is the only way through;
/// * the corridor ceiling leaves an 80-unit gap: a crouched body fits, a
///   standing one does not, and a jump certainly does not — so there is
///   nowhere to dodge when `shadowKills` is on.
abstract final class LabScene {
  /// Top surface of the floor, in world units from the top of the screen.
  static const double floorTop = 620;

  /// Deeper than the screen on purpose: only the top edge is ever seen, and a
  /// thick floor is one more thing standing between a lag spike and a player
  /// who fell out of the world.
  static const Rect floor = Rect.fromLTRB(-1300, floorTop, 1300, 1200);

  /// Test 2, step one: a normal jump gets you here.
  static const Rect lowPlatform = Rect.fromLTRB(300, 500, 520, 560);

  /// Test 2, step two: only a jump off the shadow's head gets you here.
  static const Rect ledge = Rect.fromLTRB(560, 330, 1000, 380);

  /// Test 3: low enough that you have to duck through it, which means you
  /// cross it slowly and cannot jump — so there is nowhere to go when the
  /// shadow comes the other way.
  static const Rect corridorCeiling = Rect.fromLTRB(-280, 450, -80, 540);

  /// Test 1: the door, closed. Taller than the character's jump, and taller
  /// than a jump taken from the head of a shadow standing at its foot — see
  /// `Levels.minDoorHeight`.
  static const Rect door = Rect.fromLTRB(-993, 360, -967, floorTop);

  /// Test 1: the plate. Held down by anything standing on it — including a
  /// shadow, which is the entire point.
  static const Rect plate = Rect.fromLTRB(-610, 608, -510, floorTop);

  /// Slightly taller than the plate so a body resting on it counts as on it.
  static const Rect plateTrigger = Rect.fromLTRB(-610, 580, -510, 622);

  static const Rect goalBehindDoor = Rect.fromLTRB(-1160, 548, -1090, floorTop);
  static const Rect goalOnLedge = Rect.fromLTRB(860, 258, 930, 330);

  /// Everything that blocks movement on all sides. The door is not here: it
  /// blocks only while closed, so it manages its own rect.
  static const List<Rect> blocking = [
    floor,
    lowPlatform,
    ledge,
    corridorCeiling,
  ];

  static const double spawnX = 0;

  // Grey-box palette. Light ground, dark bodies: the real game is a
  // silhouette game, and a black character on a dark test scene would tell us
  // nothing about the shadow's opacity.
  static const Color background = Color(0xFFB4B4B4);
  static const Color blockFill = Color(0xFF6E6E6E);
  static const Color blockTop = Color(0xFF8C8C8C);
  static const Color blockEdge = Color(0xFF4A4A4A);
  static const Color plateUp = Color(0xFF8C8C8C);
  static const Color plateDown = Color(0xFF3A3A3A);
  static const Color doorColor = Color(0xFF5A5A5A);
  static const Color goalIdle = Color(0xFF9A9A9A);
  static const Color goalReached = Color(0xFF2B2B2B);
  static const Color bodyColor = Color(0xFF141414);
  static const Color trailColor = Color(0xFF3C3C3C);
}
