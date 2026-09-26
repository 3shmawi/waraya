import 'dart:ui';

import '../lab/lab_scene.dart';
import 'level.dart';
import 'playthrough.dart';

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

  /// How far above its own floor a body standing on a shadow can get its feet:
  /// the body's height plus a jump, 96 + 136.
  ///
  /// This one number is where every "can this be climbed" bug in the game has
  /// come from, twice now. It broke every door in the campaign once
  /// (`minDoorHeight`), and then it broke levels six and seven from the side —
  /// a shadow is a ladder **wherever there is room to stand**, so any open
  /// ground within about [ladderCarry] of a surface no higher than this is a
  /// second way onto that surface. Ask it of every surface in a level, from
  /// every patch of open floor, not only of the thing being added.
  static const double ladderReach = 232;

  /// How far a jump off a shadow's head carries sideways while still above a
  /// surface 64 below the head. The reach of that second way up.
  static const double ladderCarry = 145;

  /// [ladderReach] in a level where only a ducked body is solid: a crouched
  /// figure is `crouchHeightFactor` of a standing one, so the step is 69 and
  /// the reach is 69 + 136.
  ///
  /// Twenty-seven short of the standing number, which sounds like nothing and
  /// is the whole margin: a shelf drawn at 190 is still climbable and one
  /// drawn at 210 is not. Any level using [ShadowSolidity.crouched] is
  /// measured against this and not against [ladderReach].
  static const double crouchedLadderReach = 205;

  /// The same rule for a level with two shadows, where the staircase has one
  /// more step in it.
  ///
  /// Two shadows can be stacked. Stand on the near one's head and you are
  /// recorded standing at 96; four seconds later the far one arrives *there*,
  /// so the near one on the floor is a step up to the far one in the air, and
  /// a jump from that second head clears 96 + 96 + 136 = 328 above the floor.
  /// Nobody would find that by accident and somebody would find it on
  /// purpose, which is the same thing that happened to every door in the game
  /// the first time round.
  static const double minDoorHeightTwoShadows = 360;

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
  /// standing on it two and a half seconds ago. Flat ground, no jumping: the only new
  /// thing is the idea.
  static final Level pressItEarly = Level(
    id: 'press-it-early',
    solution: const [
      Move.right(1.8), // out to the plate, the wrong way from the door
      Move(1.2), // stand on it
      Move.left(4.8), // all the way to the door, and wait there
    ],
    wrongIdeas: const [
      // Hold one arrow and walk at the door. The first draft of this level
      // could be finished exactly like this, because the plate sat on the way
      // — you crossed it, and two and a half seconds later so did your
      // shadow.
      [Move.left(8)],
    ],
    name: 'قبل ما تحتاجه',
    teaches: 'الزرار محتاج حد يقف عليه. مفيش حد غيرك.',
    delaySeconds: 2.5,
    spawnX: 0,
    floorTop: _floor,
    blocks: [_ground(-700, 700)],
    // The plate is the opposite way from the door on purpose. Put it between
    // the player and the door and the level solves itself: you cross it on
    // your way past, and two and a half seconds later your shadow crosses it
    // too and
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
    solution: const [
      Move.left(3.3), // out to the mark, under the ledge
      Move(2.5, crouch: true), // duck there: this is the step you are leaving
      Move.right(0.9), // get out of your own way
      Move(0.15), // it is already standing there
      Move.left(0.4), // run at it
      Move.left(0.55, jump: true), // up onto its head
      Move.left(0.6, jump: true), // and off the head onto the ledge
      Move.left(1.5), // along to the way out
    ],
    wrongIdeas: const [
      // Run at the ledge and jump at it, twice, on your own legs.
      [
        Move.left(3),
        Move.left(0.8, jump: true),
        Move.left(2),
        Move.left(0.8, jump: true),
        Move.left(2),
      ],
    ],
    name: 'اوقف على نفسك',
    teaches: 'انت الوحيد اللي ممكن تبقى السلّمة.',
    delaySeconds: 2.5,
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
    solution: const [
      Move.left(1.9), // into the corridor, onto the plate
      Move(1.0), // hold it down
      Move.left(0.5), // on to the dead end
      Move.left(0.5, jump: true), // up onto the step
      Move(0.25),
      Move.right(0.3), // a run at the gap
      Move.right(0.75, jump: true), // across onto the upper lane
      Move.right(1.7), // home, above your own footprints
      Move.right(2.5), // down off the end and through the door
    ],
    wrongIdeas: const [
      // Straight back out the way you came in, and wait by the door — which
      // is standing in the corridor your own past is walking up.
      [Move.left(1.9), Move(1.0), Move.right(2.5), Move(4)],
    ],
    name: 'مش نفس السكة',
    teaches: 'ظلك جاي في نفس السكة. دوّر على سكة تانية.',
    // Four seconds, and the layout does the forcing rather than the number.
    // The player starts beside the door, so the shadow's first steps are
    // through the one spot you would otherwise stand and wait in: leaving the
    // corridor early and loitering by the door is the obvious plan, and it is
    // the plan that walks you into yourself.
    delaySeconds: 4,
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
    // window arrives exactly four seconds later, and the lane you come home
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
    solution: const [
      Move.right(1.9), // out to the plate, away from the drop
      Move(2.5), // stand on it long enough to be worth something
      Move.left(2.9), // back along the shelf
      Move.left(0.7), // off the end, committing
      Move.left(1.0), // to the door at the bottom
      Move.left(1.2), // through it, once your past opens it
    ],
    wrongIdeas: const [
      // Off the shelf without leaving anything behind: a hole, a shut door,
      // and only R.
      [Move.left(9)],
    ],
    name: 'خُد قرارك واقفز',
    teaches: 'اللي تحت مفيش رجوع منه. اتأكد إنك سيبت حاجة وراك.',
    delaySeconds: 3.5,
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
  /// you need your past for, from the same two seconds of history.
  ///
  /// Nothing new is introduced. The only new thing is that both setups are in
  /// flight at the same time, and the order they were laid down in is the
  /// order they come back in.
  static final Level bothAtOnce = Level(
    id: 'both-at-once',
    solution: const [
      Move.left(1.1), // back to the plate
      Move(1.2), // hold it
      Move.right(2.0), // to the door, and wait at it
      Move.right(1.2), // through, once the shadow takes over the plate
      Move.right(0.6), // out to the mark, short of the ledge
      Move(2.0, crouch: true), // duck there: this is the second job
      Move.left(0.9), // out of your own way
      Move(0.1),
      Move.right(0.45), // run at what you left behind
      Move.right(0.55, jump: true), // onto its head
      Move.right(0.6, jump: true), // and off the head onto the ledge
      Move.right(1.5), // along to the way out
    ],
    wrongIdeas: const [
      // Straight at the door, having pressed nothing.
      [Move.right(8)],
    ],
    name: 'الاتنين مع بعض',
    teaches: 'ظل واحد، مهمتين. الترتيب اللي عملتهم بيه هو اللي راجع بيه.',
    delaySeconds: 2.2,
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
  /// Nothing here is a stopwatch. The shadow waits in the gap for exactly as
  /// long as you waited there, so a player who wants more room simply waits
  /// longer — the level is made harder by having more to work out, not by
  /// giving less time to do it in.
  ///
  /// **What this level is about, now that a ducked body is the only solid
  /// one.** Under the roof you have no choice: it is eighty above the floor,
  /// so you crouch the whole way, and crouching leaves a step behind you
  /// every inch of it. Which sounds like it should hand you the level — and
  /// does not, because of the other number. A body standing on a step in this
  /// corridor has its head at 455 and the roof's underside is at 540: it does
  /// not fit. The whole trail under the roof is a staircase you cannot use.
  ///
  /// The gap between the two roof pieces is the only place with headroom
  /// over it, so it is the only place a step is worth anything — which is
  /// the same sentence the level always said, arrived at from the other side.
  /// It used to be *the one place you may stand up*; it is now *the one place
  /// standing on something fits*.
  ///
  /// It is also the level that shows where the rule stops helping. "A walk
  /// leaves no ladder" is only true where ducking is a choice. Under a roof
  /// that forces it, the ladder is back — and what has to stop it is
  /// geometry, as it is here.
  static final Level goInLow = Level(
    id: 'go-in-low',
    solution: const [
      Move.left(0.5), // out to the mouth of the roof
      Move.left(2.9, crouch: true), // under it, bent over, to the gap
      Move(2.0, crouch: true), // duck here: the one place a step is any use
      Move.left(1.2, crouch: true), // back under the roof, out of your own way
      Move.right(1.2, crouch: true), // and straight back: it is standing there
      Move(0.1),
      Move.right(0.5, jump: true), // up onto your own head
      Move.right(0.6, jump: true), // and off it onto the roof
      Move.right(1.2), // along to the way out
    ],
    wrongIdeas: const [
      // Walk in standing, and the roof says no.
      [
        Move.left(0.5),
        Move.left(3.5),
        Move(1.0),
        Move.right(0.6, jump: true),
        Move.right(0.6, jump: true),
        Move(2.0),
      ],
      // Or jump at the way out from underneath it, which does not reach.
      [
        Move.left(0.9),
        Move(0.3),
        Move(0.6, jump: true),
        Move(0.6, jump: true),
        Move.left(0.4, crouch: true),
        Move(0.6, jump: true),
        Move(2.0),
      ],
      // Use the staircase the corridor hands you. Crouching under the roof
      // is not optional, so the trail down there is solid the whole way —
      // and useless, because a body standing on it has its head in the roof.
      // Come back to the middle of the corridor, climb, and there is nowhere
      // to be. This is the one the geometry has to stop, not the rule.
      [
        Move.left(0.5),
        Move.left(2.0, crouch: true),
        Move(1.2, crouch: true),
        Move.left(0.9, crouch: true),
        Move(1.4, crouch: true),
        Move.right(0.5, crouch: true),
        Move.right(0.6, jump: true),
        Move.right(0.6, jump: true),
        Move(1.5),
      ],
      // Or — reported from playing, and it used to work — never crouch at
      // all: leave a body standing out in the open at the spawn and climb
      // onto the roof from the wrong end. The lip is what stops it.
      [
        Move(2.5),
        Move.right(0.7),
        Move(1.2),
        Move.left(0.12),
        Move.left(0.55, jump: true),
        Move(0.1),
        Move.left(0.6, jump: true),
        Move.left(1.4),
      ],
    ],
    name: 'خُش واطي',
    teaches: 'تحت السقف مفيش وقوف على حاجة. المكان الوحيد هو الفتحة.',
    delaySeconds: 3,
    spawnX: 330,
    floorTop: _floor,
    blocks: [
      _ground(-600, 600),
      // The roof, in two pieces. Its underside is eighty above the floor —
      // crouched fits, standing does not.
      //
      // The left piece is **thick**: its top is 260 above the floor, and a
      // body standing on a shadow reaches 232, so it cannot be climbed at
      // all. It is a ceiling, not a place.
      const Rect.fromLTRB(-420, 360, -180, 540),
      // The right piece is the one the way out sits on, and its top is a
      // hundred and sixty above the floor: out of reach of a jump from the
      // floor, in reach of a jump from your own head.
      const Rect.fromLTRB(0, 460, 220, 540),
      // And the lip on its right edge, which is the whole reason this level
      // still asks a question.
      //
      // Reported from playing: "levels six and seven are the same, I went
      // right instead of left". They were right, and it was worse than that.
      // The spawn is out in the open past the end of the roof, so a body left
      // standing **there** was a step up onto the roof from the wrong side —
      // the level finished in 5.7 seconds without the player ever crouching.
      // A shadow is a ladder wherever there is room to stand, which makes
      // every open patch next to a climbable surface a second front door.
      // The lip is 160 tall, so a jump off a shadow (232) cannot clear it.
      const Rect.fromLTRB(190, 300, 220, 460),
    ],
    // The gap between those two, -180 to 0, is the only headroom in the level.
    // A hundred and eighty wide: two forty-four-wide bodies, the one you leave
    // and the one that climbs it, with room to take a step.
    //
    // The way out sits short of the lip, so the walk along the roof ends at it
    // rather than at a wall.
    goal: const Rect.fromLTRB(100, 388, 180, 460),
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
    solution: const [
      Move.left(2.1), // out to the plate, the wrong way from everything
      // Ducked, and the plate does not care: a body on it holds the door
      // whatever shape it is in. Ducked is only about what you can climb.
      Move(3.0, crouch: true), // hold it. this is how long the door is open
      Move.left(0.6), // on past it, into the open, out of your own way
      Move(0.6), // and wait there for yourself to arrive
      Move.right(0.75, jump: true), // a running jump onto your own head
      Move(0.2),
      Move.right(0.75, jump: true), // off it onto the shelf
      Move.right(1.6), // along the shelf, through the door you are holding
      Move.right(1.5), // to the way out
    ],
    wrongIdeas: const [
      // The same run with a one-second press: up onto the shelf, and a shut
      // door at the end of it. The press is the timer.
      [
        Move.left(2.1),
        Move(1.0, crouch: true),
        Move.left(0.6),
        Move(2.6),
        Move.right(0.75, jump: true),
        Move(0.2),
        Move.right(0.75, jump: true),
        Move.right(1.6),
        Move.right(1.5),
      ],
      // And the one that used to finish the level without touching it:
      // out past the end of the shelf, leave a body on the open floor, and
      // climb on from the right, behind the door. The wall is what stops it.
      [
        Move.right(1.0),
        Move(2.5),
        Move.right(0.7),
        Move(2.2),
        Move.left(0.12),
        Move.left(0.55, jump: true),
        Move(0.1),
        Move.left(0.6, jump: true),
        Move.left(1.0),
      ],
    ],
    name: 'واقف على اللي فاتحلك',
    teaches: 'قد ما وقفت على الزرار، قد ما الباب هيفضل مفتوح.',
    delaySeconds: 4,
    spawnX: 400,
    floorTop: _floor,
    blocks: [
      _ground(-600, 600),
      // Its top is a hundred and ninety above the floor and a jump lifts a
      // hundred and thirty, so the floor cannot reach it from anywhere along
      // its length.
      const Rect.fromLTRB(60, 430, 520, 470),
      // The wall on its far end, and the level does not exist without it.
      //
      // Reported from playing: the shelf could be climbed from the **right**,
      // where the open floor runs past the end of it. A body left standing out
      // there is a step onto the shelf on the wrong side of the door — the
      // level finished in 7.7 seconds with the door never once open and the
      // plate never once pressed, which is the entire level skipped. A shadow
      // is a ladder wherever there is room to stand, so a shelf with open
      // ground off the end of it has two ways up.
      //
      // As tall as the door, and for the same reason: 260 above the shelf is
      // past anything a jump off a shadow can reach.
      const Rect.fromLTRB(520, 170, 560, 470),
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
  /// arrives — and it flips for the body walking your path three and a half
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
  /// the door is a little over two seconds out of three and a half, so a beat
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
    solution: const [
      Move.left(1.7), // out to the key — the opposite way from the door
      Move.right(2.8), // straight back, and through, before your past arrives
    ],
    wrongIdeas: const [
      // The habit six levels of plates have drilled: stand on it and wait for
      // your past to come and hold it down. On a key that arrival is the flip
      // that shuts the door, and then it is shut for good.
      [Move.left(1.7), Move(5.2), Move.right(3.2)],
      // Or hold one arrow at the way out, with the key untouched.
      [Move.right(8)],
    ],
    name: 'اللي بتفتحه بتقفله',
    teaches: 'المفتاح مش زرار. بيفتح دلوقتي — وماضيك جاي يقفله.',
    delaySeconds: 3.5,
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
    solution: const [
      Move.left(1.58), // out to the mark, past the lit ground
      Move(2.2, crouch: true), // duck there, leaving something to climb
      Move.left(0.6), // out of your own way
      Move(1.3), // and wait for yourself to arrive
      Move.right(0.12), // a short run — any longer and you sail over it
      Move.right(0.55, jump: true), // onto it
      Move(0.1),
      Move.right(0.6, jump: true), // off it onto the shelf
      Move.right(1.6), // along to the way out
    ],
    wrongIdeas: const [
      // Leave the body in the obvious place, hard against the shelf, which is
      // the lit place. You come back and go straight through it.
      [
        Move.left(1.3),
        Move(2.2, crouch: true),
        Move.left(0.6),
        Move(1.3),
        Move.right(0.12),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.6, jump: true),
        Move.right(1.6),
      ],
    ],
    name: 'ضلّك مش هنا',
    teaches: 'في النور مفيش ظل. سيب جسمك في الضلمة.',
    delaySeconds: 3,
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

  /// **Use nine: two pasts.** The gate has two locks and you are one person.
  ///
  /// This is not a new rule. It is the rule twice, and what the second copy
  /// buys is the one thing a single shadow cannot do at any delay at all: be
  /// in two places at the same moment. One shadow covers exactly one spot —
  /// the one you were standing in D ago — so a gate that wants both of its
  /// plates held *at once* is a gate one shadow can never open, however long
  /// you stand on either.
  ///
  /// Two shadows cover two spots, and the distance between them is fixed at
  /// four seconds. So the puzzle is not where to stand but **how far apart in
  /// time** to stand: press the far plate, walk to the near one, and the gap
  /// between the two things you did has to fit inside the gap between your two
  /// pasts. The walk between the plates is about two and a half seconds, which
  /// leaves roughly a second and a half of both-at-once at the gate — and it
  /// is the player who widens it, by standing longer on each, exactly as in
  /// every other level here.
  ///
  /// The two doors touch, and that is load-bearing. The first draft left
  /// thirty units between them, which is less than a body — and a body still
  /// fitted, because fitting is about the gap plus whichever door is open.
  /// The player could walk through the near one while it was open, stand in
  /// the middle, and wait for the far one: two doors taken one at a time, and
  /// no reason left to own two pasts. With no gap at all there is nowhere to
  /// wait, and the only way through is both at once.
  ///
  /// They are also 360 tall rather than 250: two shadows stack, and a body on
  /// top of a body on top of the floor reaches 328. See
  /// [minDoorHeightTwoShadows].
  static final Level twoNotOne = Level(
    id: 'two-not-one',
    solution: const [
      Move.left(3.1), // out to the far plate, past the near one
      Move(1.8), // stand on it: this is how wide the window will be
      Move.right(2.5), // back to the near plate
      Move(1.8), // and stand on that one
      Move.right(1.4), // up to the gate, both of them already standing
      Move.right(1.8), // and straight through, before the near one moves
    ],
    wrongIdeas: const [
      // Step off the far plate and take your time about the walk. Your pasts
      // are four seconds apart whatever you do, so the far one has been and
      // gone before the near one arrives.
      [
        Move.left(3.1),
        Move(1.8),
        Move.right(0.8),
        Move(2.5),
        Move.right(1.7),
        Move(1.8),
        Move.right(1.3),
        Move(1.6),
        Move.right(1.6),
      ],
      // Or press the near plate alone, which opens half a gate.
      [
        Move.left(0.8),
        Move(2.0),
        Move.right(1.4),
        Move(4.0),
        Move.right(1.6),
      ],
    ],
    name: 'اتنين مش واحد',
    teaches: 'البوابة عايزة الزرارين مع بعض، وانت واحد. بس ماضيك اتنين.',
    delays: const [2, 6],
    spawnX: 120,
    floorTop: _floor,
    blocks: [_ground(-900, 700)],
    plates: const [
      // The far one, which the six-second shadow comes back for.
      PlateSpec(area: Rect.fromLTRB(-560, 608, -460, 620), opens: 'far'),
      // The near one, which the two-second shadow comes back for.
      PlateSpec(area: Rect.fromLTRB(-60, 608, 40, 620), opens: 'near'),
    ],
    doors: const [
      DoorSpec(id: 'near', closed: Rect.fromLTRB(240, 260, 266, 620)),
      DoorSpec(id: 'far', closed: Rect.fromLTRB(266, 260, 292, 620)),
    ],
    goal: const Rect.fromLTRB(400, 548, 480, 620),
  );

  /// **Phase 7, one.** Both halves of your past, in one pass.
  ///
  /// This level is where `ShadowSolidity.crouched` was worked out, back when
  /// it was one level's opt-in rather than the game's rule. What it proved is
  /// still the thing it teaches: your past is two different things depending
  /// on what it was doing, and you need both of them here.
  ///
  /// The **standing** body is as real as it ever was — it puts its weight on
  /// the plate and holds the gate open for you. It is just not a floor. The
  /// **ducked** body is the floor, and it is the only one, which makes the
  /// shelf a place you can only reach by having decided to duck.
  ///
  /// So: go the wrong way, stand on the plate, come back through the gate
  /// your own weight is holding, and duck once in the right place. Walk the
  /// whole thing perfectly and never duck and you end up under the shelf with
  /// nothing to climb — the first recorded wrong idea, and the run that would
  /// have won this game before the rule changed.
  static final Level notEveryStep = Level(
    id: 'not-every-step',
    solution: const [
      Move.left(0.95), // the wrong way first, as ever: out to the plate
      Move(1.2), // hold it, so your past holds the door
      Move.right(2.1), // back to the gate, arriving as it opens
      Move.right(0.85), // through, and on to the foot of the shelf
      Move(0.1),
      Move(1.0, crouch: true), // and duck. this is the only step you get
      Move.left(0.6), // back out of your own way, still this side of the gate
      Move(0.8), // wait for the thing you left
      Move.right(0.55), // run at it
      Move.right(0.6, jump: true), // onto its head
      Move.right(0.7, jump: true), // and off the head onto the shelf
      Move.right(1.2), // along to the way out
    ],
    wrongIdeas: const [
      // The run that would have won any other level in the game: do
      // everything right and never duck. The plate is pressed, the door
      // opens, you walk through and stand under the shelf on a trail that is
      // not there.
      [
        Move.left(0.95),
        Move(1.2),
        Move.right(2.1),
        Move.right(0.85),
        Move(0.1),
        Move(1.0), // the one difference: upright
        Move.left(0.6),
        Move(0.8),
        Move.right(0.55),
        Move.right(0.6, jump: true),
        Move.right(0.7, jump: true),
        Move.right(1.2),
      ],
      // Touch the plate and run for the gate on your own press. Reported
      // from playing, and it used to work: the grace on the door outlasted
      // the walk, so the gate was open when you arrived and your past was
      // still three seconds from existing. The whole first half of the level
      // was scenery.
      [
        Move.left(0.95),
        Move(0.1),
        Move.right(2.2),
        Move(0.6, crouch: true),
        Move.left(0.7),
        Move(0.8),
        Move.right(0.55),
        Move.right(0.6, jump: true),
        Move.right(0.7, jump: true),
        Move.right(1.2),
      ],
      // Or duck in the obvious place — on the plate, where you are standing
      // still anyway — and get a perfectly good step on the wrong side of a
      // door you then have to walk through.
      [
        Move.left(0.95),
        Move(0.2),
        Move(1.0, crouch: true),
        Move.right(2.1),
        Move.right(0.55),
        Move(2.0),
        Move.right(0.6, jump: true),
        Move.right(0.7, jump: true),
        Move.right(2.0),
      ],
    ],
    name: 'مش كل خطوة سلّمة',
    teaches: 'الواقف بيمسك الباب، والواطي بس هو اللي بتقف عليه.',
    delaySeconds: 3,
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-600, 1000),
      // The shelf with the way out on it. A hundred and ninety above the
      // floor: past a jump (136), inside a duck's staircase (205) by fifteen.
      // See [crouchedLadderReach] — this number is the reason it exists.
      //
      // It starts at 480 rather than hard against the gate, and the gap is
      // the level working. You duck just short of it, step off your own way,
      // and come back at a run — and all of that has to happen on **this**
      // side of the gate. Drawn any tighter, the only room to back up into is
      // through the doorway, and a door that has done its job is shut by
      // then: you end up on the wrong side of it watching the step you left.
      const Rect.fromLTRB(480, 430, 880, 470),
      // The wall closing the shelf's far end, and the level does not exist
      // without it. Open floor runs past 880, and open floor beside a surface
      // is a way onto that surface — duck out there and the shelf has a back
      // door. 260 above the shelf, which nothing can top.
      const Rect.fromLTRB(880, 170, 920, 430),
    ],
    // The wrong way from everything, which is the first thing this game ever
    // taught and still the spine of the level: you cannot open the gate and
    // be at the gate.
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-260, 608, -160, 620), opens: 'gate'),
    ],
    // A second and a bit of grace, and the number is load-bearing — this is
    // the whole gate half of the level.
    //
    // Reported from playing: "the door opens the moment I stand on the plate
    // and closes by itself." It did, and that was the level broken. The walk
    // from the plate to the gate is 410 units, which is 1.86 seconds, so any
    // grace longer than that means **your own press carries you through** and
    // the shadow never has to arrive at all. It was six. You could touch the
    // plate, run, and be through the gate a second before your past even
    // existed.
    //
    // 1.2 is under the walk, so the door your own weight opened has shut
    // again before you get there. And it is not a stopwatch on the other
    // side: your past holds the plate for as long as you held it, plus this,
    // which is a window of about two and a half seconds to walk through a
    // gate you are already standing at.
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(250, 360, 276, 620),
        lingerSeconds: 1.2,
      ),
    ],
    goal: const Rect.fromLTRB(660, 358, 740, 430),
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
    twoNotOne,
    notEveryStep,
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
