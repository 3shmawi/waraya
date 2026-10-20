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
  /// It is, but only one way round. Pull first, for nobody, then the key on
  /// your way past, then the basket: your past gets to the rope after the
  /// lamp went out and before it throws the key. Key first and the lamp is
  /// back on by the time your past is at the rope, the way «ضلمة ماضيك»
  /// taught: a key puts out the dark on what you did *before* it.
  static final Level theBasketInTheDark = Level(
    id: 'the-basket-in-the-dark',
    solution: const [
      Move.right(1.0), // to the rope, under the lamp
      Move(1.6), // and pull, for nobody
      Move.right(1.45), // over the key: the lamp is out
      Move.right(0.7),
      Move.right(0.35, jump: true), // into the basket
      Move(3.4), // until your past pulls, in the dark
      Move.right(2), // onto the ledge, and out
    ],
    wrongIdeas: const [
      // The rope, then hop the key and into the basket: the lamp never went
      // out, and your past at the rope is in the light.
      [
        Move.right(1.0),
        Move(1.6),
        Move.right(1.06),
        Move.right(0.8, jump: true), // over the key
        Move.right(0.24),
        Move.right(0.35, jump: true),
        Move(5),
        Move.right(2),
      ],
      // The key first, then back to the rope, and hop the key on the way to
      // the basket: the dark it gave is over before your past is at the rope.
      [
        Move.right(2.45),
        Move.left(1.45),
        Move(1.6),
        Move(1.4), // until the basket is down again
        Move.right(1.06),
        Move.right(0.8, jump: true),
        Move.right(0.24),
        Move.right(0.35, jump: true),
        Move(6),
        Move.right(2),
      ],
    ],
    name: 'السبت في الضلمة',
    teaches: 'الحبل تحت اللمبة: اسحب الأول، واطفي بعدين.',
    nameEn: 'The Basket in the Dark',
    teachesEn: 'The rope is under the lamp: pull first, put it out after.',
    delaySeconds: 5,
    spawnX: -700,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1600, 620, 100, 2200),
      const Rect.fromLTRB(-1040, 140, -1000, 620),
      const Rect.fromLTRB(100, 320, 1100, 2200),
      const Rect.fromLTRB(1100, 140, 1140, 2200),
    ],
    lights: const [LightSpec(Rect.fromLTRB(-560, 200, -400, 620), id: 'lamp')],
    baskets: const [
      BasketSpec(
        id: 'basket',
        area: Rect.fromLTRB(0, 600, 100, 620),
        rise: 280,
        lingerSeconds: 1,
      ),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-520, 608, -440, 620), opens: 'basket'),
    ],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-200, 608, -120, 620), flips: 'lamp'),
    ],
    goal: const Rect.fromLTRB(300, 248, 380, 320),
  );

  static final List<Level> all = [pullItForMe, theBasketInTheDark];
}
