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
    teaches: 'دوس الزرار وكمّل. ماضيك هيفتحلك الباب.',
    nameEn: 'Before You Need It',
    teachesEn:
        'Step on the button and keep going. Your past will open the door.',
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
    teaches: 'وطّي جنب الحيطة وابعد. ماضيك هيبقى سلّمة.',
    nameEn: 'Stand on Yourself',
    teachesEn: 'Crouch by the wall, then step away. Your past becomes a step.',
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
      // The miserly run, and it used to finish this level in four seconds.
      // Touch the plate on the way past, turn round, and walk out through a
      // door your own weight opened — the grace on it outlasted the walk by
      // four and a half seconds, so you were through before the shadow this
      // level is entirely about had come into existence. Now the door shuts
      // as you step off the plate, and the corridor kills you on the way
      // back, which is the lesson arriving on time.
      [Move.left(1.7), Move.right(3.0)],
    ],
    name: 'مش نفس السكة',
    teaches: 'ماضيك بيقتل لو لمسك. ارجع من سكة تانية.',
    nameEn: 'Not the Same Way Back',
    teachesEn: 'Your past kills on touch. Come back another way.',
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
    teaches: 'اقف على الزرار الأول، وبعدين انزل. مفيش طلوع.',
    nameEn: 'Make Your Choice and Jump',
    teachesEn: 'Stand on the button first, then drop. There is no way back up.',
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
    teaches: 'ماضيك هيعمل شغلانتين، بنفس الترتيب اللي عملتهم بيه.',
    nameEn: 'Both at Once',
    teachesEn: 'Your past does two jobs, in the order you did them.',
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
    teaches: 'وطّي تحت السقف. الفتحة هي المكان الوحيد اللي تطلع منه.',
    nameEn: 'Go In Low',
    teachesEn: 'Crouch under the roof. The gap is the only way up.',
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
    teaches: 'قد ما تقف على الزرار، قد ما ماضيك يمسك الباب.',
    nameEn: 'Standing on What Holds It',
    teachesEn:
        'However long you stand on the button, your past holds the door that long.',
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
    teaches: 'المفتاح بيفتح دلوقتي، وماضيك هيقفله. اسبقه.',
    nameEn: 'What You Open, You Close',
    teachesEn:
        'The switch opens now, and your past will close it. Beat it there.',
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
    teaches: 'في النور ماضيك مش موجود. خلّيه في الضلمة.',
    nameEn: 'Your Shadow Isn\'t Here',
    teachesEn: 'In the light your past is not there. Keep it in the dark.',
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
    lights: const [LightSpec(Rect.fromLTRB(-20, 200, 60, 620))],
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
      [Move.left(0.8), Move(2.0), Move.right(1.4), Move(4.0), Move.right(1.6)],
    ],
    name: 'اتنين مش واحد',
    teaches: 'الباب عايز الزرارين مع بعض. انت واحد، وماضيك اتنين.',
    nameEn: 'Two, Not One',
    teachesEn:
        'The gate needs both buttons at once. You are one; your past is two.',
    delays: const [2, 6],
    spawnX: 120,
    floorTop: _floor,
    blocks: [
      _ground(-900, 700),
      // The wall that makes the far plate a place rather than a thing on the
      // way, and the level does not hold without it.
      //
      // Found by sweeping the campaign for the cheapest run that finishes:
      // walk left past both plates, turn round, walk right. Out and back
      // crosses each plate **twice**, which is four presses from one walk,
      // and with the turn as a free dial two of them can always be slid four
      // seconds apart — the exact gap between the two shadows. It finished in
      // 9.4 seconds, faster than the intended solution, without the player
      // ever working out what the gap was for.
      //
      // A dead end collapses the two crossings into one press whose *length*
      // you choose, which is the thing the level is actually about. Its face
      // is at -560 so a body pushed up against it is standing on the plate.
      const Rect.fromLTRB(-600, 260, -560, 620),
    ],
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
    teaches: 'ماضيك الواقف بيدوس الزرار. الواطي بس هو اللي تقف عليه.',
    nameEn: 'Not Every Step Is a Stair',
    teachesEn:
        'Your standing past presses buttons. Only a crouched one holds you up.',
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
    // A second and a bit of grace, which is your past's and not yours.
    //
    // Reported from playing: "the door opens the moment I stand on the plate
    // and closes by itself." It did, and that was the level broken — the
    // grace was six seconds and the walk from the plate to the gate is 1.86,
    // so your own weight carried you through and the shadow never had to
    // arrive. That is fixed in `Door.hold` now rather than here: a door held
    // open by nothing but the body you are standing in shuts the instant you
    // step off it, in every level.
    //
    // This number is what is left of the question, and it is the forgiving
    // half: your past holds the plate for as long as you held it, plus this
    // — about two and a half seconds to walk through a gate you are already
    // standing at. It stays under the walk as well, which costs nothing and
    // means the level would still be a level if the rule above were ever
    // argued with.
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(250, 360, 276, 620),
        lingerSeconds: 1.2,
      ),
    ],
    goal: const Rect.fromLTRB(660, 358, 740, 430),
  );

  /// **Phase 7, one.** Two pasts, one on top of the other.
  ///
  /// Two shadows are usually read as *two places at once* — that is what
  /// `twoNotOne` teaches. This level is the other thing they are: **two
  /// steps**. One ducked body is sixty-nine tall and a jump off it reaches
  /// two hundred and five. Duck on top of a ducked body, and later your past
  /// is floating sixty-nine up, sitting on a past that is no longer under it
  /// — and if the other shadow is still ducked on the floor underneath it at
  /// that moment, the two of them are a stair a hundred and thirty-eight tall,
  /// and the top of the climb is two hundred and seventy-four.
  ///
  /// The first shelf is the one step every level since the second has
  /// taught, as a reminder with both shadows present. The roof is fifty
  /// beyond one step and twenty-four inside two.
  ///
  /// **Why one shadow cannot do it alone,** which is the whole reason the
  /// level needs two, and which rests on two units. Your own past floating
  /// sixty-nine up has its top a hundred and thirty-eight above the floor,
  /// and a jump — measured, not the textbook number — lifts the feet a
  /// hundred and thirty. Even with the six units of landing grace the body
  /// is two short. So the bottom step has to be *the other* past, still
  /// ducked where you ducked first, and the long first duck is what keeps it
  /// there: the far shadow holds the floor for as long as you held it, and it
  /// has to outlast the near one arriving on top. `hard_levels_test.dart`
  /// pins the two units.
  static final Level stairOfYourself = Level(
    id: 'stair-of-yourself',
    solution: const [
      Move.right(1.05), // to the foot of the step
      Move(1.2, crouch: true), // duck: the first step
      Move(0.3),
      Move(0.9), // wait for it
      Move(0.5, jump: true), // straight up onto it
      Move.right(0.9, jump: true), // and off it onto the shelf
      Move.right(1.45), // along the shelf to the foot of the wall
      Move(3.5, crouch: true), // duck, long: this is the bottom step
      Move(1.6), // stand up and wait for the far one to arrive under you
      Move(0.5, jump: true), // up onto it
      Move(1.0, crouch: true), // and duck on top of it: the second step
      Move(1.0), // stand, and wait for the near one to arrive on top
      Move(0.7, jump: true), // up onto that
      Move.right(0.9, jump: true), // and off the top onto the roof
      Move.right(1.5), // to the way out
    ],
    wrongIdeas: const [
      // One step, which is all the first shelf needed. Duck at the foot of
      // the wall, climb the first body that arrives, and jump: seventy short.
      [
        Move.right(1.05),
        Move(1.2, crouch: true),
        Move(1.2),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.45),
        Move(1.2, crouch: true),
        Move(1.0),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
      // One past stacked on itself. Duck, climb it, duck on top — and by the
      // time that comes back floating in the air, the body that was under it
      // has walked off. The floating one is a hundred and thirty-eight up and
      // a jump is a hundred and thirty: two short, with nothing to stand on.
      [
        Move.right(1.05),
        Move(1.2, crouch: true),
        Move(1.2),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.45),
        Move(1.0, crouch: true),
        Move(1.1),
        Move(0.5, jump: true),
        Move(0.4, crouch: true),
        Move(1.6),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
    ],
    name: 'سلّم من نفسك',
    teaches: 'ماضيك اتنين. وطّي، والاتنين يبقوا درجتين.',
    nameEn: 'A Stair of Yourself',
    teachesEn: 'Your past is two. Crouch, and they become two steps.',
    // Three seconds apart. The gap is what the bottom step has to last
    // through: the far one arrives under you three seconds after the near
    // one, and has to still be there when the near one comes back on top.
    delays: const [2, 5],
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-400, 1300),
      // One step up: a hundred and ninety, inside a ducked body's two
      // hundred and five.
      const Rect.fromLTRB(300, 430, 1300, 620),
      // Two steps up: two hundred and fifty above the shelf, past one body's
      // reach by forty-five and inside two bodies' by twenty-four. Nothing
      // anywhere in the level is higher than the shelf except this.
      const Rect.fromLTRB(760, 180, 1300, 430),
    ],
    goal: const Rect.fromLTRB(1000, 108, 1080, 180),
  );

  /// **Phase 7.** What your past opens, your past shuts — the order in
  /// `Door.hold`, played as a level.
  ///
  /// Three rules decide a door, in order: an inverted plate under a body
  /// shuts it whatever else is true; otherwise a plate held or a key thrown
  /// opens it; otherwise it drifts shut after its grace. Every level so far
  /// has used one line of that at a time. This one walks you down all three.
  ///
  /// The first room is the key, as a reminder: touch it and leave, because
  /// your past is coming to flip it back. The second room is the other two
  /// lines at once. A plate on a balcony holds the far gate open, with three
  /// seconds of grace — plenty for the long walk. But the corridor to that
  /// gate has an inverted plate on its floor, and it beats the plate *and*
  /// the grace. You can walk over it all you like; it is your past walking
  /// over it two and a half seconds later that slams the gate, and by then
  /// you are still a walk away. So the thing to do is not to have been
  /// there: jump it.
  ///
  /// The corridor past it is longer than the delay on purpose. If the walk
  /// from the inverted plate to the gate were shorter than two and a half
  /// seconds, you would be through before your past stepped on it, and the
  /// plate would be scenery.
  ///
  /// The balcony is for the reason `threeGatesOnePast` found: a plate on the
  /// floor of the only corridor is a plate everybody crosses, and a crossing
  /// with three seconds of grace behind it opens the gate for free.
  static final Level yourPastShutsIt = Level(
    id: 'your-past-shuts-it',
    solution: const [
      Move.left(0.7), // onto the key, against the wall
      Move.right(1.82), // and straight out through the gate, before you return
      Move.right(1.2), // on past the balcony
      Move.left(0.55, jump: true), // up onto it
      Move.left(0.25),
      Move(1.0), // stand on the plate: this holds the far gate
      Move.right(1.15), // off the balcony
      Move.right(0.55, jump: true), // over the plate on the floor
      Move.right(6), // and the long way to the far gate
    ],
    wrongIdeas: const [
      // Everything right, and walk across the plate on the floor instead of
      // over it. Two and a half seconds later your past walks across it too,
      // and it holds the far gate shut — which beats the plate on the
      // balcony and wipes the grace with it. You arrive at a shut gate.
      [
        Move.left(0.7),
        Move.right(1.82),
        Move.right(1.2),
        Move.left(0.55, jump: true),
        Move.left(0.25),
        Move(1.0),
        Move.right(1.15),
        Move.right(0.55),
        Move.right(6),
      ],
      // Step on the key and wait for your past to come and hold it, the way
      // every plate is held. On a key its arrival is the second flip.
      [
        Move.left(0.7),
        Move(3.0),
        Move.right(1.82),
        Move.right(1.2),
        Move.left(0.55, jump: true),
        Move.left(0.25),
        Move(1.0),
        Move.right(1.15),
        Move.right(0.55, jump: true),
        Move.right(6),
      ],
    ],
    name: 'اللي ماضيك بيفتحه بيقفله',
    teaches: 'الزرار المعكوس بيقفل الباب. متخلّيش ماضيك يقف عليه.',
    nameEn: 'What Your Past Opens, It Shuts',
    teachesEn:
        'The reversed button locks the door. Don\'t let your past stand on it.',
    delaySeconds: 2.5,
    spawnX: -200,
    floorTop: _floor,
    blocks: [
      _ground(-500, 1500),
      // The wall against the key, which turns you round while you are still
      // on it: one trip to the key is exactly one flip.
      const Rect.fromLTRB(-400, 200, -360, 620),
      // The balcony, head height and a hop up. Walking under it presses
      // nothing.
      const Rect.fromLTRB(120, 506, 220, 522),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-360, 608, -260, 620), flips: 'near'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(130, 494, 210, 506), opens: 'far'),
      // Sixty wide rather than a hundred, so a plain running jump clears it.
      // A body counts as on a plate with sixteen units over it, and a jump is
      // above the trigger for about a hundred units of travel — a full-width
      // plate would be a jump that has to be timed, and this is a level about
      // knowing to jump at all.
      PlateSpec(
        area: Rect.fromLTRB(470, 608, 530, 620),
        opens: 'far',
        inverts: true,
      ),
    ],
    doors: const [
      DoorSpec(id: 'near', closed: Rect.fromLTRB(0, 360, 26, 620)),
      DoorSpec(
        id: 'far',
        closed: Rect.fromLTRB(1200, 360, 1226, 620),
        lingerSeconds: 3,
      ),
    ],
    goal: const Rect.fromLTRB(1300, 548, 1380, 620),
  );

  /// **Phase 7.** Light has a bottom.
  ///
  /// `yourShadowIsNotHere` taught *where* the light is. This is the other
  /// half of the same rule, which nothing in the campaign has asked yet: the
  /// light is a rectangle, and a rectangle has a bottom edge. What decides
  /// whether your past exists is whether the beam **touches** it — so how
  /// tall your past was matters as much as where it stood.
  ///
  /// The first room's lamp hangs low over the plate and stops at head
  /// height, forty units short of the floor. A body standing on the plate
  /// has its head in the light and is not there; a ducked body is under the
  /// beam, clear of it, and presses the plate like anything else. So the
  /// habit of eleven levels — stand on the plate — opens nothing, and the
  /// thing to work out is to duck on it. Nothing about the timing changes.
  ///
  /// The second room undoes the answer. Its beam goes all the way to the
  /// floor at the foot of the shelf, which is where a step is shortest to
  /// climb — and ducking there is exactly what the first room just taught to
  /// do about light. It does nothing here: a ducked body is still touched.
  /// The step has to go in the dark, a little further out. Two rooms, the
  /// same move, opposite answers, and the only thing that tells them apart
  /// is looking at where each beam stops. That is the second room being
  /// harder *because* of the first, which is the question this phase asks
  /// of every room.
  static final Level underTheLight = Level(
    id: 'under-the-light',
    solution: const [
      Move.left(1.68), // out to the plate, the wrong way from the gate
      Move(1.5, crouch: true), // duck on it: under the lamp, not in it
      Move.right(3.3), // to the gate, and wait at it
      Move(0.6),
      Move.right(1.1), // through, to the dark short of the second beam
      Move(1.2, crouch: true), // duck there: this beam goes all the way down
      Move.left(0.6), // out of your own way
      Move(1.1),
      Move.right(0.05),
      Move.right(0.55, jump: true), // onto it
      Move(0.1),
      Move.right(0.6, jump: true), // and off it onto the shelf
      Move.right(2.2), // to the way out
    ],
    wrongIdeas: const [
      // Stand on the plate, the way every plate in the game has been stood
      // on. Your past arrives standing, its head in the lamp, and is not
      // there: the gate never moves.
      [
        Move.left(1.68),
        Move(1.5),
        Move.right(3.3),
        Move(3.0),
        Move.right(1.1),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(1.1),
        Move.right(0.05),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.6, jump: true),
        Move.right(2.2),
      ],
      // Carry the first room's answer into the second: duck, and the light
      // will not see you. This beam goes to the floor. Duck hard against the
      // shelf, where the climb is shortest, and you go straight through.
      [
        Move.left(1.68),
        Move(1.5, crouch: true),
        Move.right(3.3),
        Move(0.6),
        Move.right(1.5),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(1.1),
        Move.right(0.05),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.6, jump: true),
        Move.right(2.2),
      ],
    ],
    name: 'النور ليه آخر',
    teaches: 'النور بيمسح ماضيك. شوف بيخلص فين بالظبط.',
    nameEn: 'The Light Ends Somewhere',
    teachesEn: 'The light erases your past. Find exactly where it ends.',
    delaySeconds: 3,
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-700, 1500),
      // A hundred and ninety up: out of a jump's reach, inside a step's.
      const Rect.fromLTRB(700, 430, 1400, 620),
      // Closing the shelf's far end, so it has one way up. Open floor past it
      // would be a dark place to duck and a back door.
      const Rect.fromLTRB(1400, 170, 1440, 620),
    ],
    lights: const [
      // The lamp over the plate. Its bottom edge is at 540: a standing body's
      // head is at 524 and in it, a ducked body's is at 551 and eleven clear.
      LightSpec(Rect.fromLTRB(-440, 200, -300, 540)),
      // The beam at the foot of the shelf, to the floor. Narrow, so the dark
      // is close: a body ducked anywhere from about 570 to 628 is clear of
      // it and near enough to jump onto the shelf from.
      LightSpec(Rect.fromLTRB(650, 200, 700, 620)),
    ],
    // The wrong way from the gate, as the first plate in the game was, and
    // far enough from the spawn that ducking your way past it is too slow to
    // be a plan.
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-420, 608, -320, 620), opens: 'gate'),
    ],
    // A second and a half of grace, your past's and not yours: the walk from
    // the plate is three seconds and the delay is three, so you arrive as it
    // opens and the grace is only there for arriving a beat late.
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(300, 360, 326, 620),
        lingerSeconds: 1.5,
      ),
    ],
    goal: const Rect.fromLTRB(1100, 358, 1180, 430),
  );

  /// **Phase 7, two.** Three gates, one past — and the past is the whole
  /// plan, laid down before the first gate opens.
  ///
  /// Every plate is behind the first gate. There is nothing to press on the
  /// far side of it, so by the time you walk through, the three presses the
  /// three gates need are already in your past and on their way: the second
  /// and third gates are opened by things you did **before you could see
  /// them working**. That is the hypothesis this phase is built on — a long
  /// level is not a short one with more floor, it is one where the buffer is
  /// something you spend from — and this is the level that tests it.
  ///
  /// The plates are on balconies rather than on the floor, and the level does
  /// not exist without that. A floor plate is a plate you cross, and a shadow
  /// crossing a plate opens its gate for as long as the grace lasts: the first
  /// draft had all three on the floor in a row, and walking to the wall and
  /// back — pressing nothing on purpose — opened the gates in a usable order
  /// from the crossings alone. A balcony is something you have to decide to
  /// climb onto. Walking underneath it presses nothing.
  ///
  /// And the balconies are **not** in the gates' order. The middle one opens
  /// the first gate, the far one the second, the near one the third. So the
  /// two orders a hand falls into — nearest first, and furthest first (which
  /// is what the very first level taught) — both open the gates in an order
  /// nobody can walk through. The only order that works is the gates' own,
  /// which means the route through the balconies is worked out from the gates
  /// backwards: that is the thing to understand, and nothing here is timed
  /// tightly enough to be the thing instead. The grace on each gate is
  /// generous, and a sweep of every order at every pause
  /// (`levels_test.dart`) finds only that one order finishing — with anything
  /// from a touch to over a second on each balcony.
  ///
  /// Getting it wrong costs a restart rather than a walk back, and that is
  /// the answer this level gives to the question `docs/phase-7-hard-levels.md`
  /// left open. The whole plan lives on this side of the first gate, so "go
  /// back and redo the part that went wrong" and "start again" are the same
  /// walk; a way back would be a slower R. Nothing kills.
  static final Level threeGatesOnePast = Level(
    id: 'three-gates-one-past',
    solution: const [
      Move.left(1.3), // under the near balcony, to the foot of the middle one
      Move.left(0.5, jump: true), // up onto it
      Move.left(0.15),
      Move(0.6), // the first gate
      Move.left(0.2),
      Move.left(0.55, jump: true), // across onto the far balcony
      Move.left(0.25),
      Move(0.6), // the second gate
      Move.right(1.45), // off it, and back under the middle one
      Move.right(0.55, jump: true), // up onto the near balcony
      Move.right(0.1),
      Move(0.6), // the third gate
      Move.right(12), // and through all three, in the order they were pressed
    ],
    wrongIdeas: const [
      // Nearest first, the way the balconies come to hand.
      [
        Move.left(0.15),
        Move.left(0.55, jump: true),
        Move.left(0.1),
        Move(0.6),
        Move.left(0.2),
        Move.left(0.55, jump: true),
        Move.left(0.25),
        Move(0.6),
        Move.left(0.38),
        Move.left(0.55, jump: true),
        Move.left(0.25),
        Move(0.6),
        Move.right(14),
      ],
      // Furthest first, the habit the first level taught.
      [
        Move.left(2.4),
        Move.left(0.55, jump: true),
        Move.left(0.1),
        Move(0.6),
        Move.right(0.2),
        Move.right(0.55, jump: true),
        Move.right(0.25),
        Move(0.6),
        Move.right(0.3),
        Move.right(0.55, jump: true),
        Move.right(0.25),
        Move(0.6),
        Move.right(14),
      ],
      // One gate at a time: the first one's balcony, through it, and then
      // look for the second.
      [
        Move.left(1.3),
        Move.left(0.5, jump: true),
        Move.left(0.15),
        Move(1.2),
        Move.right(14),
      ],
    ],
    name: 'تلات أبواب بماضي واحد',
    teaches: 'تلات أبواب. ماضيك هيفتحهم بنفس ترتيب ما دُست.',
    nameEn: 'Three Gates, One Past',
    teachesEn: 'Three gates. Your past opens them in the order you pressed.',
    // Longer than anything else in the campaign, because it has to hold three
    // presses and the walk back from them. The waiting it costs is at the
    // first gate, with the plan already made, and it is short.
    delaySeconds: 5.5,
    spawnX: -20,
    floorTop: _floor,
    blocks: [
      _ground(-800, 1100),
      // The back wall. Tall enough that a body on a ducked shadow on the far
      // balcony still cannot top it (the top of that climb is 301).
      const Rect.fromLTRB(-840, 200, -800, 620),
      // Three balconies, a hundred and fourteen above the floor: out of reach
      // of nothing, a jump puts you on any of them, but high enough that a
      // standing body walks underneath with room to spare. Walking past is
      // not pressing. The gaps between them are a hundred and fifty, which is
      // room to take off from the floor in and a hop from one to the next.
      const Rect.fromLTRB(-750, 506, -650, 522),
      const Rect.fromLTRB(-500, 506, -400, 522),
      const Rect.fromLTRB(-250, 506, -150, 522),
    ],
    // Out of order on purpose. See above.
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-740, 494, -660, 506), opens: 'second'),
      PlateSpec(area: Rect.fromLTRB(-490, 494, -410, 506), opens: 'first'),
      PlateSpec(area: Rect.fromLTRB(-240, 494, -160, 506), opens: 'third'),
    ],
    // Four hundred apart, a little under two seconds of walking, and the
    // grace is most of that again: the gates forgive arriving late, never the
    // wrong order. The first one has longest, because it is the one you wait
    // at while your whole plan walks back to you.
    doors: const [
      DoorSpec(
        id: 'first',
        closed: Rect.fromLTRB(60, 360, 86, 620),
        lingerSeconds: 2,
      ),
      DoorSpec(
        id: 'second',
        closed: Rect.fromLTRB(460, 360, 486, 620),
        lingerSeconds: 1.5,
      ),
      DoorSpec(
        id: 'third',
        closed: Rect.fromLTRB(860, 360, 886, 620),
        lingerSeconds: 1.5,
      ),
    ],
    goal: const Rect.fromLTRB(960, 548, 1040, 620),
  );

  /// **Phase 7, last.** All of it — nothing new, everything somewhere else.
  ///
  /// Four rooms, one delay, and every room is a lesson from earlier in the
  /// campaign put somewhere it was not learned:
  ///
  /// 1. **The key, on a balcony.** Touch it and leave before you come back
  ///    to flip it (`closeWhatYouOpened`). Up on a balcony a trip to it is
  ///    exactly one arrival, with no wall needed to turn you round, and
  ///    nobody flips it by walking past.
  /// 2. **The lamp that stops short of the floor, over a plate.** Duck on it
  ///    (`underTheLight`). New here: the plate is right behind the gate you
  ///    just came through and you walk over it on the way — and walking
  ///    over it does nothing, because a walking past is standing and its
  ///    head is in the lamp. The lamp is what makes a plate on the path
  ///    safe to have on the path.
  /// 3. **The inverted plate on the corridor floor.** Jump it
  ///    (`yourPastShutsIt`). The balcony that holds the gate is *before* it,
  ///    which is the only order where it matters: crossing an inverted plate
  ///    before your past has held anything shuts nothing that was open.
  /// 4. **The beam that goes to the floor, at the foot of the shelf.** Duck
  ///    in the dark further out (`yourShadowIsNotHere`) — and after the
  ///    second room, ducking was the answer to light. Here it is not.
  ///
  /// So three recorded wrong ideas, one for each room after the first, and
  /// each is the previous room's habit carried one room too far or the
  /// campaign's oldest habit — stand on the plate — met in the one place it
  /// fails.
  ///
  /// Nothing kills. Every mistake is a shut gate you can see from where you
  /// are standing, and costs a restart of a level that takes about twenty
  /// seconds when you know it.
  static final Level allOfIt = Level(
    id: 'all-of-it',
    solution: const [
      Move.left(0.27), // to the foot of the balcony
      Move.left(0.55, jump: true), // up onto the key
      Move.left(0.15),
      Move(0.2),
      Move.right(2.3), // off it, and through the first gate before you return
      Move(1.2, crouch: true), // duck on the plate under the lamp
      Move.right(3.0), // to the second gate
      Move(0.5),
      Move.right(0.4), // through it, to the foot of the next balcony
      Move.right(0.55, jump: true), // up onto the plate
      Move.right(0.1),
      Move(1.0), // stand: this holds the third gate
      Move.right(0.9), // off it
      Move.right(0.55, jump: true), // over the plate on the floor
      Move.right(3.9), // the long way to the third gate, and through
      Move(1.2, crouch: true), // duck in the dark short of the beam
      Move.left(0.6),
      Move(1.1),
      Move.right(0.05),
      Move.right(0.55, jump: true), // onto it
      Move(0.1),
      Move.right(0.6, jump: true), // and onto the shelf
      Move.right(2.0), // to the way out
    ],
    wrongIdeas: const [
      // The second room: stand on the plate, as every plate is stood on. Your
      // past arrives with its head in the lamp and is not there.
      [
        Move.left(0.27),
        Move.left(0.55, jump: true),
        Move.left(0.15),
        Move(0.2),
        Move.right(2.3),
        Move(1.2),
        Move.right(3.0),
        Move(0.5),
        Move.right(0.4),
        Move.right(0.55, jump: true),
        Move.right(0.1),
        Move(1.0),
        Move.right(0.9),
        Move.right(0.55, jump: true),
        Move.right(3.9),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(1.1),
        Move.right(0.05),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.6, jump: true),
        Move.right(2.0),
      ],
      // The third: walk across the plate on the floor. Your past walks
      // across it three seconds later, and it beats the plate on the balcony
      // and its grace.
      [
        Move.left(0.27),
        Move.left(0.55, jump: true),
        Move.left(0.15),
        Move(0.2),
        Move.right(2.3),
        Move(1.2, crouch: true),
        Move.right(3.0),
        Move(0.5),
        Move.right(0.4),
        Move.right(0.55, jump: true),
        Move.right(0.1),
        Move(1.0),
        Move.right(0.9),
        Move.right(0.55),
        Move.right(3.9),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(1.1),
        Move.right(0.05),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.6, jump: true),
        Move.right(2.0),
      ],
      // The fourth: duck hard against the shelf, where the climb is
      // shortest — the second room's answer to a lamp. This beam reaches the
      // floor.
      [
        Move.left(0.27),
        Move.left(0.55, jump: true),
        Move.left(0.15),
        Move(0.2),
        Move.right(2.3),
        Move(1.2, crouch: true),
        Move.right(3.0),
        Move(0.5),
        Move.right(0.4),
        Move.right(0.55, jump: true),
        Move.right(0.1),
        Move(1.0),
        Move.right(0.9),
        Move.right(0.55, jump: true),
        Move.right(4.35),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(1.1),
        Move.right(0.05),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.6, jump: true),
        Move.right(2.0),
      ],
    ],
    name: 'كله مع بعض',
    teaches: 'مفيش جديد. كل اللي اتعلمته، في أوض تانية.',
    nameEn: 'All of It',
    teachesEn: 'Nothing new. Everything you learned, in other rooms.',
    delaySeconds: 3,
    spawnX: -100,
    floorTop: _floor,
    blocks: [
      _ground(-440, 2840),
      const Rect.fromLTRB(-440, 200, -400, 620),
      const Rect.fromLTRB(-360, 506, -260, 522),
      const Rect.fromLTRB(1060, 506, 1160, 522),
      const Rect.fromLTRB(2400, 430, 2800, 620),
      const Rect.fromLTRB(2800, 170, 2840, 620),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-350, 494, -270, 506), flips: 'first'),
    ],
    lights: const [
      LightSpec(Rect.fromLTRB(160, 200, 300, 540)),
      LightSpec(Rect.fromLTRB(2350, 200, 2400, 620)),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(180, 608, 280, 620), opens: 'second'),
      PlateSpec(area: Rect.fromLTRB(1070, 494, 1150, 506), opens: 'third'),
      PlateSpec(
        area: Rect.fromLTRB(1300, 608, 1360, 620),
        opens: 'third',
        inverts: true,
      ),
    ],
    doors: const [
      DoorSpec(id: 'first', closed: Rect.fromLTRB(120, 360, 146, 620)),
      DoorSpec(
        id: 'second',
        closed: Rect.fromLTRB(900, 360, 926, 620),
        lingerSeconds: 1.5,
      ),
      DoorSpec(
        id: 'third',
        closed: Rect.fromLTRB(2100, 360, 2126, 620),
        lingerSeconds: 3,
      ),
    ],
    goal: const Rect.fromLTRB(2600, 358, 2680, 430),
  );

  /// **Phase 12, one.** The reversed button you cannot jump.
  ///
  /// `yourPastShutsIt` taught that an inverted plate on the way to a gate is
  /// a thing to jump. This one is on the floor of a tunnel, where there is no
  /// jumping, and the plate that holds the gate is at the far end of it. So
  /// the first thing to work out is that going **in** over it is harmless —
  /// your past crosses it before it has held anything open — and the second
  /// is that coming **back** over it is the whole failure: your past steps
  /// off the plate, crawls after you, and wipes the gate's grace three
  /// seconds before you can reach it. The way home is over the tunnel's roof.
  ///
  /// And the roof needs a step, at the one end you are standing at. Duck on
  /// the plate, which sits against the roof's face: the body you leave there
  /// holds the gate and is the stair, the same seconds of you doing both
  /// (`holdYourOwnDoor`).
  ///
  /// The light at the roof's other end is what keeps it one route. Without
  /// it you could build the step on the near side before ever going in,
  /// walk the roof both ways and never meet the tunnel. A body ducked clear
  /// of the beam is too far out to reach the roof from — `more_levels_test`
  /// sweeps it.
  ///
  /// The tunnel's floor past the plate is longer than the delay on purpose:
  /// from the reversed button to the gate is nearly four seconds, so your
  /// past is on it before you get there, however long you held the plate.
  static final Level inUnderBackOver = Level(
    id: 'in-under-back-over',
    solution: const [
      Move.left(1.3), // to the mouth of the tunnel
      Move.left(3.4, crouch: true), // through it, over the reversed button
      Move.left(0.3),
      Move(1.5, crouch: true), // duck on the plate, against the roof
      Move.left(0.6), // out of your own way
      Move(0.9),
      Move.right(0.55, jump: true), // onto your own head
      Move(0.1),
      Move.right(0.7, jump: true), // and onto the roof
      Move.right(6), // over the tunnel, down, and through the gate
    ],
    wrongIdeas: const [
      // Back the way you came. Your past follows you into the tunnel three
      // seconds later, onto the reversed button, and the gate shuts in front
      // of you for good.
      [
        Move.left(1.3),
        Move.left(3.4, crouch: true),
        Move.left(0.3),
        Move(1.5, crouch: true),
        Move.right(3.6, crouch: true),
        Move.right(6),
      ],
      // Build the step on this side, so the roof is a way there as well as
      // back. The lamp is where the step would have to be.
      [
        Move.left(0.6),
        Move(1.5, crouch: true),
        Move.right(0.6),
        Move(1.0),
        Move.left(0.55, jump: true),
        Move(0.1),
        Move.left(0.7, jump: true),
        Move.left(5),
        Move(1.5, crouch: true),
        Move.right(8),
      ],
    ],
    name: 'رايح من تحت، راجع من فوق',
    teaches: 'المعكوس جوّه النفق. خُش منه، بس مترجعش منه.',
    nameEn: 'In Under, Back Over',
    teachesEn:
        'The reversed button is in the tunnel. In through it, never back.',
    delaySeconds: 3,
    spawnX: -200,
    floorTop: _floor,
    blocks: [
      _ground(-1100, 400),
      // The dead end, 420 tall: nothing climbs it.
      const Rect.fromLTRB(-1100, 200, -1060, 620),
      // The tunnel's roof. Its underside is at 540, so a standing body (96)
      // does not fit under it and a ducked one (69) does; its top is 190
      // above the floor, out of a jump's reach and inside a step's.
      const Rect.fromLTRB(-800, 430, -500, 540),
    ],
    // Over the tunnel's mouth on this side, to the floor. A past ducked
    // anywhere in it is not there, and a past ducked clear of it is too far
    // from the roof to climb onto it.
    lights: const [LightSpec(Rect.fromLTRB(-500, 200, -360, 620))],
    plates: const [
      // Hard against the roof's face, so ducking on it leaves the step.
      PlateSpec(area: Rect.fromLTRB(-880, 608, -810, 620), opens: 'gate'),
      PlateSpec(
        area: Rect.fromLTRB(-690, 608, -610, 620),
        opens: 'gate',
        inverts: true,
      ),
    ],
    // Long grace, because it is the only clock: from stepping off the plate
    // to the gate is the climb, the roof and the walk. It cannot rescue the
    // tunnel — the reversed button wipes it.
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(0, 360, 26, 620),
        lingerSeconds: 6.5,
      ),
    ],
    goal: const Rect.fromLTRB(200, 548, 280, 620),
  );

  /// **Phase 12, two.** Two lamps, and they ask opposite things.
  ///
  /// A lamp that stops at head height erases a standing past and misses a
  /// ducked one — `underTheLight` used that to make you duck on a plate, so
  /// that your past would be there to hold it. The first room asks it again.
  ///
  /// The second room has the same lamp over a key, and here you want the
  /// opposite. A key your past arrives on is a key your past flips back
  /// (`closeWhatYouOpened`), and the door it opens is the last one in the
  /// level, a climb away — far longer than three seconds. So duck on it, as
  /// the room before just taught, and your past comes back, ducked, out of
  /// the light, and shuts that door while you are building the step. Stand
  /// on it and your past arrives standing, in the light, and is not there:
  /// the flip is yours alone, and it stays.
  ///
  /// Same lamp, same height, and what you want from your past decides how
  /// you stand under it. That is the level.
  static final Level standToStay = Level(
    id: 'stand-to-stay',
    solution: const [
      Move.left(1.36), // the wrong way first, to the plate under the lamp
      Move(1.2, crouch: true), // duck on it: under the lamp, ducked counts
      Move.right(2.7), // to the gate, and through as it opens
      Move.right(1.0), // to the foot of the balcony
      Move.right(0.55, jump: true), // up onto the key, under the second lamp
      Move(0.3), // standing: your past will not be there to flip it back
      Move.right(1.8), // off it, to the foot of the shelf
      Move(1.0, crouch: true), // duck: the step up
      Move.left(0.5), // out of your own way
      Move(1.6),
      Move.right(0.55, jump: true), // onto your own head
      Move(0.1),
      Move.right(0.7, jump: true), // onto the shelf
      Move.right(3), // and through the door the key opened
    ],
    wrongIdeas: const [
      // The first room's answer carried into the second: duck under the
      // lamp. Your past ducks on the key three seconds later and the last
      // door shuts while you are building the step to it.
      [
        Move.left(1.36),
        Move(1.2, crouch: true),
        Move.right(2.7),
        Move.right(1.0),
        Move.right(0.55, jump: true),
        Move(0.3, crouch: true),
        Move.right(1.8),
        Move(1.0, crouch: true),
        Move.left(0.5),
        Move(1.6),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(3),
      ],
      // Stand on the plate, the way every plate is stood on. Your past
      // arrives with its head in the lamp and holds nothing.
      [
        Move.left(1.36),
        Move(1.2),
        Move.right(2.7),
        Move(3.0),
        Move.right(1.0),
        Move.right(0.55, jump: true),
        Move(0.3),
        Move.right(1.8),
        Move(1.0, crouch: true),
        Move.left(0.5),
        Move(1.6),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(3),
      ],
    ],
    name: 'اقف عشان تفضل',
    teaches: 'تحت اللمبة، ماضيك الواطي موجود والواقف لأ. اختار.',
    nameEn: 'Stand So It Stays',
    teachesEn:
        'Under a lamp your crouched past is there and your standing one '
        'is not.',
    delaySeconds: 3,
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-500, 1640),
      const Rect.fromLTRB(-540, 200, -500, 620),
      // The balcony the key is on, so nothing flips it by walking past.
      const Rect.fromLTRB(600, 506, 700, 522),
      // The shelf with the last door on it: 190, a step and not a jump.
      const Rect.fromLTRB(1100, 430, 1640, 620),
      // Closing its far end, so the step goes at this one.
      const Rect.fromLTRB(1600, 170, 1640, 430),
    ],
    lights: const [
      // Over the plate. Its bottom edge is at 540: a standing body's head is
      // at 524 and in it, a ducked body's at 551 and clear.
      LightSpec(Rect.fromLTRB(-370, 200, -230, 540)),
      // Over the key, at the same height above the balcony as the first is
      // above the floor: a standing head on the balcony is at 410, a ducked
      // one at 437, and the edge is between them at 425.
      LightSpec(Rect.fromLTRB(590, 200, 710, 425)),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(610, 494, 690, 506), flips: 'last'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-350, 608, -250, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(300, 360, 326, 620),
        lingerSeconds: 1.5,
      ),
      DoorSpec(id: 'last', closed: Rect.fromLTRB(1300, 170, 1326, 430)),
    ],
    goal: const Rect.fromLTRB(1480, 358, 1560, 430),
  );

  /// **Phase 12, three.** The only place for the step shuts the door.
  ///
  /// The shelf can be climbed from one place: its foot, where a step is
  /// close enough to jump from. And the whole of that place is a reversed
  /// button for the gate on the shelf. A step is a ducked body, a ducked
  /// body presses, and so for as long as your step is there, the gate is
  /// held shut — and when your past stands up and walks off it, the grace
  /// went with it.
  ///
  /// Which makes the order every level so far has taught — press, then
  /// climb — the one order that cannot work. Press the plate on the balcony
  /// and then duck for the step, and your past presses the plate and then
  /// ducks on the reversed button: whatever it held is wiped before you are
  /// up. The step has to come **first**. Duck at the foot, go back and press
  /// the plate while the step is still on its way, and come back to climb
  /// it. By the time you are at the gate your past has climbed off the
  /// button and walked to the plate, and that is what opens it.
  ///
  /// The delay is long so that round trip is not a race: five and a half
  /// seconds, and how long you duck is how long the step stays.
  static final Level theStepThatShuts = Level(
    id: 'the-step-that-shuts',
    solution: const [
      Move.right(2.45), // to the foot of the shelf, onto the reversed button
      Move(1.0, crouch: true), // duck: the step, first
      Move.left(0.8), // then back to the balcony
      Move.left(0.55, jump: true), // up onto the plate
      Move.left(0.1),
      Move(0.5), // stand: this is what will hold the gate
      Move.right(0.6), // off it
      Move(1.5), // and wait for the step you left
      Move.right(0.25),
      Move.right(0.55, jump: true), // onto your own head
      Move(0.1),
      Move.right(0.7, jump: true), // onto the shelf
      Move.right(6), // to the gate, open once your past is on the plate
    ],
    wrongIdeas: const [
      // Press, then climb — the order of every level before this. Your past
      // does the same: presses the plate, then ducks on the reversed button,
      // and the gate is shut by the step you are standing on.
      [
        Move.right(0.9),
        Move.right(0.55, jump: true),
        Move(0.5),
        Move.right(1.6),
        Move(1.0, crouch: true),
        Move.left(0.6),
        Move(4.0),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(8),
      ],
      // Leave the step just off the button, where it shuts nothing. It is
      // also too far out to climb from.
      [
        Move.right(1.6),
        Move(1.0, crouch: true),
        Move.left(0.3),
        Move.left(0.55, jump: true),
        Move.left(0.1),
        Move(0.5),
        Move.right(0.4),
        Move(2.6),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(6),
      ],
    ],
    name: 'السلّمة بتقفل',
    teaches: 'مكان السلّمة الوحيد بيقفل الباب. فكّر في الترتيب.',
    nameEn: 'The Step That Shuts',
    teachesEn:
        'The only place for a step shuts the door. Think about the order.',
    delaySeconds: 5.5,
    spawnX: -200,
    floorTop: _floor,
    blocks: [
      _ground(-600, 1240),
      const Rect.fromLTRB(-640, 200, -600, 620),
      // The balcony, a hop up, so the plate is pressed on purpose.
      const Rect.fromLTRB(0, 506, 100, 522),
      // The shelf: 190, a step and not a jump.
      const Rect.fromLTRB(400, 430, 1200, 620),
      // Closing its far end. Open floor past it would be a second foot.
      const Rect.fromLTRB(1200, 170, 1240, 620),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(10, 494, 90, 506), opens: 'gate'),
      // The whole foot of the shelf, and then some. The best climb off a step
      // — onto it in place, to its edge, and jump — reaches the shelf from
      // about 175 out; a body that is off this plate, less than a footprint
      // over its edge, is 207 out or more, and falls short
      // (`highestClimbFrom` in the tests searches it).
      PlateSpec(
        area: Rect.fromLTRB(200, 608, 400, 620),
        opens: 'gate',
        inverts: true,
      ),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(800, 170, 826, 430),
        lingerSeconds: 3,
      ),
    ],
    goal: const Rect.fromLTRB(1000, 358, 1080, 430),
  );

  /// **Phase 12, four.** A lamp hung high enough to miss you — until your
  /// past is a stair.
  ///
  /// The first shelf has a lamp at its foot, ending just above head height.
  /// It misses a standing body and misses a ducked one, so the step goes
  /// where it always goes, right at the foot, and works. The lesson the room
  /// gives is *this lamp does not matter*.
  ///
  /// The roof needs two steps (`stairOfYourself`): the far past ducked on
  /// the shelf, and the near one ducked on top of it, floating sixty-nine
  /// up. The same lamp hangs at the roof's foot at the same height — and a
  /// stair has a body higher than you ever are. The top step is touched by
  /// the light and is not there. Build the stair at the foot, as the first
  /// room said you could, and you jump through your own past.
  ///
  /// So the stair goes in the dark, just clear of the beam, where the top
  /// step is still close enough to jump from: from about a body's width out
  /// to the lamp's edge. `more_levels_test` sweeps that band.
  static final Level stairInTheDark = Level(
    id: 'stair-in-the-dark',
    solution: const [
      Move.right(1.25), // to the foot of the shelf, under the high lamp
      Move(1.2, crouch: true), // duck: the lamp is above a ducked body
      Move(0.3),
      Move(0.9), // wait for it
      Move(0.5, jump: true), // straight up onto it
      Move.right(0.9, jump: true), // and off it onto the shelf
      Move.right(1.95), // along the shelf, short of the second lamp
      Move(3.5, crouch: true), // duck, long: the bottom step
      Move(1.6), // wait for the far one under you
      Move(0.5, jump: true), // up onto it
      Move(1.0, crouch: true), // and duck on top: the second step
      Move(1.0), // wait for the near one on top
      Move(0.7, jump: true), // up onto that, in the dark
      Move.right(0.9, jump: true), // and onto the roof
      Move.right(1.5),
    ],
    wrongIdeas: const [
      // The stair at the foot of the roof, where the first room's step went.
      // The top step is in the light.
      [
        Move.right(1.25),
        Move(1.2, crouch: true),
        Move(0.3),
        Move(0.9),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(2.25),
        Move(3.5, crouch: true),
        Move(1.6),
        Move(0.5, jump: true),
        Move(1.0, crouch: true),
        Move(1.0),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
      // One step, in the dark, which is all the first shelf needed.
      [
        Move.right(1.25),
        Move(1.2, crouch: true),
        Move(0.3),
        Move(0.9),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.95),
        Move(1.5, crouch: true),
        Move(1.0),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
    ],
    name: 'السلّمة في الضلمة',
    teaches: 'اللمبة العالية مبتلمسكش. بس السلّمة أعلى منك.',
    nameEn: 'A Stair in the Dark',
    teachesEn: 'The high lamp misses you. A stair of you is taller than you.',
    delays: const [2, 5],
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-400, 1500),
      // One step up: 190.
      const Rect.fromLTRB(300, 430, 1500, 620),
      // Two steps up: 230 above the shelf, past one ducked body's 205 and
      // inside two bodies' 274. It ends where the shelf does, so it has no
      // back way up.
      const Rect.fromLTRB(900, 200, 1500, 430),
    ],
    lights: const [
      // Both end 105 above what they hang over: a standing head is 96 up, a
      // ducked one 69, and the top of a stair 138.
      LightSpec(Rect.fromLTRB(260, 200, 300, 515)),
      LightSpec(Rect.fromLTRB(860, 0, 900, 325)),
    ],
    goal: const Rect.fromLTRB(1100, 128, 1180, 200),
  );

  /// **Phase 12, last.** All of it again — nothing new, everything somewhere
  /// else, the way `allOfIt` closed Phase 7.
  ///
  /// 1. **The key under the lamp, stood on** (`standToStay`). It opens the
  ///    door at the end of the next room, and the next room takes longer
  ///    than the delay. Up here at the start, with no lamp-plate before it,
  ///    the trap is the campaign's older habit — a lamp means duck.
  /// 2. **The step that shuts** (`theStepThatShuts`), with the plate under
  ///    a lamp. Step first, then duck on the plate, then climb. The plate is
  ///    on the way, and walking over it does nothing: a walking past is
  ///    standing, and its head is in the lamp.
  /// 3. **The tunnel** (`inUnderBackOver`), the other way round: the plate
  ///    is on this side and the gate beyond. The tunnel is the obvious way
  ///    on, and the reversed button in it is behind the plate, so it is the
  ///    wrong one. Duck on the plate against the roof and go over.
  ///
  /// Nothing kills. Every mistake is a shut door you can see, and a restart.
  static final Level allOfItAgain = Level(
    id: 'all-of-it-again',
    solution: const [
      Move.right(0.3),
      Move.right(0.55, jump: true), // up onto the key
      Move(0.3), // standing, under the lamp
      Move.right(2.6), // off it, over the lamp plate, to the step spot
      Move(1.5, crouch: true), // duck on the reversed button: the step first
      Move.left(1.0), // back to the plate under the lamp
      Move(0.8, crouch: true), // duck on it
      Move.right(0.25), // short of the button: your past will run up here too
      Move(0.55), // wait for the step
      Move.right(0.65, jump: true), // a running jump onto your own head
      Move.right(0.1),
      Move.right(0.7, jump: true), // up onto the shelf
      Move.right(1.2), // to the gate, and through as your past presses
      Move(1.0),
      Move.right(4.0), // through the key's door, and off the end
      Move(1.2, crouch: true), // duck on the plate by the roof
      Move.left(0.6), // out of your own way
      Move(2.2),
      Move.right(0.55, jump: true), // onto your own head
      Move(0.1),
      Move.right(0.7, jump: true), // onto the roof
      Move.right(5), // over the tunnel and through the last gate
    ],
    wrongIdeas: const [
      // The campaign's older habit at the first lamp: duck under it. Your
      // past ducks on the key four seconds later, out of the light, and the
      // key's door shuts while you are still building the step to the shelf.
      [
        Move.right(0.3),
        Move.right(0.55, jump: true),
        Move(0.3, crouch: true),
        Move.right(2.6),
        Move(1.5, crouch: true),
        Move.left(1.0),
        Move(0.8, crouch: true),
        Move.right(0.25),
        Move(0.55),
        Move.right(0.65, jump: true),
        Move.right(0.1),
        Move.right(0.7, jump: true),
        Move.right(1.2),
        Move(1.0),
        Move.right(4.0),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(2.2),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(5),
      ],
      // The plate first and then the step, the order of every level before
      // `theStepThatShuts`. Your past ducks on the reversed button after it
      // has pressed, and the gate is shut by the step you are standing on.
      [
        Move.right(0.3),
        Move.right(0.55, jump: true),
        Move(0.3),
        Move.right(1.6),
        Move(0.8, crouch: true),
        Move.right(1.0),
        Move(1.5, crouch: true),
        Move.left(0.5),
        Move(2.0),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(1.2),
        Move(3.0),
        Move.right(4.0),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(2.2),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(5),
      ],
      // The right order, standing on the plate. Its head is in the lamp.
      [
        Move.right(0.3),
        Move.right(0.55, jump: true),
        Move(0.3),
        Move.right(2.6),
        Move(1.5, crouch: true),
        Move.left(1.0),
        Move(0.8),
        Move.right(0.25),
        Move(0.55),
        Move.right(0.65, jump: true),
        Move.right(0.1),
        Move.right(0.7, jump: true),
        Move.right(1.2),
        Move(1.0),
        Move.right(4.0),
        Move(1.2, crouch: true),
        Move.left(0.6),
        Move(2.2),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(5),
      ],
      // The tunnel, because it is the way on. Your past follows you onto the
      // reversed button just inside it and wipes the last gate's grace.
      [
        Move.right(0.3),
        Move.right(0.55, jump: true),
        Move(0.3),
        Move.right(2.6),
        Move(1.5, crouch: true),
        Move.left(1.0),
        Move(0.8, crouch: true),
        Move.right(0.25),
        Move(0.55),
        Move.right(0.65, jump: true),
        Move.right(0.1),
        Move.right(0.7, jump: true),
        Move.right(1.2),
        Move(1.0),
        Move.right(4.0),
        Move(1.2, crouch: true),
        Move.right(3.6, crouch: true),
        Move.right(5),
      ],
    ],
    name: 'كله تاني',
    teaches: 'مفيش جديد. آخر أربع مراحل، في أوض تانية.',
    nameEn: 'All of It, Again',
    teachesEn: 'Nothing new. The last four levels, in other rooms.',
    delaySeconds: 4,
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-300, 2900),
      const Rect.fromLTRB(-340, 200, -300, 620),
      // The key's balcony.
      const Rect.fromLTRB(100, 506, 200, 522),
      // The shelf, 190 up, with the gate and the key's door on it. It ends
      // 420 short of the roof, which no jump crosses.
      const Rect.fromLTRB(800, 430, 1450, 620),
      // The tunnel's roof: 540 underneath, 190 on top.
      const Rect.fromLTRB(1870, 430, 2170, 540),
    ],
    lights: const [
      // Over the key: a standing head on the balcony is in it, a ducked one
      // clear (`standToStay`).
      LightSpec(Rect.fromLTRB(90, 150, 210, 425)),
      // Over the plate: a standing past is in it, a ducked one clear.
      LightSpec(Rect.fromLTRB(430, 200, 570, 540)),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(110, 494, 190, 506), flips: 'key'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(450, 608, 550, 620), opens: 'one'),
      // The shelf's whole foot, as in `theStepThatShuts`.
      PlateSpec(
        area: Rect.fromLTRB(600, 608, 800, 620),
        opens: 'one',
        inverts: true,
      ),
      // Against the roof's face, so ducking on it leaves the step.
      PlateSpec(area: Rect.fromLTRB(1800, 608, 1870, 620), opens: 'three'),
      // Just inside the tunnel, so the crawl from it to the last gate is
      // longer than the delay.
      PlateSpec(
        area: Rect.fromLTRB(1890, 608, 1970, 620),
        opens: 'three',
        inverts: true,
      ),
    ],
    doors: const [
      DoorSpec(
        id: 'one',
        closed: Rect.fromLTRB(1000, 170, 1026, 430),
        lingerSeconds: 3,
      ),
      DoorSpec(id: 'key', closed: Rect.fromLTRB(1200, 170, 1226, 430)),
      DoorSpec(
        id: 'three',
        closed: Rect.fromLTRB(2700, 360, 2726, 620),
        lingerSeconds: 6.5,
      ),
    ],
    goal: const Rect.fromLTRB(2820, 548, 2900, 620),
  );

  /// **Phase 12, the light switch, four.** Two pasts, one key — three flips.
  ///
  /// A key your past walks onto is a key your past throws back. With two
  /// pasts it is thrown back and then thrown again: you put the lamp out, the
  /// near past lights it two seconds later, the far one puts it out three
  /// seconds after that — and nobody comes after the far one. One touch, and
  /// the lamp is out for good. (The same arithmetic made a door that ends
  /// open forever, which is why "two shadows and a key" was struck for doors
  /// in Phase 7. For a light, out for good is the point.)
  ///
  /// The roof needs a stair of both pasts (`stairOfYourself`), and the only
  /// place one reaches it from is under the lamp. `yourPastsDark` taught the
  /// step first and the key after, and that order cannot work here: the near
  /// past relights the lamp two seconds after the key, long before a stair
  /// that takes seven to build is standing. The key goes first — and then
  /// there is nothing to hurry for.
  ///
  /// The lamp is wide on purpose. A stair in the dark beside it, with no key
  /// at all, reaches a roof up to about 200 out (searched, in
  /// `light_switch_test`); the lamp starts 230 out, so the dark is too far.
  static final Level theThirdFlip = Level(
    id: 'the-third-flip',
    solution: const [
      Move.left(0.9), // the wrong way, to the foot of the balcony
      Move.left(0.55, jump: true), // up onto the key: first
      Move(0.2),
      Move.right(3.75), // all the way to the foot of the roof, under the lamp
      Move(3.5, crouch: true), // duck, long: the bottom step
      Move(1.6), // wait for the far one under you
      Move(0.5, jump: true), // up onto it
      Move(1.0, crouch: true), // and duck on top: the second step
      Move(1.0), // wait for the near one on top
      Move(0.7, jump: true), // up onto that, in the dark for good
      Move.right(0.9, jump: true), // and onto the roof
      Move.right(1.5),
    ],
    wrongIdeas: const [
      // No key: the stair under the lit lamp, which erases both steps.
      [
        Move.right(2.45),
        Move(3.5, crouch: true),
        Move(1.6),
        Move(0.5, jump: true),
        Move(1.0, crouch: true),
        Move(1.0),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
      // The order `yourPastsDark` taught: the step first, then the key, then
      // back to climb. With two pasts the key is thrown back on two seconds
      // later, and the stair takes longer than that to stand.
      [
        Move.right(2.45),
        Move(3.5, crouch: true),
        Move.left(3.4),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(3.75),
        Move(0.5, jump: true),
        Move(1.0, crouch: true),
        Move(1.0),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
      // The key, and then one step, in the dark: the roof is past one
      // ducked body's reach.
      [
        Move.left(0.9),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(3.75),
        Move(1.5, crouch: true),
        Move(1.2),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
    ],
    name: 'التالتة بتطفيها',
    teaches: 'ماضيك اتنين، والمفتاح بيتقلب تلات مرات. عدّهم.',
    nameEn: 'The Third Flip',
    teachesEn: 'Your past is two, so the key flips three times. Count them.',
    delays: const [2, 5],
    spawnX: 0,
    floorTop: _floor,
    blocks: [
      _ground(-600, 1300),
      const Rect.fromLTRB(-640, 200, -600, 620),
      const Rect.fromLTRB(-350, 506, -250, 522),
      const Rect.fromLTRB(600, 390, 1300, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(370, 200, 600, 620), id: 'lamp')],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-340, 494, -260, 506), flips: 'lamp'),
    ],
    goal: const Rect.fromLTRB(800, 318, 880, 390),
  );

  /// **Phase 12, the light switch, last.** All of it in the dark.
  ///
  /// Two rooms, two pasts, and the lessons of the four before:
  ///
  /// 1. **One holds the dark, one presses** (`oneHoldsTheDark`): the gate's
  ///    plate is under a lamp and the gate has no grace, so the near past
  ///    holds the switch while the far past stands on the plate. The plate
  ///    is on a balcony: on the floor, walking over it on the way to the
  ///    switch got you through at one exact hold, and a walk is not a press.
  /// 2. **The third flip** (`theThirdFlip`): a stair of both pasts under the
  ///    roof's lamp, which one key puts out for good.
  ///
  /// The new thing is where the second room's key is: **in the first room**.
  /// The gate shuts behind you, so the key has to be thrown before you can
  /// see what it is for — and throwing it early is exactly what the third
  /// flip rewards. Forget it and you reach a lit roof with no way back.
  static final Level allOfItInTheDark = Level(
    id: 'all-of-it-in-the-dark',
    solution: const [
      Move.left(2.35), // the wrong way, to the foot of the far balcony
      Move.left(0.55, jump: true), // up onto the next room's key
      Move(0.2),
      Move.right(0.5), // off the key's balcony
      Move(0.25),
      Move.right(0.55, jump: true), // up onto the plate under the first lamp
      Move(2.0), // stand on it, long: the far past will
      Move.right(0.5),
      Move.right(0.55, jump: true), // up onto the switch
      Move(1.6), // stand on it: the near past will
      Move.right(1.4), // to the gate: open, both of them in place
      Move.right(2.8), // through it, and on to the foot of the roof
      Move(3.5, crouch: true), // duck, long: the bottom step
      Move(1.6),
      Move(0.5, jump: true),
      Move(1.0, crouch: true), // the second step
      Move(1.0),
      Move(0.7, jump: true),
      Move.right(0.9, jump: true), // onto the roof
      Move.right(1.5),
    ],
    wrongIdeas: const [
      // Straight to the plate, leaving the next room's key where it is. The
      // gate shuts behind you, and the roof's lamp is lit for good.
      [
        Move.left(1.3),
        Move.left(0.55, jump: true),
        Move(2.0),
        Move.right(0.5),
        Move.right(0.55, jump: true),
        Move(1.6),
        Move.right(1.4),
        Move.right(2.8),
        Move(3.5, crouch: true),
        Move(1.6),
        Move(0.5, jump: true),
        Move(1.0, crouch: true),
        Move(1.0),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
      // One past's way with the first room: hold the switch yourself until
      // the gate opens, then run for it. Step off and the lamp is lit, the far
      // past on the plate is gone, and the gate has no grace.
      [
        Move.left(2.35),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(0.5),
        Move(0.25),
        Move.right(0.55, jump: true),
        Move(2.0),
        Move.right(0.5),
        Move.right(0.55, jump: true),
        Move(4.0),
        Move.right(1.4),
        Move.right(2.8),
        Move(3.5, crouch: true),
        Move(1.6),
        Move(0.5, jump: true),
        Move(1.0, crouch: true),
        Move(1.0),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
      // The switch first and then the plate: the far past holds the dark and
      // the near one presses — but the plate is further from the gate than
      // two seconds, and the near past has stepped off it by then.
      [
        Move.left(2.35),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(0.5),
        Move(0.25),
        Move.right(0.95),
        Move.right(0.55, jump: true),
        Move(1.6),
        Move.left(0.35),
        Move.left(0.55, jump: true),
        Move(2.0),
        Move.right(0.5),
        Move.right(3.8),
        Move(3.5, crouch: true),
        Move(1.6),
        Move(0.5, jump: true),
        Move(1.0, crouch: true),
        Move(1.0),
        Move(0.7, jump: true),
        Move.right(0.9, jump: true),
        Move.right(1.5),
      ],
    ],
    name: 'كله في الضلمة',
    teaches: 'مفتاح الأوضة الجاية هنا. واحد يطفي وواحد يدوس.',
    nameEn: 'All of It in the Dark',
    teachesEn:
        'The next room\'s key is in this one. One holds the dark, one '
        'presses.',
    delays: const [2, 5],
    spawnX: -120,
    floorTop: _floor,
    blocks: [
      _ground(-900, 1500),
      const Rect.fromLTRB(-940, 200, -900, 620),
      // The next room's key, up out of the way.
      const Rect.fromLTRB(-800, 506, -700, 522),
      // The plate's balcony, under the first lamp, so the plate is stood on
      // on purpose: a walk past it is not a press. On the floor, walking over
      // it on the way to the switch was a way through at one exact hold.
      const Rect.fromLTRB(-560, 506, -460, 522),
      // The switch's balcony.
      const Rect.fromLTRB(-330, 506, -230, 522),
      // The roof: 230, two steps and not one.
      const Rect.fromLTRB(700, 390, 1500, 620),
    ],
    lights: const [
      LightSpec(Rect.fromLTRB(-580, 200, -440, 620), id: 'plate-lamp'),
      LightSpec(Rect.fromLTRB(470, 200, 700, 620), id: 'roof-lamp'),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-790, 494, -710, 506), flips: 'roof-lamp'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-550, 494, -470, 506), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(-320, 494, -240, 506), opens: 'plate-lamp'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(30, 260, 56, 620)),
    ],
    goal: const Rect.fromLTRB(1000, 318, 1080, 390),
  );

  /// **Phase 12, the light switch, two again.** `yourPastsDark` with two
  /// things to fit into the dark instead of one.
  ///
  /// The key puts the lamp out until your past reaches the key, so the dark
  /// falls on the six seconds of you before the key — and both things the
  /// way out needs are under the lamp: the plate that holds the gate, on its
  /// balcony, and the step at the foot of the shelf. Both have to be in those
  /// six seconds, so the key comes last; the walk from the step to the key
  /// and back is a little over four of them, which leaves a second and a
  /// half to stop and think. Plate or step first does not matter, and the
  /// gate's long grace is there so it does not.
  ///
  /// The plate's balcony is narrow and far from the shelf, and the plate is
  /// at its far end, on purpose. Off the balcony's edge a running jump
  /// carries to about 394 at the shelf's height, which was the shelf until a
  /// test found it; and a past ducked on the plate is a step not much lower
  /// than the shelf, from which a run carries further still. With the plate
  /// where it is, that step is short. (A step at the balcony's other end does
  /// reach — but that is a plate and a step, the level's answer in another
  /// place.)
  static final Level theLastSixSeconds = Level(
    id: 'the-last-six-seconds',
    solution: const [
      Move.right(2.0), // under the lamp, past the plate's balcony
      Move(0.15),
      Move.left(0.65, jump: true), // up onto the plate
      Move(0.5), // it holds the gate, once a past stands on it in the dark
      Move.right(0.95), // off, to the foot of the shelf
      Move(0.15),
      Move(1.0, crouch: true), // duck: the step
      Move.left(1.2), // all the way back, out of the lamp
      Move(0.15),
      Move.left(0.55, jump: true), // up onto the key: the dark falls now,
      Move(0.2), // over the last six seconds of you
      Move.right(1.75), // back to where the step will be
      Move(1.25),
      Move(0.5, jump: true), // straight up onto it
      Move.right(0.9, jump: true), // and onto the shelf
      Move.right(4), // and through the gate the same dark is holding
    ],
    wrongIdeas: const [
      // The key first, the way every switch so far was thrown: the dark
      // falls on nothing yet, and your past is back on the key to light it
      // again before it ever ducks.
      [
        Move.right(1.2),
        Move(0.45),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(1.75),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.45),
        Move(0.15),
        Move.left(0.65, jump: true),
        Move(0.5),
        Move.right(0.95),
        Move(2.4),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // The plate and the key, and the step last: it is after the key, so
      // outside the six seconds it puts out. The lamp is back by the time
      // your past ducks under it.
      [
        Move.right(2.0),
        Move(0.15),
        Move.left(0.65, jump: true),
        Move(0.5),
        Move.left(0.25),
        Move(0.3),
        Move.right(0.1),
        Move(0.15),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(1.75),
        Move(0.15),
        Move(1.0, crouch: true),
        Move(5.1),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // The right order, with a long look between the step and the key: the
      // step is more than six seconds before the key, and it is gone before
      // the dark falls on it.
      [
        Move.right(2.0),
        Move(0.15),
        Move.left(0.65, jump: true),
        Move(0.5),
        Move.right(0.95),
        Move(0.15),
        Move(1.0, crouch: true),
        Move(2.5),
        Move.left(1.2),
        Move(0.45),
        Move.left(0.55, jump: true),
        Move(0.2),
        Move.right(1.75),
        Move(0.15),
        Move(0.5, jump: true),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
    ],
    name: 'آخر ست ثواني',
    teaches: 'المفتاح بيطفي على آخر ست ثواني قبله. حط فيهم كل حاجة.',
    nameEn: 'The Last Six Seconds',
    teachesEn:
        'The key puts out the last six seconds before it. Fit everything in.',
    delaySeconds: 6,
    spawnX: -200,
    floorTop: _floor,
    blocks: [
      _ground(-600, 1240),
      const Rect.fromLTRB(-640, 200, -600, 620),
      // The key's balcony, in the dark.
      const Rect.fromLTRB(-80, 506, 20, 522),
      // The plate's balcony, under the lamp. Up out of the way, because on
      // the floor it was on the walk to the key, and your past walking over
      // it in the dark was a press nobody chose.
      const Rect.fromLTRB(100, 506, 180, 522),
      const Rect.fromLTRB(400, 430, 1200, 620),
      const Rect.fromLTRB(1200, 170, 1240, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(80, 200, 400, 620), id: 'lamp')],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-70, 494, 10, 506), flips: 'lamp'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(100, 494, 140, 506), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(800, 170, 826, 430),
        lingerSeconds: 5,
      ),
    ],
    goal: const Rect.fromLTRB(1000, 358, 1080, 430),
  );

  /// **Phase 12, the light switch, a chain.** Three plates, and each one's
  /// press is only there in the dark the one before it makes.
  ///
  /// The gate's plate is under a lamp; the switch that puts it out is under
  /// another; and the plate that puts *that* out is yours, a step up beside
  /// the gate's plate. So at one moment: you on yours, a past on the switch,
  /// a past on the gate's plate. Which past goes where is not a choice — the
  /// switch is more than two seconds from your plate, so it has to be the
  /// far one; and it is further from the gate than the gate's grace, so you
  /// cannot hold it yourself and run. In your own time: the switch, the
  /// plate, yours, and then the gate on its grace.
  ///
  /// It is `oneHoldsTheDark` with the roles turned over and one more link,
  /// and that link is you: yours is the only plate nothing but you can be on.
  static final Level aChainOfDark = Level(
    id: 'a-chain-of-dark',
    solution: const [
      Move.left(3.05), // the wrong way, all the way to the far end
      Move(0.45),
      Move.left(0.6, jump: true), // up onto the first switch
      Move(1.7), // stand on it: the far past will, six seconds on
      Move.right(1.25),
      Move(0.45),
      Move.right(0.6, jump: true), // onto the gate's plate
      Move(0.9), // the near past will stand here, two seconds on
      Move.right(0.15),
      Move(0.15),
      Move.right(0.55, jump: true), // a step up, onto your own
      Move.right(0.2),
      Move(0.3), // the lamps go out one after the other, and the gate opens
      Move.right(4), // and its grace is long enough to get there
    ],
    wrongIdeas: const [
      // Your own plate first, as if a past could hold it too. Then all three
      // plates want a past on them while you are at the gate, and you have
      // two.
      [
        Move.left(1.4),
        Move(0.4),
        Move.left(0.55, jump: true),
        Move.right(0.1),
        Move(0.15),
        Move.right(0.55, jump: true),
        Move.right(0.2),
        Move(1.65),
        Move.left(2.25),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.6),
        Move.right(1.25),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(1.1),
        Move.right(2.25),
        Move(6.15),
        Move.right(4),
      ],
      // The switch and the plate in the right order, and straight to the
      // gate. The switch is under a lamp of its own: with nobody on your
      // plate, the far past on it is erased, and nothing puts the next out.
      [
        Move.left(3.05),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.7),
        Move.right(1.25),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(0.9),
        Move.right(6),
      ],
      // Hold the switch yourself, with a past on the plate: the gate opens,
      // and the switch is too far from it to arrive inside its grace.
      [
        Move.left(2.25),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(1.15),
        Move.left(1.25),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.75),
        Move.right(7),
      ],
    ],
    name: 'سلسلة الضلمة',
    teaches: 'انت تطفي على البعيد، والبعيد يطفي على القريب.',
    nameEn: 'A Chain of Dark',
    teachesEn:
        'You put out the far past\'s lamp, and it puts out the near one\'s.',
    delays: const [2, 6],
    spawnX: 200,
    floorTop: _floor,
    blocks: [
      _ground(-860, 700),
      const Rect.fromLTRB(-900, 200, -860, 620),
      // The first switch, far from everything and under its own lamp.
      const Rect.fromLTRB(-620, 506, -520, 522),
      // The gate's plate, under the lamp the first switch puts out.
      const Rect.fromLTRB(-250, 506, -150, 522),
      // Yours, a step up from the gate's plate: walking off that balcony to
      // the gate goes under it, so nobody is ever on it without meaning to.
      const Rect.fromLTRB(-60, 450, 40, 466),
    ],
    lights: const [
      LightSpec(Rect.fromLTRB(-650, 200, -490, 620), id: 'switch-lamp'),
      LightSpec(Rect.fromLTRB(-280, 200, -120, 620), id: 'plate-lamp'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-610, 494, -530, 506), opens: 'plate-lamp'),
      PlateSpec(area: Rect.fromLTRB(-240, 494, -160, 506), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(-50, 438, 30, 450), opens: 'switch-lamp'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(400, 150, 426, 620),
        lingerSeconds: 3.5,
      ),
    ],
    goal: const Rect.fromLTRB(550, 548, 630, 620),
  );

  /// **Phase 12, the light switch, three again.** `oneHoldsTheDark` with
  /// the roles turned round: the switch for the far past, and the near one
  /// is the step under the lamp.
  ///
  /// The shelf is climbed from its foot, under a lamp a plate on the balcony
  /// puts out. A step there needs the lamp out while you climb it, and you
  /// cannot be on the switch and on the step. With two pasts, one is each —
  /// but which is which is not a choice: from the switch to the foot is most
  /// of two seconds, so the near past on the switch is gone again before you
  /// are up. The far one stands there for as long as you did, so: the switch
  /// first and long, then the duck, then up onto it two seconds later.
  ///
  /// How long you ducked is how long you can stop before climbing.
  static final Level oneIsTheStep = Level(
    id: 'one-is-the-step',
    solution: const [
      Move.right(0.95), // to the foot of the switch's balcony
      Move(0.45),
      Move.right(0.6, jump: true), // up onto the switch
      Move(2.6), // and stand: the far past will, six seconds on
      Move.right(1.4), // to the foot of the shelf, under the lamp
      Move(0.15),
      Move(1.0, crouch: true), // duck: the near past will, two seconds on
      Move.left(0.25), // a step back
      Move(0.85), // and wait for it
      Move.right(0.55, jump: true), // onto it, in the dark the far one holds
      Move(0.1),
      Move.right(0.9, jump: true), // and onto the shelf
      Move.right(4),
    ],
    wrongIdeas: const [
      // The roles `oneHoldsTheDark` taught: the far past on the thing under
      // the lamp, the near one on the switch. The walk from the switch to
      // the shelf is most of the two seconds, and the near past is off the
      // switch again before you are up.
      [
        Move.right(2.8),
        Move(0.15),
        Move(1.5, crouch: true),
        Move.left(1.85),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(1.65),
        Move.right(1.15),
        Move(0.15),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // No switch: a step under the lamp, and wait for it.
      [
        Move.right(2.8),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // The switch touched on the way: the far past is on it for as long as
      // you were, and that is over before the near one ducks.
      [
        Move.right(0.95),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(0.45),
        Move.right(1.4),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
    ],
    name: 'واحد يطفي والتاني سلّمة',
    teaches: 'ماضيك اتنين: واحد يطفي النور، والتاني تطلع عليه.',
    nameEn: 'One Holds the Dark, One Is the Step',
    teachesEn:
        'Your past is two: one puts the lamp out, the other is what you climb.',
    delays: const [2, 6],
    spawnX: -250,
    floorTop: _floor,
    blocks: [
      _ground(-500, 1240),
      const Rect.fromLTRB(-540, 200, -500, 620),
      // The switch, up out of the way, in the dark.
      const Rect.fromLTRB(0, 506, 100, 522),
      const Rect.fromLTRB(400, 430, 1200, 620),
      const Rect.fromLTRB(1200, 170, 1240, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(170, 200, 400, 620), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(10, 494, 90, 506), opens: 'lamp'),
    ],
    goal: const Rect.fromLTRB(1000, 358, 1080, 430),
  );

  /// **Phase 12, the light switch, the step.** One body, two jobs: your
  /// past ducked on the switch is the lamp going out and the way up at once.
  ///
  /// The gate on the ledge is held by a plate under the lamp, so a past on
  /// the plate is only there while somebody is on the switch. The ledge is
  /// out of a jump's reach from the switch's balcony and in a step's. So the
  /// near past ducks on the switch — a step, and the dark — and the far past
  /// is on the plate in that dark. The plate first and long, then the duck,
  /// then up onto it two seconds later, and through on the gate's grace.
  ///
  /// Stand on the switch yourself and the gate opens below a ledge you
  /// cannot reach; make the step without the plate and you are up at a shut
  /// gate. The other way round, the plate is too far from the switch for the
  /// near past to be on it.
  static final Level yourStepIsTheSwitch = Level(
    id: 'your-step-is-the-switch',
    solution: const [
      Move.right(0.5), // toward the plate's balcony
      Move(0.4),
      Move.right(0.6, jump: true), // up onto the plate, under the lamp
      Move(1.6), // and stand: the far past will, six seconds on
      Move.right(0.95), // to the foot of the switch's balcony
      Move(0.4),
      Move.right(0.7, jump: true), // up, and along onto the switch
      Move(0.1),
      Move(1.5, crouch: true), // duck on it: the near past will, two on
      Move.left(0.25), // a step back
      Move(0.35),
      Move.right(0.15, jump: true), // onto it, and the lamp is out under you
      Move(0.45),
      Move.right(0.9, jump: true), // up onto the ledge
      Move.right(4), // and through the gate the far past is holding
    ],
    wrongIdeas: const [
      // Hold the switch yourself: the lamp goes out, the far past is on the
      // plate and the gate opens — and there is nothing to climb.
      [
        Move.right(0.5),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(1.6),
        Move.right(0.95),
        Move(0.4),
        Move.right(0.7, jump: true),
        Move(2.6),
        Move.left(0.25),
        Move(0.1),
        Move.right(0.15, jump: true),
        Move(0.45),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // The other way round: the step on the switch first, for the far
      // past, and the plate after it for the near one. The plate is more
      // than two seconds from the switch.
      [
        Move.right(1.85),
        Move(0.45),
        Move.right(0.7, jump: true),
        Move(0.1),
        Move(1.5, crouch: true),
        Move.left(1.9),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(1.15),
        Move.right(0.95),
        Move(0.4),
        Move.right(0.55, jump: true),
        Move.left(0.15),
        Move(0.1),
        Move.right(0.15, jump: true),
        Move(0.45),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // No plate: the step on the switch, up onto the ledge, and the gate
      // has nobody holding it.
      [
        Move.right(1.85),
        Move(0.45),
        Move.right(0.7, jump: true),
        Move(0.1),
        Move(1.5, crouch: true),
        Move.left(0.25),
        Move(0.35),
        Move.right(0.15, jump: true),
        Move(0.45),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
    ],
    name: 'سلّمتك هي المطفي',
    teaches: 'ماضيك الواطي على المطفي سلّمة، والنور مطفي وهو تحتك.',
    nameEn: 'Your Step Is the Switch',
    teachesEn: 'Your past ducked on the switch is a step, and the dark.',
    delays: const [2, 6],
    spawnX: -300,
    floorTop: _floor,
    blocks: [
      _ground(-500, 900),
      const Rect.fromLTRB(-540, 200, -500, 620),
      // The gate's plate, under the lamp.
      const Rect.fromLTRB(-150, 506, -50, 522),
      // The switch, in the dark, under the end of the ledge.
      const Rect.fromLTRB(150, 506, 300, 522),
      // The ledge: out of a jump's reach from the switch, in a step's.
      const Rect.fromLTRB(300, 320, 900, 336),
      const Rect.fromLTRB(900, -100, 940, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(-180, 200, -20, 620), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-140, 494, -60, 506), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(170, 494, 290, 506), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(560, -40, 586, 320),
        lingerSeconds: 2.5,
      ),
    ],
    goal: const Rect.fromLTRB(760, 248, 840, 320),
  );

  /// **Phase 12, the light switch, two rooms.** The far past has two jobs,
  /// one after the other, and both are in the first room.
  ///
  /// The gate between the rooms is held by a plate at the far end of the
  /// first, and the lamp over the second room's step is put out by a switch
  /// by the gate — in the first room too. So six seconds after you, your
  /// far past opens the gate for you, and a few seconds after that it is on
  /// the switch, holding the dark over the step the near past is making two
  /// seconds after you. The plate, then the switch for long enough, then the
  /// duck, then the climb.
  ///
  /// The switch is close to the step on purpose: touch it on your way past
  /// and the far past has been and gone before you are climbing. Standing
  /// on it is the whole of it. The gate is tall because a stair of both
  /// pasts on the switch's balcony gets your feet to 232.
  static final Level theFarOneTwice = Level(
    id: 'the-far-one-twice',
    solution: const [
      Move.left(1.6), // the wrong way, to the far end
      Move(0.45),
      Move.left(0.6, jump: true), // up onto the gate's plate
      Move(1.15), // the far past will stand here, six seconds on
      Move.right(0.45),
      Move(0.1),
      Move.right(2.15), // back to the switch by the gate
      Move(0.4),
      Move.right(0.6, jump: true), // up onto it
      Move(2.15), // and stand: the far past will, after the plate
      Move.right(1.6), // through the gate its first job is holding
      Move(0.15),
      Move(1.0, crouch: true), // duck at the foot: the near past will
      Move.left(0.25),
      Move(0.85),
      Move.right(0.55, jump: true), // onto it, in the dark of its second job
      Move(0.1),
      Move.right(0.9, jump: true),
      Move.right(5),
    ],
    wrongIdeas: const [
      // The switch first, as the room it is in suggests, then the plate. The
      // far past is on the switch while you are still in the first room, and
      // on the plate long after you needed it.
      [
        Move.right(0.65),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(2.15),
        Move.left(2.7),
        Move(0.4),
        Move.left(0.6, jump: true),
        Move(1.65),
        Move.right(4.75),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(5),
      ],
      // The plate, and straight through: the next room's switch is never
      // stood on, and its lamp is lit over the step.
      [
        Move.left(1.6),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.15),
        Move.right(4.75),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(5),
      ],
      // The switch touched on the way: the far past is on it for a moment,
      // and that moment is long over when you are at the step.
      [
        Move.left(1.6),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.15),
        Move.right(0.45),
        Move(0.1),
        Move.right(2.15),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(0.45),
        Move.right(2.1),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(5),
      ],
    ],
    name: 'البعيد بيشتغل مرتين',
    teaches: 'البعيد يفتحلك الباب، وبعدين يطفيلك نور الأوضة الجاية.',
    nameEn: 'The Far One Works Twice',
    teachesEn: 'The far past opens the gate, then holds the next room dark.',
    delays: const [2, 6],
    spawnX: -300,
    floorTop: _floor,
    blocks: [
      _ground(-900, 1500),
      const Rect.fromLTRB(-940, 200, -900, 620),
      // The gate's plate, at the far end of the first room.
      const Rect.fromLTRB(-800, 506, -700, 522),
      // The next room's switch, by the gate. The gate is tall for it: a
      // stair of both pasts up here gets your feet to 232.
      const Rect.fromLTRB(-110, 506, -10, 522),
      const Rect.fromLTRB(330, 430, 1500, 620),
      const Rect.fromLTRB(1500, 170, 1540, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(100, 200, 330, 620), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-790, 494, -710, 506), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(-100, 494, -20, 506), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(0, 150, 26, 620),
        lingerSeconds: 2,
      ),
    ],
    goal: const Rect.fromLTRB(1200, 358, 1280, 430),
  );

  /// **Phase 12, the light switch, behind you.** `yourPastsDark` with the
  /// key in the room you have left.
  ///
  /// The step is in the second room, under a lamp, and the key that puts it
  /// out is in the first, by the gate. The key puts out the six seconds
  /// before it, so the step has to come first: through the gate, duck, back
  /// through it to the key, and through again to climb. The gate is held by
  /// your past on a plate at the far end of the first room, with a grace, so
  /// it is open for all three crossings only if you stood there long — touch
  /// the plate and it shuts you in with the step and without the key.
  ///
  /// Every key before this one was thrown on the way. This one is on the way
  /// too, which is the trap.
  static final Level theKeyBehindYou = Level(
    id: 'the-key-behind-you',
    solution: const [
      Move.left(0.7), // the wrong way, to the foot of the gate's plate
      Move(0.45),
      Move.left(0.6, jump: true), // up onto it
      Move(4.0), // and stand, long: the gate will be open as long, and more
      Move.right(2.35), // to the gate
      Move(0.15), // open: your past is on the plate
      Move.right(1.45), // through, to the foot of the shelf
      Move(0.15),
      Move(1.0, crouch: true), // duck: the step, before the key
      Move.left(1.15), // back through the gate
      Move(0.45),
      Move.left(0.6, jump: true), // up onto the key: the dark falls on the
      Move(0.3), // last six seconds, and the step is in them
      Move.right(1.35), // through the gate again
      Move(1.2), // and wait for the step
      Move.right(0.55, jump: true),
      Move(0.1),
      Move.right(0.9, jump: true),
      Move.right(5),
    ],
    wrongIdeas: const [
      // The key first, on the way, as every key before it: the dark falls
      // over the walk to the plate, and is gone again before the step.
      [
        Move.right(0.65),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(0.3),
        Move.left(1.8),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(3.1),
        Move.right(2.35),
        Move(0.65),
        Move.right(1.45),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(4.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(5),
      ],
      // The right order, but the plate only touched: the gate lets you
      // through once, and is shut when you turn back for the key.
      [
        Move.left(0.7),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(0.6),
        Move.right(2.35),
        Move(3.15),
        Move.right(1.45),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(1.15),
        Move(0.45),
        Move.left(0.55, jump: true),
        Move.left(5),
        Move(0.3),
        Move.right(1.1),
        Move(0.15),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(5),
      ],
      // No key: the step under the lamp, and wait for it.
      [
        Move.left(0.7),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(3.1),
        Move.right(2.35),
        Move(0.65),
        Move.right(1.45),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(4.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(5),
      ],
    ],
    name: 'المفتاح ورا ضهرك',
    teaches: 'السلّمة قدّام والمفتاح ورا: اعمل السلّمة، وارجع للمفتاح.',
    nameEn: 'The Key Behind You',
    teachesEn:
        'The step is ahead and the key behind: the step first, then back.',
    delaySeconds: 6,
    spawnX: -300,
    floorTop: _floor,
    blocks: [
      _ground(-700, 1400),
      const Rect.fromLTRB(-740, 200, -700, 620),
      // The gate's plate, at the far end of the first room.
      const Rect.fromLTRB(-600, 506, -500, 522),
      // The key to the next room's lamp, by the gate, in this room.
      const Rect.fromLTRB(-110, 506, -10, 522),
      const Rect.fromLTRB(330, 430, 1400, 620),
      const Rect.fromLTRB(1400, 170, 1440, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(100, 200, 330, 620), id: 'lamp')],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-100, 494, -20, 506), flips: 'lamp'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-590, 494, -510, 506), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(0, 260, 26, 620),
        lingerSeconds: 3.5,
      ),
    ],
    goal: const Rect.fromLTRB(1100, 358, 1180, 430),
  );

  /// **Phase 12, the light switch, a chain through the gate.**
  /// `aChainOfDark` with the gate in the middle of it, and the far past
  /// working twice as in `theFarOneTwice`.
  ///
  /// At the moment you leave: you are on your plate in the second room,
  /// which puts out the lamp back in the first, over the switch for the
  /// second room's lamp; the far past is on that switch, so the lamp over
  /// the last gate's plate is out; and the near past is on that plate. So
  /// the plate at the far end of the first room (the far past holds the
  /// first gate a little later), the switch for long enough, through, the
  /// last plate, a step up onto yours, and out on the last gate's grace.
  ///
  /// The roles are not a choice: the switch is too far from your plate for
  /// the near past, and the first gate's plate too far from the gate for it.
  /// The switch's lamp comes right up to the first gate, so no stair can be
  /// built against it.
  static final Level aChainThroughTheGate = Level(
    id: 'a-chain-through-the-gate',
    solution: const [
      Move.left(2.55), // the wrong way, to the first gate's plate
      Move(0.45),
      Move.left(0.6, jump: true), // up onto it
      Move(1.6), // the far past will stand here, six seconds on
      Move.right(0.45),
      Move(0.1),
      Move.right(1.9), // back, to the switch for the next room
      Move(0.45),
      Move.right(0.6, jump: true), // up onto it, under its own lamp
      Move(2.1), // and stand: the far past will, after the plate
      Move.right(0.4), // down to the gate: the far past is on its plate
      Move(0.15),
      Move.right(0.55), // through, to the foot of the next plate
      Move(0.4),
      Move.right(0.6, jump: true), // up onto it, under the next room's lamp
      Move(0.9), // the near past will stand here, two seconds on
      Move.right(0.15),
      Move(0.15),
      Move.right(0.55, jump: true), // a step up, onto yours
      Move.right(0.25),
      Move(0.2), // both lamps go out, one for the other, and the gate opens
      Move.right(5), // and its grace gets you there
    ],
    wrongIdeas: const [
      // The first room's plate and the second room's two, but not the switch
      // back in the first: nobody puts out the lamp over the last plate.
      [
        Move.left(2.55),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.6),
        Move.right(3.3),
        Move(0.15),
        Move.right(0.6),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(0.9),
        Move.right(0.15),
        Move(0.15),
        Move.right(0.55, jump: true),
        Move.right(0.25),
        Move(2.15),
        Move.right(5),
      ],
      // The switch first, as it is on the way, then the plate. The far past
      // is on the switch long before you are on yours, and on the first
      // gate's plate only after you needed it.
      [
        Move.right(0.35),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(2.1),
        Move.left(2.45),
        Move(0.4),
        Move.left(0.6, jump: true),
        Move(1.6),
        Move.right(3.3),
        Move(0.15),
        Move.right(0.6),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(0.9),
        Move.right(0.15),
        Move(0.15),
        Move.right(0.55, jump: true),
        Move.right(0.25),
        Move(2.15),
        Move.right(5),
      ],
      // Everything but your own plate: the switch is under a lamp, and only
      // you, from here, can put it out.
      [
        Move.left(2.55),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.6),
        Move.right(0.45),
        Move(0.1),
        Move.right(1.9),
        Move(0.45),
        Move.right(0.6, jump: true),
        Move(2.1),
        Move.right(0.4),
        Move(0.15),
        Move.right(0.55),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(0.9),
        Move.right(2.6),
        Move(3.15),
        Move.right(5),
      ],
    ],
    name: 'سلسلة من ورا الباب',
    teaches: 'زرارك هنا بيطفي ورا الباب، واللي ورا الباب بيطفي هنا.',
    nameEn: 'A Chain Through the Gate',
    teachesEn: 'Your plate here puts out the room behind; that one, this one.',
    delays: const [2, 6],
    spawnX: -100,
    floorTop: _floor,
    blocks: [
      _ground(-900, 1100),
      const Rect.fromLTRB(-940, 200, -900, 620),
      // The first gate's plate, at the far end of the first room.
      const Rect.fromLTRB(-800, 506, -700, 522),
      // The switch for the second room's lamp, under a lamp of its own.
      const Rect.fromLTRB(-170, 506, -70, 522),
      // The second gate's plate, under the second room's lamp.
      const Rect.fromLTRB(150, 506, 250, 522),
      // Yours: puts out the lamp back in the first room.
      const Rect.fromLTRB(350, 506, 450, 522),
    ],
    lights: const [
      LightSpec(Rect.fromLTRB(-200, 200, -40, 620), id: 'switch-lamp'),
      LightSpec(Rect.fromLTRB(120, 200, 280, 620), id: 'plate-lamp'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-790, 494, -710, 506), opens: 'first'),
      PlateSpec(area: Rect.fromLTRB(-160, 494, -80, 506), opens: 'plate-lamp'),
      PlateSpec(area: Rect.fromLTRB(160, 494, 240, 506), opens: 'last'),
      PlateSpec(area: Rect.fromLTRB(360, 494, 440, 506), opens: 'switch-lamp'),
    ],
    doors: const [
      DoorSpec(
        id: 'first',
        closed: Rect.fromLTRB(0, 150, 26, 620),
        lingerSeconds: 1.5,
      ),
      DoorSpec(
        id: 'last',
        closed: Rect.fromLTRB(800, 150, 826, 620),
        lingerSeconds: 3,
      ),
    ],
    goal: const Rect.fromLTRB(950, 548, 1030, 620),
  );

  /// **Phase 12, the light switch, the last switch is you.** The sequel to
  /// `theFarOneTwice`, and its answer is the first wrong idea.
  ///
  /// The far past's dark ends six seconds after you leave its switch, however
  /// long you stood there — and the climb takes most of that. So on the
  /// shelf, where the last gate's plate is under the same lamp, the far past
  /// has gone and the lamp is lit again. The lamp has a second switch up
  /// there: you hold it, and the near past stands on the plate in your dark.
  /// The first room as before, the climb, the plate, then the switch until
  /// the gate opens, and out on its grace.
  ///
  /// This level was first drawn with one switch for both jobs. It cannot be
  /// done: from leaving the switch to the near past on the plate is seven
  /// seconds, and nothing stretches the six.
  static final Level youHoldTheLast = Level(
    id: 'you-hold-the-last',
    solution: const [
      Move.left(1.6), // the wrong way, to the first gate's plate
      Move(0.45),
      Move.left(0.6, jump: true), // up onto it
      Move(1.25), // the far past will stand here, six seconds on
      Move.right(0.45),
      Move(0.1),
      Move.right(2.15), // back to the switch by the gate
      Move(0.4),
      Move.right(0.6, jump: true), // up onto it
      Move(2.25), // and stand: the far past will, for the climb
      Move.right(0.15),
      Move(0.15),
      Move.right(1.45), // through, to the foot of the shelf
      Move(0.15),
      Move(1.0, crouch: true), // duck: the near past will
      Move.left(0.25),
      Move(0.85),
      Move.right(0.55, jump: true), // onto it, in the far past's dark
      Move(0.1),
      Move.right(0.9, jump: true), // and up
      Move.right(0.1),
      Move(0.65), // onto the last gate's plate: the near past will stand here
      Move.right(0.65), // to the lamp's other switch, and hold it yourself
      Move(0.9), // until the near past is on the plate in your dark
      Move.right(4), // and out on the gate's grace
    ],
    wrongIdeas: const [
      // The last level's answer: the far past holds the dark, you climb —
      // and walk to a gate whose plate nobody is on.
      [
        Move.left(1.6),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.25),
        Move.right(0.45),
        Move(0.1),
        Move.right(2.15),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(2.25),
        Move.right(0.15),
        Move(0.15),
        Move.right(1.45),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(4),
      ],
      // The plate up there, and on to the gate: the far past's dark was
      // over six seconds after you left its switch, and nobody holds it now.
      [
        Move.left(1.6),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.25),
        Move.right(0.45),
        Move(0.1),
        Move.right(2.15),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(2.25),
        Move.right(0.15),
        Move(0.15),
        Move.right(1.45),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(0.1),
        Move(0.65),
        Move.right(4),
      ],
      // The switch by the gate touched on the way: the far past has been and
      // gone before the near one ducks, and there is no climbing it.
      [
        Move.left(1.6),
        Move(0.45),
        Move.left(0.6, jump: true),
        Move(1.25),
        Move.right(0.45),
        Move(0.1),
        Move.right(2.15),
        Move(0.4),
        Move.right(0.6, jump: true),
        Move(0.45),
        Move.right(0.15),
        Move(0.15),
        Move.right(1.45),
        Move(0.15),
        Move(1.0, crouch: true),
        Move.left(0.25),
        Move(0.85),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.9, jump: true),
        Move.right(0.1),
        Move(0.65),
        Move.right(0.65),
        Move(0.9),
        Move.right(4),
      ],
    ],
    name: 'انت المطفي الأخير',
    teaches: 'البعيد يطفي للسلّمة من ورا الباب، وانت تطفي للقريب فوق.',
    nameEn: 'You Hold the Last',
    teachesEn: 'The far past holds the dark for the climb; you, for the near.',
    delays: const [2, 6],
    spawnX: -300,
    floorTop: _floor,
    blocks: [
      _ground(-900, 1000),
      const Rect.fromLTRB(-940, 200, -900, 620),
      // The first gate's plate, at the far end of the first room.
      const Rect.fromLTRB(-800, 506, -700, 522),
      // A switch for the second room's lamp, by the gate, in the first room.
      const Rect.fromLTRB(-110, 506, -10, 522),
      const Rect.fromLTRB(330, 430, 1000, 620),
      const Rect.fromLTRB(1000, -100, 1040, 620),
    ],
    // One lamp over the foot of the shelf and the plate on top of it.
    lights: const [LightSpec(Rect.fromLTRB(100, 200, 520, 620), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-790, 494, -710, 506), opens: 'first'),
      PlateSpec(area: Rect.fromLTRB(-100, 494, -20, 506), opens: 'lamp'),
      PlateSpec(area: Rect.fromLTRB(420, 418, 500, 430), opens: 'last'),
      // The same lamp's other switch, up on the shelf, in the dark.
      PlateSpec(area: Rect.fromLTRB(560, 418, 640, 430), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(
        id: 'first',
        closed: Rect.fromLTRB(0, 150, 26, 620),
        lingerSeconds: 3,
      ),
      DoorSpec(
        id: 'last',
        closed: Rect.fromLTRB(760, 70, 786, 430),
        lingerSeconds: 1.5,
      ),
    ],
    goal: const Rect.fromLTRB(880, 358, 960, 430),
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
    stairOfYourself,
    underTheLight,
    yourPastShutsIt,
    threeGatesOnePast,
    allOfIt,
    inUnderBackOver,
    standToStay,
    theStepThatShuts,
    stairInTheDark,
    allOfItAgain,
    youHoldTheDark,
    yourPastsDark,
    theLastSixSeconds,
    oneHoldsTheDark,
    oneIsTheStep,
    yourStepIsTheSwitch,
    theThirdFlip,
    aChainOfDark,
    theKeyBehindYou,
    theFarOneTwice,
    youHoldTheLast,
    aChainThroughTheGate,
    allOfItInTheDark,
  ];

  /// The levels whose intended solution **is** one of the cheap runs
  /// (`cheapRuns` in `level_check.dart`), and which are therefore expected to
  /// fall to it.
  ///
  /// Not a list of things to fix. Each of these is a level whose lesson is
  /// that a small deliberate act, done early, is enough — pressing a plate on
  /// your way past and walking on (`press-it-early`), stepping onto one and
  /// throwing yourself off a ledge (`take-it-with-you`), brushing a key and
  /// leaving before your past shuts it (`close-what-you-opened`). A sweep
  /// that finishes them is the sweep agreeing with the design.
  ///
  /// It is a list that should only ever get shorter, and it is the campaign's
  /// alone: a level from outside cannot be on it, so the gate refuses any
  /// level a cheap run finishes. Adding to it means deciding a level is meant
  /// to be finishable without thought, which is a thing to argue about rather
  /// than to do while fixing something else.
  static const Set<String> cheapByDesign = {
    'press-it-early',
    'take-it-with-you',
    'close-what-you-opened',
  };

  /// The Phase 2 tuning bench, as a level so it runs on the same code as the
  /// puzzles. Not part of the campaign: it is where the numbers get argued
  /// with, not somewhere to be finished.
  /// **Level zero: that's you.** On the bench, not in the campaign — it uses
  /// [Level.prelude], which is still on trial (`docs/lab.md` §1).
  ///
  /// The first review of the game said the line under the name was not
  /// understood, and a line was the only thing explaining the game. This one
  /// is explained by a picture: the level opens with a pale body already
  /// walking — standing on the plate under your feet, then walking through
  /// the door your weight is holding open. Move, and it is gone; two seconds
  /// later a new one comes out of the spawn and does exactly what you did.
  ///
  /// The puzzle is the first level's sentence made as small as it goes: the
  /// plate is under the spawn and the door is ahead. Your own weight opens it
  /// only while you stand there, so walking straight at it finds it shut —
  /// unless you stood long enough first for your past to be on the plate when
  /// you arrive. The demonstration is the solution, shown once, in a body the
  /// player then watches turn into their own.
  ///
  /// **Before it can join the campaign** it needs playing by hand, and one
  /// more line: `miserly_test` sweeps «wait for your shadow, then hold the way
  /// out», and here that *is* the lesson, so it joins [cheapByDesign] the day
  /// it is promoted — the waiting the other levels assume is what this one
  /// teaches.
  static final Level thatsYou = Level(
    id: 'thats-you',
    solution: const [
      Move(1.5), // stand where you are: the plate is under you
      Move.right(3.0), // to the door, which your past is holding now
    ],
    wrongIdeas: const [
      // Straight at the door: it was only open while you stood still.
      [Move.right(6)],
    ],
    prelude: const [Move(1.5), Move.right(3.0)],
    name: 'ده انت',
    teaches: 'الفاتح ده انت. اتحرك، وبعد ثانيتين هيعمل زيك.',
    nameEn: "That's You",
    teachesEn:
        'The pale one is you. Move, and two seconds later it does what you did.',
    delaySeconds: 2,
    spawnX: 0,
    floorTop: _floor,
    blocks: [_ground(-700, 900)],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-30, 608, 30, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(300, 360, 326, 620)),
    ],
    goal: const Rect.fromLTRB(420, 548, 500, 620),
  );

  /// The levels that draw a lit edge on a past you can stand on.
  ///
  /// One: the level that teaches the step. Every surface you can stand on
  /// has a lit top edge, and putting one on your ducked past says *this is
  /// a floor now* without a word — where that is the lesson. Everywhere
  /// after, working out which of your pasts will hold you is part of the
  /// puzzle, and an edge pointing at it would be solving it for the player.
  /// Asked for after playing.
  ///
  /// Only levels whose recorded solution actually stands on a past belong
  /// here; `step_edge_test.dart` holds that.
  static const Set<String> showsSteps = {'stand-on-yourself'};

  /// **Phase 12, the light switch, one.** You are the helper.
  ///
  /// The plate that holds the gate is under a lamp, and your past in a lamp
  /// is nothing — so for eleven levels a plate under a light was a plate only
  /// you could press. Now there is a switch for the lamp, on a balcony in the
  /// dark, and the level turns the game's sentence round: stand on the plate,
  /// walk away, and then **you** stand somewhere useless — the switch — while
  /// your past does the work in the dark you made for it. Step off and the
  /// lamp is lit, your past is gone, and the gate's grace is what you run on.
  ///
  /// The grace starts when your past steps off the plate, so it has to cover
  /// the switch you are still standing on as well as the walk: four seconds,
  /// enough for a short press held a while.
  static final Level youHoldTheDark = Level(
    id: 'you-hold-the-dark',
    solution: const [
      Move.left(1.75), // to the plate under the lamp
      Move(1.0), // stand on it: your past will, in the light
      Move.right(2.45), // to the foot of the balcony
      Move.right(0.55, jump: true), // up onto the switch
      Move.right(0.15),
      Move(1.5), // stand: the lamp is out, and your past is on the plate
      Move.right(4), // off, and through while the gate lingers
    ],
    wrongIdeas: const [
      // The plate, and then the gate, as every plate before it. Your past
      // arrives in the light and holds nothing.
      [Move.left(1.75), Move(1.0), Move.right(6)],
      // The switch first, then the plate. Your past puts the lamp out, but by
      // the time it walks to the plate it has stepped off the switch.
      [
        Move.right(0.75),
        Move.right(0.55, jump: true),
        Move(1.0),
        Move.left(2.75),
        Move(1.5),
        Move.right(6),
      ],
    ],
    name: 'انت اللي مطفّيه',
    teaches: 'الزرار تحت النور. اقف انت في الضلمة، وماضيك يدوسه.',
    nameEn: 'You Hold the Dark',
    teachesEn:
        'The button is under the lamp. Stand in the dark; your past '
        'presses it.',
    delaySeconds: 4,
    spawnX: -100,
    floorTop: _floor,
    blocks: [
      _ground(-700, 800),
      const Rect.fromLTRB(-740, 200, -700, 620),
      const Rect.fromLTRB(100, 506, 200, 522),
    ],
    lights: const [LightSpec(Rect.fromLTRB(-520, 200, -380, 620), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-500, 608, -400, 620), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(110, 494, 190, 506), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(
        id: 'gate',
        closed: Rect.fromLTRB(500, 360, 526, 620),
        lingerSeconds: 4,
      ),
    ],
    goal: const Rect.fromLTRB(650, 548, 730, 620),
  );

  /// **Phase 12, the light switch, two.** A key puts the lamp out for
  /// exactly as long as your past takes to reach it — and that is the
  /// stretch of your past from **before** you threw it.
  ///
  /// The shelf can only be climbed from its foot, and its foot is under a
  /// lamp: a step there is erased. The key on the balcony puts the lamp out
  /// until your past arrives on the key and throws it back, D seconds later.
  /// In those D seconds your past is replaying what you did in the D seconds
  /// before the key. So the step has to be there already: duck at the foot,
  /// then go and throw the key, then come back and climb.
  ///
  /// The order every level teaches — make the thing that opens the way, then
  /// use it — is the wrong one again: throw the key first and the lamp is out
  /// over your walk to the shelf, and back on before the step you then leave
  /// arrives. It is `theStepThatShuts` with a lamp instead of a button, which
  /// is the point: the same order, for a different reason.
  static final Level yourPastsDark = Level(
    id: 'your-pasts-dark',
    solution: const [
      Move.right(2.45), // under the lamp, to the foot of the shelf
      Move(1.0, crouch: true), // duck: a step the lamp will erase
      Move.left(0.8), // back to the balcony
      Move.left(0.55, jump: true), // up onto the key
      Move.left(0.1),
      Move(0.2), // the lamp goes out, over the last few seconds of you
      Move.right(0.6),
      Move(1.0),
      Move.right(0.25),
      Move.right(0.55, jump: true), // onto your own head
      Move(0.1),
      Move.right(0.7, jump: true), // onto the shelf
      Move.right(3),
    ],
    wrongIdeas: const [
      // The key first, so the lamp is out while you build the step. It is out
      // over what you did before the key — and the step is after it. By the
      // time your past ducks, the lamp is back on.
      [
        Move.right(0.75),
        Move.right(0.55, jump: true),
        Move(0.2),
        Move.right(1.1),
        Move(1.0, crouch: true),
        Move.left(0.5),
        Move(4.5),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(3),
      ],
      // The step in the dark, short of the lamp, where nothing erases it and
      // no key is needed. It is too far out to climb from.
      [
        Move.right(1.6),
        Move(1.0, crouch: true),
        Move(4.2), // stand where it will be, and wait for it under you
        Move(0.5, jump: true), // up onto it
        Move.right(0.9, jump: true), // and at the shelf
        Move.right(3),
      ],
      // No key at all: the step under the lamp, and wait for it.
      [
        Move.right(2.45),
        Move(1.0, crouch: true),
        Move.left(0.5),
        Move(4.5),
        Move.right(0.55, jump: true),
        Move(0.1),
        Move.right(0.7, jump: true),
        Move.right(3),
      ],
    ],
    name: 'ضلمة ماضيك',
    teaches: 'المفتاح بيطفي النور شوية — على اللي عملته قبله.',
    nameEn: 'Your Past\'s Dark',
    teachesEn:
        'The key puts the lamp out for a while — over what you did '
        'before it.',
    delaySeconds: 5,
    spawnX: -200,
    floorTop: _floor,
    blocks: [
      _ground(-600, 1240),
      const Rect.fromLTRB(-640, 200, -600, 620),
      const Rect.fromLTRB(0, 506, 100, 522),
      const Rect.fromLTRB(400, 430, 1200, 620),
      const Rect.fromLTRB(1200, 170, 1240, 620),
    ],
    lights: const [LightSpec(Rect.fromLTRB(220, 200, 400, 620), id: 'lamp')],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(10, 494, 90, 506), flips: 'lamp'),
    ],
    goal: const Rect.fromLTRB(1000, 358, 1080, 430),
  );

  /// **Phase 12, the light switch, three.** Two pasts, two jobs.
  ///
  /// The plate is under a lamp and the gate has no grace, so somebody has to
  /// be standing on the switch at the moment you walk through — and you are at
  /// the gate. With one past that cannot be done. With two, the near one
  /// holds the switch while the far one, four seconds further back, stands on
  /// the plate in the dark it is making. So: the plate first and long, then
  /// the switch, then the gate.
  ///
  /// The window is the overlap of the far past on the plate and the near one
  /// on the switch, and how long you stood on the plate is how wide it is:
  /// the lever `twoNotOne` taught, not a stopwatch. The switch is close to
  /// the plate because the walk between them comes straight off that window.
  static final Level oneHoldsTheDark = Level(
    id: 'one-holds-the-dark',
    solution: const [
      Move.left(2.3), // the wrong way, to the plate under the lamp
      // Stand on it, and long: how long is how wide the window will be.
      Move(2.0),
      Move.right(0.85), // back to the foot of the balcony
      Move.right(0.55, jump: true), // up onto the switch
      Move(1.6), // stand on it: the near past will, two seconds on
      Move.right(1.9), // to the gate, and wait for both of them
      Move(1.0),
      Move.right(1.5),
    ],
    wrongIdeas: const [
      // One past's way of doing it: hold the switch yourself until the gate
      // opens, then run for it. The moment you step off, the lamp is lit,
      // the past on the plate is gone, and the gate has no grace to give.
      [
        Move.left(2.3),
        Move(1.0),
        Move.right(0.85),
        Move.right(0.55, jump: true),
        Move(4.0),
        Move.right(4),
      ],
      // The switch first and then the plate. The near past would press it
      // and the far one hold the dark — but the plate is too far from the
      // gate to be there inside two seconds.
      [
        Move.left(0.6),
        Move.left(0.55, jump: true),
        Move.left(0.1),
        Move(1.0),
        Move.left(1.25),
        Move(1.0),
        Move.right(3.4),
        Move(4.0),
        Move.right(1.5),
      ],
    ],
    name: 'واحد يطفي وواحد يدوس',
    teaches: 'ماضيك اتنين: واحد يطفي النور، والتاني يدوس تحته.',
    nameEn: 'One Holds the Dark',
    teachesEn:
        'Your past is two: one puts the lamp out, the other presses under it.',
    delays: const [2, 6],
    spawnX: 100,
    floorTop: _floor,
    blocks: [
      _ground(-700, 600),
      const Rect.fromLTRB(-740, 200, -700, 620),
      const Rect.fromLTRB(-150, 506, -50, 522),
    ],
    lights: const [LightSpec(Rect.fromLTRB(-470, 200, -330, 620), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-450, 608, -350, 620), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(-140, 494, -60, 506), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(250, 260, 276, 620)),
    ],
    goal: const Rect.fromLTRB(400, 548, 480, 620),
  );

  /// Levels on the bench and not in the campaign: they use something still
  /// on trial. The editor's start menu offers them.
  static final List<Level> bench = [thatsYou];

  static final Level lab = Level(
    id: 'lab',
    name: 'الورشة',
    teaches: 'جرّب الأرقام. R يعيد المشهد.',
    nameEn: 'The Bench',
    teachesEn: 'Try the numbers. R starts over.',
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
