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
    teaches: 'ماضيك في النور مش موجود، حتى على المراية.',
    nameEn: 'The Mirror in the Light',
    teachesEn: 'Your past in the light is not there, not even on the mirror.',
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
    teaches: 'المراية بترجّعك ورا باب اتقفل وراك.',
    nameEn: 'From Behind the Door',
    teachesEn: 'The mirror puts you back behind a door that shut after you.',
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
    name: 'افتحه متأخر',
    teaches: 'ماضيك بيقفله بعد ما تفتحه بـ٥ ثواني. افتحه متأخر.',
    nameEn: 'Open It Late',
    teachesEn:
        'Your past shuts it five seconds after you open it. Open it '
        'late.',
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

  static final List<Level> all = [
    theMirrorInTheLight,
    fromBehindTheDoor,
    openItLate,
    allOfItInTheMirror,
  ];
}
