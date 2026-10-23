import 'dart:ui';

import 'level.dart';
import 'playthrough.dart';

/// The mirror's harder levels (`docs/phase-12-more.md` §9.4): each one the
/// mirror and something the campaign already taught, and longer than the
/// two that introduce it. On the bench with the mirror.
abstract final class MirrorLevels {
  /// **The mirror in the light.** The mirror is under a lamp, and a past in
  /// the light is not there — it arrives on the mirror and nothing happens.
  ///
  /// There are two buttons down past the edge: one for the door, one for
  /// the lamp. The habit from the first mirror level is to stand on the
  /// door's button until the mirror takes you back up, and here that is the
  /// one thing that does not work: when your past reaches the mirror the
  /// lamp is on. So the door's button only needs a while, and it is the
  /// lamp's you have to be standing on when your past gets there — and then
  /// your past does the door's for you, on its way.
  static final Level theMirrorInTheLight = Level(
    id: 'the-mirror-in-the-light',
    solution: const [
      Move.right(2.15), // over the mirror, off the edge, onto the door's
      Move(1.85), // a while
      Move.right(1.1), // to the lamp's, and stand
      Move(1.5), // until your past is on the mirror, in the dark
      Move.left(6), // back along the top, through
    ],
    wrongIdeas: const [
      // The first mirror level's answer: the door's button, until it takes
      // you back. Your past reaches the mirror in the light.
      [Move.right(2.15), Move(6), Move.left(6)],
      // The lamp's button only: you go up, and your past never goes near
      // the door's.
      [Move.right(3.2), Move(3), Move.left(6)],
    ],
    name: 'المراية في النور',
    teaches: 'المراية تحت اللمبة.',
    nameEn: 'The Mirror in the Light',
    teachesEn: 'The mirror is under the lamp.',
    delaySeconds: 5,
    spawnX: 0,
    floorTop: 400,
    blocks: [
      const Rect.fromLTRB(-700, 400, 300, 2200),
      const Rect.fromLTRB(300, 620, 1300, 2200),
      const Rect.fromLTRB(-740, 140, -700, 2200),
      const Rect.fromLTRB(1300, 140, 1340, 2200),
    ],
    mirrors: const [Rect.fromLTRB(150, 388, 210, 400)],
    lights: const [LightSpec(Rect.fromLTRB(110, 150, 250, 400), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(450, 608, 510, 620), opens: 'gate'),
      PlateSpec(area: Rect.fromLTRB(700, 608, 760, 620), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-300, 150, -274, 400)),
    ],
    goal: const Rect.fromLTRB(-450, 328, -370, 400),
  );

  /// **From behind the door.** The mirror is on the far side of a door your
  /// past holds open, and the button for the door beyond it is a long way
  /// back the other way.
  ///
  /// Without the mirror there is no order that works: by the time you have
  /// stood on the far button and walked back to the first door, your past
  /// has long since been and gone off its button, and you are the wrong side
  /// of a shut door. With it: through, onto the mirror, straight back out
  /// while the door is still held, all the way to the far button — and it
  /// puts you back on the far side, where your past then opens the last door
  /// for you from the other end of the level.
  static final Level fromBehindTheDoor = Level(
    id: 'from-behind-the-door',
    solution: const [
      Move.right(1.3), // onto the button by the first door
      Move(3.6), // long enough for there and back: your past holds it this long
      Move.right(0.6), // to the door, and wait for your past
      Move(1.4),
      Move.right(1.0), // through, and onto the mirror
      Move.left(3.9), // straight back out, and all the way to the far button
      Move(1.5), // until it takes you back
      Move.right(6), // through the last door, as your past stands back there
    ],
    wrongIdeas: const [
      // The far button first, then the near one, then through: your past
      // has left the far button long before you get to its door.
      [
        Move.left(1.6),
        Move(1.0),
        Move.right(2.75),
        Move(2.0),
        Move.right(0.6),
        Move(3.5),
        Move.right(6),
      ],
      // Through, and wait at the last door: nobody is on its button.
      [Move.right(1.3), Move(2.0), Move.right(0.6), Move(3.6), Move.right(8)],
    ],
    name: 'من ورا الباب',
    teaches: 'الباب بيقفل وراك.',
    nameEn: 'From Behind the Door',
    teachesEn: 'The door shuts behind you.',
    delaySeconds: 5.3,
    spawnX: -200,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1600, 620, 1600, 2200),
      const Rect.fromLTRB(-640, 200, -600, 620),
      const Rect.fromLTRB(800, 200, 840, 620),
    ],
    mirrors: const [Rect.fromLTRB(300, 608, 360, 620)],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(50, 608, 110, 620), opens: 'near'),
      PlateSpec(area: Rect.fromLTRB(-560, 608, -500, 620), opens: 'far'),
    ],
    doors: const [
      DoorSpec(id: 'near', closed: Rect.fromLTRB(150, 360, 176, 620)),
      DoorSpec(id: 'far', closed: Rect.fromLTRB(560, 360, 586, 620)),
    ],
    goal: const Rect.fromLTRB(680, 548, 760, 620),
  );

  /// **Open it late.** The door is opened by a key down past the edge, and
  /// your past, walking your way D seconds behind you, comes down and flips
  /// it shut again — D seconds after you opened it, whatever happens.
  ///
  /// The mirror takes you back up D seconds after you stood on *it*. So the
  /// time you have at the door is the time between the mirror and the key,
  /// and the key is right where you land: step straight onto it, as anybody
  /// would, and it shuts again before you are back across the top. Wait down
  /// there first. The later you open it, the later it closes.
  static final Level openItLate = Level(
    id: 'open-it-late',
    solution: const [
      Move.right(1.75), // over the mirror and off the edge, short of the key
      Move(2.0), // wait: the later you open it, the later it shuts
      Move.right(0.6), // onto the key, and stay
      Move(1.5), // until the mirror takes you back
      Move.left(6), // across the top and through
    ],
    wrongIdeas: const [
      // Straight onto the key, as anybody would: it is shut again before
      // you get back across.
      [Move.right(2.3), Move(4), Move.left(6)],
      // The wait, in the wrong place: up top, before the mirror. The time
      // you get is from the mirror to the key, and that is still none.
      [Move(2.5), Move.right(2.3), Move(4), Move.left(6)],
    ],
    name: 'المفتاح والمراية',
    teaches: 'خمس ثواني.',
    nameEn: 'The Key and the Mirror',
    teachesEn: 'Five seconds.',
    delaySeconds: 5,
    spawnX: 0,
    floorTop: 400,
    blocks: [
      const Rect.fromLTRB(-700, 400, 300, 2200),
      const Rect.fromLTRB(300, 620, 600, 2200),
      const Rect.fromLTRB(-740, 140, -700, 2200),
      // Hard against the key, so walking on past it is not a second flip.
      const Rect.fromLTRB(560, 140, 600, 620),
    ],
    mirrors: const [Rect.fromLTRB(150, 388, 210, 400)],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(460, 608, 540, 620), flips: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-300, 150, -274, 400)),
    ],
    goal: const Rect.fromLTRB(-450, 328, -370, 400),
  );

  /// **All of it in the mirror.** The last two at once: the mirror is under
  /// a lamp, and the door is a key's.
  ///
  /// Down past the edge the key is where you land and the lamp's button is
  /// further on. Two clocks, both started by you: the mirror takes you back
  /// D seconds after you stood on it — but only if you are holding the
  /// lamp out right then — and your past shuts the door D seconds after you
  /// opened it. So: wait short of the key, cross it late, and be on the
  /// lamp's button before your past reaches the mirror.
  static final Level allOfItInTheMirror = Level(
    id: 'all-of-it-in-the-mirror',
    solution: const [
      Move.right(1.75), // over the mirror, off the edge, short of the key
      Move(2.0), // wait: the door will shut D after the key
      Move.right(1.9), // over the key, on to the lamp's button
      Move(1.2), // until your past is on the mirror, in the dark
      Move.left(7), // across the top and through
    ],
    wrongIdeas: const [
      // Straight over the key to the lamp's button: back up in time, and
      // the door shuts before you get across.
      [Move.right(3.6), Move(3.5), Move.left(7)],
      // Late on the key, as in «افتحه متأخر», and stay on it: your past
      // reaches the mirror in the light.
      [Move.right(1.75), Move(2.0), Move.right(0.5), Move(5), Move.left(8)],
    ],
    name: 'كله في المراية',
    teaches: 'ساعتين بتبدأهم انت: المراية والمفتاح.',
    nameEn: 'All of It in the Mirror',
    teachesEn: 'Two clocks, and you start both: the mirror and the key.',
    delaySeconds: 6,
    spawnX: 0,
    floorTop: 400,
    blocks: [
      const Rect.fromLTRB(-900, 400, 300, 2200),
      const Rect.fromLTRB(300, 620, 1000, 2200),
      const Rect.fromLTRB(-940, 140, -900, 2200),
      const Rect.fromLTRB(1000, 140, 1040, 2200),
    ],
    mirrors: const [Rect.fromLTRB(150, 388, 210, 400)],
    lights: const [LightSpec(Rect.fromLTRB(110, 150, 250, 400), id: 'lamp')],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(460, 608, 540, 620), flips: 'gate'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(780, 608, 840, 620), opens: 'lamp'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-350, 150, -324, 400)),
    ],
    goal: const Rect.fromLTRB(-500, 328, -420, 400),
  );

  /// **Two of you, two returns.** With two pasts the mirror takes you back
  /// twice — once when the near one gets there, once when the far one does —
  /// and the mirror is under a lamp, so each return happens only if that
  /// past arrives in the dark.
  ///
  /// The near one gets there far too soon: if it takes you back, you are up
  /// top before anything is done. So the lamp has to be on for the near one
  /// and out for the far one: be on the lamp's button when the far one is
  /// due, and anywhere else when the near one is. And the door's button down
  /// there is a long way from the door, so it is held after you are back up
  /// by the far past — the one that brought you.
  static final Level twoOfYouTwoReturns = Level(
    id: 'two-of-you-two-returns',
    solution: const [
      Move.right(1.75), // over the mirror, off the edge, short of the lamp's
      Move.right(1.42), // over it — not on it when the near past is due
      Move(2.1), // on the door's button, long: the far past will hold it
      Move.left(0.9), // back to the lamp's, and stand
      Move(2.3), // until the far past is on the mirror, in the dark
      Move.left(8), // and the long way to the door
    ],
    wrongIdeas: const [
      // Down onto the lamp's button and stand: the near past takes you back
      // before anything is done.
      [Move.right(2.15), Move(6), Move.left(8)],
      // The first mirror level's answer: the door's button until it takes
      // you back. With the lamp on, it never does.
      [Move.right(3.25), Move(8), Move.left(8)],
    ],
    name: 'اتنين ورجعتين',
    teaches: 'اتنين منك، ورجعتين.',
    nameEn: 'Two of You, Two Returns',
    teachesEn: 'Two of you, and two returns.',
    delays: const [2.5, 7],
    spawnX: 0,
    floorTop: 400,
    blocks: [
      const Rect.fromLTRB(-900, 400, 300, 2200),
      const Rect.fromLTRB(300, 620, 1000, 2200),
      const Rect.fromLTRB(-940, 140, -900, 2200),
      const Rect.fromLTRB(1000, 140, 1040, 2200),
    ],
    mirrors: const [Rect.fromLTRB(150, 388, 210, 400)],
    lights: const [LightSpec(Rect.fromLTRB(110, 150, 250, 400), id: 'lamp')],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(460, 608, 520, 620), opens: 'lamp'),
      // Narrow, so a past walking over it does not open the door far
      // enough to get through (§9.3): it has to stand.
      PlateSpec(area: Rect.fromLTRB(690, 608, 730, 620), opens: 'gate'),
    ],
    doors: const [
      // Two pasts stack, so the door is as tall as two steps reach.
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-560, 40, -534, 400)),
    ],
    goal: const Rect.fromLTRB(-720, 328, -640, 400),
  );

  /// **A step, then a mirror.** The way out is up on a ledge you can only
  /// climb by leaving yourself as a step, ducked at its foot — and its door's
  /// button is down on the ground, a long way off.
  ///
  /// So you would have to climb twice, and your one past cannot be the step
  /// and the button at once. The mirror on the ledge is the second climb:
  /// stand on it, go down to the button, and it puts you back up there
  /// while your past walks down after you and stands on the button.
  static final Level aStepThenAMirror = Level(
    id: 'a-step-then-a-mirror',
    solution: const [
      Move.right(0.85), // to the foot of the ledge
      Move(4.0, crouch: true), // duck: the step you are leaving
      Move.left(0.9), // out of your own way
      Move(0.15),
      Move.right(0.4), // run at it
      Move.right(0.55, jump: true), // onto its head
      Move.right(0.6, jump: true), // and up onto the ledge
      Move.right(0.4), // onto the mirror
      Move.left(2.35), // off the ledge and away to the button
      Move(1.8), // and stand, until it takes you back up
      Move.right(6), // along the ledge, through, as your past stands there
    ],
    wrongIdeas: const [
      // The button first, then the climb: by the time you are up, your past
      // has long left the button.
      [
        Move.left(1.0),
        Move(1.5),
        Move.right(2.1),
        Move(4.0, crouch: true),
        Move.left(0.9),
        Move(0.15),
        Move.right(0.4),
        Move.right(0.55, jump: true),
        Move.right(0.6, jump: true),
        Move.right(6),
      ],
      // Up, and straight on to the door: nobody is on its button.
      [
        Move.right(0.85),
        Move(4.0, crouch: true),
        Move.left(0.9),
        Move(0.15),
        Move.right(0.4),
        Move.right(0.55, jump: true),
        Move.right(0.6, jump: true),
        Move.right(8),
      ],
    ],
    name: 'سلّمة ومراية',
    teaches: 'الرف عالي مرتين.',
    nameEn: 'A Step, Then a Mirror',
    teachesEn: 'The shelf is twice too high.',
    delaySeconds: 4,
    spawnX: -400,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1500, 620, 400, 2200),
      const Rect.fromLTRB(-200, 430, 400, 2200),
      const Rect.fromLTRB(-1040, 140, -1000, 620),
      const Rect.fromLTRB(400, 140, 440, 2200),
    ],
    mirrors: const [Rect.fromLTRB(-120, 418, -60, 430)],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-630, 608, -570, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(240, 180, 266, 430)),
    ],
    goal: const Rect.fromLTRB(300, 358, 380, 430),
  );

  /// **Two mirrors.** One up top, one down in the pit, and each takes you
  /// back to itself.
  ///
  /// The door is down at the far end of the pit, and the key that opens it
  /// is up top, behind where you start — too far from the door to open it
  /// and get there before your past flips it shut again. So you have to be
  /// up top to open it and down by the door a moment later. Stand on the top
  /// mirror, then go down and stand on the bottom one: the first takes you
  /// up to the key, and the second brings you back down beside the door.
  static final Level twoMirrors = Level(
    id: 'two-mirrors',
    solution: const [
      Move.right(2.2), // over the top mirror and down
      Move.right(0.95), // onto the bottom one, and stand
      Move(1.7), // until the top one takes you up
      Move.left(0.5), // towards the key, but not onto it yet
      Move(0.6),
      Move.left(0.5), // onto it, late
      Move(1.0), // until the bottom one takes you down
      Move.right(6), // to the door, before your past flips it back
    ],
    wrongIdeas: const [
      // The key, then run for the door: too far.
      [Move.left(0.6), Move(0.2), Move.right(9)],
      // Only the top mirror: up again, key, and the long way down.
      [
        Move.right(2.2),
        Move(2.5),
        Move.left(0.5),
        Move(0.9),
        Move.left(0.4),
        Move.right(9),
      ],
    ],
    name: 'مرايتين',
    teaches: 'مراية فوق ومراية تحت: كل واحدة بترجّعك ليها.',
    nameEn: 'Two Mirrors',
    teachesEn: 'One mirror up top, one below: each brings you back to itself.',
    delaySeconds: 4,
    spawnX: 0,
    floorTop: 400,
    blocks: [
      const Rect.fromLTRB(-500, 400, 300, 2200),
      const Rect.fromLTRB(300, 620, 1200, 2200),
      const Rect.fromLTRB(-540, 140, -500, 2200),
      const Rect.fromLTRB(1200, 140, 1240, 2200),
    ],
    mirrors: const [
      Rect.fromLTRB(100, 388, 160, 400),
      Rect.fromLTRB(600, 608, 660, 620),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-150, 388, -70, 400), flips: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(1000, 360, 1026, 620)),
    ],
    goal: const Rect.fromLTRB(1080, 548, 1160, 620),
  );

  static final List<Level> all = [
    theMirrorInTheLight,
    fromBehindTheDoor,
    openItLate,
    allOfItInTheMirror,
    twoOfYouTwoReturns,
    aStepThenAMirror,
    twoMirrors,
  ];
}
