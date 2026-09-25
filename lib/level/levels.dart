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

  /// The shortest a door is allowed to be, measured from whatever it stands on.
  ///
  /// A jump lifts about 136 and a body is 96 tall, so a player standing on a
  /// shadow that is standing on a door's own sill gets their feet 232 above
  /// that sill. Every door in the game used to be 190 tall, which made
  /// "leave a body by the door, climb it, step over" a second solution to
  /// every door in the campaign — reported from playing, and it collapses the
  /// first level completely, since the plate is the only thing that level is
  /// about.
  ///
  /// 250 clears 232 with room to spare, and `levels_test.dart` holds every
  /// door to it so a new one cannot quietly reintroduce the shortcut.
  static const double minDoorHeight = 250;

  /// Ground from [left] to [right], deep enough that nothing falls through it.
  /// How far past the ends of the play area the ground keeps going.
  ///
  /// The camera shows about 640 world units either side of the player on a
  /// 16:9 screen and more on a wider one, so a ground rect that stops at the
  /// edge of the puzzle is a ledge you can see over and walk off. Nothing in
  /// any level uses the end of the ground for anything, and falling off the
  /// map is not a failure any of them meant to have, so it simply carries on
  /// past where the camera can look.
  static const double _offstage = 900;

  /// Ground under the whole of [left] to [right], and well past both ends.
  ///
  /// Deep as well as wide. A phone held upright zooms the camera out far
  /// enough to see roughly 1200 units below the middle of the world, so a slab
  /// that stopped at 1200 ran out exactly where someone could see it.
  static Rect _ground(double left, double right) =>
      Rect.fromLTRB(left - _offstage, _floor, right + _offstage, 2200);

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
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-200, 360, -174, 620)),
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
    // Six seconds of grace. Without any, the level is a stopwatch: the door is
    // held open only for as long as you happened to stand on the plate, that
    // window arrives exactly five seconds later, and the lane you come home
    // along is a sixteen-unit shelf with your own past walking up it behind
    // you. Arrive a beat late and there is no door, no room to dodge and
    // nothing to do but watch yourself arrive. The lesson here is "your old
    // path is deadly, find another one" — not "hit this one second".
    //
    // Six and not forever. A door that latches open never shuts again, and a
    // door that never shuts is not a door your past is holding — that version
    // was reported back as a bug the day it shipped.
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(100, 360, 126, 620),
        lingerSeconds: 6,
      ),
    ],
    goal: const Rect.fromLTRB(200, 548, 280, 620),
  );

  /// **Use four: the sacrifice.** A drop with no way back up.
  ///
  /// The plate is on the shelf you start on; the door is at the bottom of a
  /// fall you cannot climb out of. So the whole level is one decision made
  /// before you can see whether it worked: stand on the plate long enough,
  /// then throw yourself off, and wait in a hole for a body that is four
  /// seconds behind you to do the thing you can no longer do.
  ///
  /// Get it wrong and there is no death and no penalty — just a hole, and R.
  /// That is the point. The cost is commitment, not damage.
  static final Level takeItWithYou = Level(
    id: 'take-it-with-you',
    name: 'خُد قرارك واقفز',
    teaches: 'اللي تحت مفيش رجوع منه. اتأكد إنك سيبت حاجة وراك.',
    delaySeconds: 4.5,
    // On the shelf, not the floor: this level starts you above the level it
    // is really about.
    spawnX: 0,
    floorTop: 430,
    blocks: [
      _ground(-900, 500),
      // The shelf, and the only way off it is down.
      const Rect.fromLTRB(-200, 430, 500, 470),
    ],
    // At the far end from the drop, for the reason `pressItEarly` learned the
    // hard way: a plate on the way to where you are going is a plate you press
    // by accident, and a puzzle you solve by holding one key.
    plates: const [
      PlateSpec(area: Rect.fromLTRB(340, 418, 460, 430), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-420, 360, -394, 620)),
    ],
    goal: const Rect.fromLTRB(-620, 548, -540, 620),
  );

  /// **All of it at once.** A door you need your past for, and then a ledge
  /// you need your past for, from the same three seconds of history.
  ///
  /// Nothing new is introduced. The only new thing is that both setups are in
  /// flight at the same time, and the order they were laid down in is the
  /// order they come back in.
  static final Level bothAtOnce = Level(
    id: 'both-at-once',
    name: 'الاتنين مع بعض',
    teaches: 'ظل واحد، مهمتين. الترتيب اللي عملتهم بيه هو اللي راجع بيه.',
    delaySeconds: 3,
    spawnX: -200,
    floorTop: _floor,
    blocks: [
      _ground(-900, 900),
      // Too high to reach on your own legs; not too high from your own head.
      const Rect.fromLTRB(380, 430, 800, 470),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-500, 608, -380, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-100, 360, -74, 620)),
    ],
    goal: const Rect.fromLTRB(600, 358, 680, 430),
  );

  /// **Use five: the shape.** Your shadow is the shape you were in, and there
  /// is exactly one place you were allowed to be a full-height one.
  ///
  /// A roof eighty units off the floor runs almost the whole level. A standing
  /// body is ninety-six and does not fit; a crouched one is sixty-nine and
  /// does. So the whole level is walked bent over — except for one gap in the
  /// roof, which is the only place in the level where you can stand up.
  ///
  /// The way out is on top of the roof, and the roof is out of reach of any
  /// jump made from the floor. The only thing tall enough to climb is a
  /// standing body, and the only place you are allowed to leave one is that
  /// gap. So the gap is where the ladder has to be built, and it has to be
  /// built before you need it, from the one spot you can build it in.
  ///
  /// Nothing here is a stopwatch. The shadow stands in the gap for exactly as
  /// long as you stood there, so a player who wants more room simply waits
  /// longer — the level is made harder by having more to work out, not by
  /// giving less time to do it in.
  static final Level goInLow = Level(
    id: 'go-in-low',
    name: 'خُش واطي',
    teaches: 'تحت السقف مفيش وقوف. المكان الوحيد اللي تقف فيه هو مكان السلّمة.',
    delaySeconds: 4,
    spawnX: 330,
    floorTop: _floor,
    blocks: [
      _ground(-600, 600),
      // The roof, in two pieces. Its underside is eighty above the floor —
      // crouched fits, standing does not. Its top is a hundred and sixty
      // above, and a jump lifts a hundred and thirty, so the floor cannot
      // reach it and the only way up is over something.
      const Rect.fromLTRB(-420, 460, -180, 540),
      const Rect.fromLTRB(0, 460, 220, 540),
    ],
    // The gap between those two, -180 to 0, is the only headroom in the level.
    // A hundred and eighty wide: two forty-four-wide bodies, the one you leave
    // and the one that climbs it, with room to take a step.
    goal: const Rect.fromLTRB(120, 388, 200, 460),
  );

  /// **Use six: the two jobs at once, from one second of your past.** You end
  /// up standing on the very thing that is holding your way out open.
  ///
  /// The shelf is out of reach of any jump from the floor, so the only way up
  /// is over a standing body, and the only standing body available is the one
  /// on the plate. That plate holds the door on the shelf. So the body under
  /// your feet and the hand on the door are the same body, in the same
  /// seconds — and the moment it stops standing there, the door shuts and you
  /// are on a shelf with a wall.
  ///
  /// Which makes the length of time you stood on that plate the length of time
  /// you have to climb yourself, run the shelf and get through. That is the
  /// lesson, and it is a lever the player holds rather than a window they have
  /// to hit: stand longer, get longer. A one-second press puts you on the shelf
  /// looking at a shut door, which is a failure you can read off the screen and
  /// fix without being told.
  ///
  /// Nothing kills here. Getting it wrong costs the walk back, not a life.
  static final Level holdYourOwnDoor = Level(
    id: 'hold-your-own-door',
    name: 'واقف على اللي فاتحلك',
    teaches: 'قد ما وقفت على الزرار، قد ما الباب هيفضل مفتوح.',
    delaySeconds: 5,
    spawnX: 400,
    floorTop: _floor,
    blocks: [
      _ground(-600, 600),
      // Its top is a hundred and ninety above the floor and a jump lifts a
      // hundred and thirty, so the floor cannot reach it from anywhere along
      // its length.
      const Rect.fromLTRB(60, 430, 520, 470),
    ],
    // Far to the left of everything, in the open: you need floor to take a
    // run at your own head from, and the shelf overhead would cap the jump.
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-100, 608, 0, 620), opens: 'gate'),
    ],
    // Two hundred and sixty tall, standing on the shelf: enough that a body
    // standing on a *shadow* standing on the shelf still cannot top it. See
    // the note on door heights at the top of this file.
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(300, 170, 326, 430)),
    ],
    goal: const Rect.fromLTRB(420, 358, 500, 430),
  );

  /// **Use seven: the key.** The first thing in the game your past *undoes*.
  ///
  /// Six levels have taught one shape of the same idea: leave a body
  /// somewhere and it presses what you cannot reach. A plate is a question
  /// the door asks every frame, and the answer your past gives is always a
  /// gift. A key is not that. It flips on the edge — the instant a body
  /// arrives — and it flips for the body walking your path four and a half
  /// seconds back exactly as it flips for you. So the door it opens is a door
  /// that shuts itself, on a timer you cannot see and did not set, and the
  /// thing that shuts it is you.
  ///
  /// Which makes the habit the trap. The move the last six levels drilled is
  /// *wait for your past to come and hold it*, and waiting on this is the one
  /// thing that cannot work: stand on the key until your shadow arrives and
  /// its arrival is the flip that shuts the door for good. The level is won by
  /// touching the key and leaving — knowing the door behind you is already
  /// counting down.
  ///
  /// Nothing kills here and nothing is timed tightly: the walk from the key to
  /// the door is a little over two seconds out of four and a half, so a beat
  /// spent thinking costs nothing. What costs is misreading what the key is.
  ///
  /// The wall past the key is not decoration. A crossing flips, so crossing it
  /// twice flips it back — walk over the key, past it, and turn round, and you
  /// have shut the door you just opened without touching anything else. The
  /// wall turns you round while you are still standing on it, so a trip to the
  /// key is always exactly one flip. (It is 320 tall: a body standing on a
  /// shadow reaches 232, so it cannot be climbed either.)
  static final Level closeWhatYouOpened = Level(
    id: 'close-what-you-opened',
    name: 'اللي بتفتحه بتقفله',
    teaches: 'المفتاح مش زرار. بيفتح دلوقتي — وماضيك جاي يقفله.',
    delaySeconds: 4.5,
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-700, 700),
      // The end wall, right against the key.
      const Rect.fromLTRB(-360, 300, -320, 620),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-320, 608, -200, 620), flips: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(160, 360, 186, 620)),
    ],
    goal: const Rect.fromLTRB(260, 548, 340, 620),
  );

  /// **Use eight: the light.** The shadow needs dark to be a thing at all.
  ///
  /// The way out is on a shelf a hundred and ninety above the floor, and a
  /// jump lifts a hundred and thirty-six: the only ladder in this game is your
  /// own body, standing where you left it. The obvious place to leave it is
  /// hard against the shelf's left edge, where the climb is shortest — and
  /// that is exactly where the light falls. Stand there, walk away, come back,
  /// and your shadow is standing in the beam looking like a ghost of itself,
  /// and you go straight through it.
  ///
  /// So the level is one question with one answer: where can a body be left
  /// that is both out of the light and still close enough to jump from. The
  /// beam's left edge is at -20 and the far end of what a jump can cross is
  /// about -63, which is a stretch of dark a body and a half wide, and it is
  /// exactly the stretch you end up in by walking out of the light and no
  /// further. Nothing here is timed and nothing kills: stand in the wrong
  /// place and you fall through yourself onto the floor, which is the lesson
  /// arriving in the only way it can.
  ///
  /// The column on the right is not scenery. Without it the shelf could be
  /// climbed from its far end instead, in the dark, and the light would be a
  /// thing to walk around rather than a thing to understand. It is four
  /// hundred and twenty tall, so a body standing on a shadow — 232 — cannot
  /// top it either.
  static final Level yourShadowIsNotHere = Level(
    id: 'your-shadow-is-not-here',
    name: 'ضلّك مش هنا',
    teaches: 'في النور مفيش ظل. سيب جسمك في الضلمة.',
    delaySeconds: 4,
    spawnX: 300,
    floorTop: _floor,
    blocks: [
      _ground(-700, 700),
      // Out of reach from the floor, reachable from your own head.
      const Rect.fromLTRB(60, 430, 560, 470),
      // The wall that closes the far end, so the shelf has one way up.
      const Rect.fromLTRB(560, 200, 620, 620),
    ],
    // Hard against the shelf's left edge: the shortest climb in the level, and
    // the one place a body left behind is worth nothing.
    lights: const [Rect.fromLTRB(-20, 200, 60, 620)],
    goal: const Rect.fromLTRB(380, 358, 460, 430),
  );

  /// In teaching order.
  static final List<Level> campaign = [
    pressItEarly,
    standOnYourself,
    notTheSameWayBack,
    takeItWithYou,
    bothAtOnce,
    goInLow,
    holdYourOwnDoor,
    closeWhatYouOpened,
    yourShadowIsNotHere,
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
