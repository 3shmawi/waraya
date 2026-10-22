import 'dart:ui';

import 'level.dart';
import 'playthrough.dart';

/// The basket's levels (`docs/media/drops.md` §3.1), on the bench.
abstract final class BasketLevels {
  /// **Pull it for me.** The way out is up on a ledge too high for any step
  /// you can leave yourself, and the basket hangs in front of it. The rope
  /// is a button back down the street: stand on it and the basket goes up —
  /// empty, because you are the one pulling.
  ///
  /// So pull it for a while for nothing, walk back, get in, and wait. D
  /// seconds after you stood at the rope your past is standing at it, and
  /// you go up.
  static final Level pullItForMe = Level(
    id: 'pull-it-for-me',
    solution: const [
      Move.right(0.36), // to the rope
      Move(1.6), // and pull, for nobody
      Move.right(1.75),
      Move.right(0.35, jump: true), // into the basket
      Move(2.2), // until your past pulls you up
      Move.right(2), // onto the ledge, and out
    ],
    wrongIdeas: const [
      // Into the basket and wait: nobody is pulling.
      [Move.right(2.1), Move.right(0.35, jump: true), Move(6), Move.right(2)],
      // Pull it up and walk to it: it is up, and you are not in it.
      [Move.right(0.36), Move(4), Move.right(2.5, jump: true), Move.right(2)],
    ],
    name: 'اسحبلي السبت',
    teaches: 'اللي ماسك الحبل مش اللي جوّه السبت.',
    nameEn: 'Pull It For Me',
    teachesEn: 'Whoever holds the rope is not the one in the basket.',
    delaySeconds: 4,
    spawnX: -500,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1400, 620, 100, 2200),
      const Rect.fromLTRB(-840, 140, -800, 620),
      // The ledge with the way out on it.
      const Rect.fromLTRB(100, 320, 1100, 2200),
      const Rect.fromLTRB(1100, 140, 1140, 2200),
    ],
    baskets: const [
      BasketSpec(
        id: 'basket',
        area: Rect.fromLTRB(0, 600, 100, 620),
        rise: 280,
        lingerSeconds: 1,
      ),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-460, 608, -380, 620), opens: 'basket'),
    ],
    goal: const Rect.fromLTRB(300, 248, 380, 320),
  );

  /// **The basket in the dark.** The rope is under a lamp, and your past in
  /// the light pulls nothing — and the key that puts the lamp out is the
  /// usual kind: your past throws it back on D seconds after you put it
  /// out, which is the dark you get. So the rope has to be in that dark.
  ///
  /// The key is on the way, before the rope, and walking in the way you
  /// are facing throws it first: the dark it gives is over before your past
  /// is at the rope. So hop it, pull, and come back for it — then the
  /// basket. Your past gets to the rope after the lamp went out and before
  /// it throws the key, the way «ضلمة ماضيك» taught: a key puts out the
  /// dark on what you did *before* it.
  static final Level theBasketInTheDark = Level(
    id: 'the-basket-in-the-dark',
    solution: const [
      Move.right(1.2),
      Move.right(0.8, jump: true), // over the key, not on it
      Move.right(0.62), // to the rope, under the lamp
      Move(1.6), // and pull, for nobody
      Move.left(1.15), // back onto the key: the lamp is out
      Move.right(2.15), // to the basket
      Move.right(0.35, jump: true), // in
      Move(2.4), // until your past pulls, in the dark
      Move.right(2), // onto the ledge, and out
    ],
    wrongIdeas: const [
      // The way you are facing: the key, the rope, the basket. The dark is
      // over before your past is at the rope.
      [
        Move.right(2.0), // over the key
        Move.right(0.62), // to the rope
        Move(1.6),
        Move.right(0.7),
        Move(1.2), // until it is down again
        Move.right(0.3),
        Move.right(0.35, jump: true),
        Move(7),
        Move.right(2),
      ],
      // Hop the key and never come back for it: the lamp never goes out.
      [
        Move.right(1.2),
        Move.right(0.8, jump: true),
        Move.right(0.62),
        Move(1.6),
        Move.right(0.7),
        Move(1.2), // until it is down again
        Move.right(0.3),
        Move.right(0.35, jump: true),
        Move(7),
        Move.right(2),
      ],
    ],
    name: 'السبت في الضلمة',
    teaches: 'اللمبة فوق الحبل.',
    nameEn: 'The Basket in the Dark',
    teachesEn: 'The lamp is over the rope.',
    delaySeconds: 6,
    spawnX: -1050,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1600, 620, -200, 2200),
      const Rect.fromLTRB(-1240, 140, -1200, 620),
      const Rect.fromLTRB(-200, 320, 900, 2200),
      const Rect.fromLTRB(900, 140, 940, 2200),
    ],
    lights: const [LightSpec(Rect.fromLTRB(-560, 200, -400, 620), id: 'lamp')],
    baskets: const [
      BasketSpec(
        id: 'basket',
        area: Rect.fromLTRB(-300, 600, -200, 620),
        rise: 280,
        lingerSeconds: 1,
      ),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-520, 608, -440, 620), opens: 'basket'),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-760, 608, -680, 620), flips: 'lamp'),
    ],
    goal: const Rect.fromLTRB(100, 248, 180, 320),
  );

  static final List<Level> all = [pullItForMe, theBasketInTheDark];
}
