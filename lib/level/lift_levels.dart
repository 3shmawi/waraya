import 'dart:ui';

import 'level.dart';
import 'playthrough.dart';

/// The lift's levels (`docs/media/drops.md` §3.2), on the bench.
abstract final class LiftLevels {
  /// **Call it from up there.** You start on a balcony, and the way out is
  /// on the ledge across the street, as high as the balcony. The lift goes
  /// between the street and the ledge, and its UP button is up here with
  /// you — stepping on it now sends the cabin up empty, which is no use to
  /// anybody. Step on it anyway.
  ///
  /// Then down to the street, call the cabin down, get in, and wait. D
  /// seconds after you stepped on UP your past steps on it, and you go up.
  /// And D seconds after you called it down your past calls it down again,
  /// so get off at the top.
  static final Level callItFromUpThere = Level(
    id: 'call-it-from-up-there',
    solution: const [
      Move.right(0.6), // onto UP: the cabin goes up, empty
      Move.right(1.4), // off the balcony
      Move(0.4),
      Move.right(1.4), // onto DOWN
      Move(1.2), // while it comes down
      Move.right(0.6),
      Move.right(0.35, jump: true), // in
      Move(2.6), // until your past calls it up
      Move.right(2), // off at the top, and out
    ],
    wrongIdeas: const [
      // Straight down and in: nobody ever calls it up.
      [
        Move.right(0.25),
        Move.right(0.7, jump: true), // over UP
        Move.right(1.0),
        Move(0.4),
        Move.right(1.2),
        Move.right(0.5),
        Move.right(0.35, jump: true),
        Move(8),
        Move.right(2),
      ],
      // The right calls, and then stay in the cabin: your past calls it
      // down again from under you.
      [
        Move.right(0.6),
        Move.right(1.4),
        Move(0.4),
        Move.right(1.4),
        Move(1.2),
        Move.right(0.6),
        Move.right(0.35, jump: true),
        Move(6),
        Move.right(2),
      ],
    ],
    name: 'اطلبه من فوق',
    teaches: 'الأسانسير بيروح للي داس آخر واحد.',
    nameEn: 'Call It from Up There',
    teachesEn: 'The lift goes to whoever called it last.',
    delaySeconds: 6,
    spawnX: -850,
    floorTop: 320,
    blocks: [
      // The balcony you start on.
      const Rect.fromLTRB(-1000, 320, -500, 2200),
      const Rect.fromLTRB(-1040, 100, -1000, 2200),
      // The street.
      const Rect.fromLTRB(-500, 620, 120, 2200),
      // The ledge across it, with the way out.
      const Rect.fromLTRB(120, 320, 1100, 2200),
      const Rect.fromLTRB(1100, 100, 1140, 2200),
    ],
    lifts: const [
      LiftSpec(
        id: 'lift',
        area: Rect.fromLTRB(0, 600, 120, 620),
        rise: 280,
        callDown: Rect.fromLTRB(-200, 608, -120, 620),
        callUp: Rect.fromLTRB(-760, 308, -680, 320),
      ),
    ],
    goal: const Rect.fromLTRB(400, 248, 480, 320),
  );

  /// **Call it while it is up there.** The cabin is waiting at the top
  /// when you come in, so UP — just behind you — does nothing at all when
  /// you step on it. Step on it anyway: your past will, D seconds later, and
  /// by then you will be in the cabin at the bottom.
  ///
  /// And do not call it down straight after. Your past calls it down again
  /// exactly as long after it calls it up as you did, and if that is the
  /// short walk from UP to DOWN it takes the cabin back down a moment after
  /// it reaches the top, with you still in it. Wait, then call it.
  static final Level callItWhileItIsUp = Level(
    id: 'call-it-while-it-is-up',
    solution: const [
      Move.left(0.75), // onto UP: nothing happens
      Move(2.0), // and wait — the later you call it down, the longer up top
      Move.right(1.5), // onto DOWN
      Move(1.2), // while it comes down
      Move.right(0.3),
      Move.right(0.35, jump: true), // in
      Move(2.4), // until your past calls it up
      Move.right(3.5), // off at the top, and out
    ],
    wrongIdeas: const [
      // It is already up, so never mind UP: down, in, and nobody sends it up.
      [
        Move.right(0.75),
        Move(1.2),
        Move.right(0.3),
        Move.right(0.35, jump: true),
        Move(8),
        Move.right(3.5),
      ],
      // UP, then straight to DOWN: your past calls it down again a moment
      // after it gets to the top.
      [
        Move.left(0.75),
        Move.right(1.5),
        Move(1.2),
        Move.right(0.3),
        Move.right(0.35, jump: true),
        Move(4.4),
        Move.right(3.5),
      ],
    ],
    name: 'اطلبه وهو فوق',
    teaches: 'الزرار اللي مبيعملش حاجة دلوقتي ماضيك هيدوسه بعدين.',
    nameEn: 'Call It While It Is Up',
    teachesEn: 'A button that does nothing now, your past presses later.',
    delaySeconds: 6,
    spawnX: -600,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1100, 620, -230, 2200),
      const Rect.fromLTRB(-1140, 100, -1100, 2200),
      const Rect.fromLTRB(-230, 320, 900, 2200),
      const Rect.fromLTRB(900, 100, 940, 2200),
    ],
    lifts: const [
      LiftSpec(
        id: 'lift',
        area: Rect.fromLTRB(-350, 600, -230, 620),
        rise: 280,
        callDown: Rect.fromLTRB(-480, 608, -400, 620),
        callUp: Rect.fromLTRB(-800, 608, -720, 620),
        startsUp: true,
      ),
    ],
    goal: const Rect.fromLTRB(300, 248, 380, 320),
  );

  static final List<Level> all = [callItFromUpThere, callItWhileItIsUp];
}
