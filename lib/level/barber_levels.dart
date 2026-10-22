import 'dart:ui';

import 'level.dart';
import 'playthrough.dart';

/// The barber's mirrors' levels (`docs/media/drops.md` §3.5), on the bench.
abstract final class BarberLevels {
  /// **Over your head.** The street has a door, and the button that holds it
  /// is on the floor above, over your head, behind you. The barber's mirror
  /// is right in front of you, and its twin right above it.
  ///
  /// Step on the mirror, then back, under the button, as if you were up
  /// there, and stand a moment. Then to the door. D seconds after you, your
  /// past steps on the mirror and comes out upstairs, walks back to where
  /// you stood — the button, up there — and stands on it while you go
  /// through.
  static final Level overYourHead = Level(
    id: 'over-your-head',
    solution: const [
      Move.right(0.3), // onto the mirror
      Move.left(0.9), // back, under the button upstairs
      Move(1.0), // and stand
      Move.right(3.8), // to the door, and through
    ],
    wrongIdeas: const [
      // The mirror, and on to the door: upstairs your past walks the same
      // way, and the button is behind it.
      [Move.right(0.3), Move.right(1.6), Move(4), Move.right(1.6)],
      // Under the button, then the mirror on the way: your past stands under
      // it down here, where there is nothing, and goes up after.
      [Move.left(0.6), Move(1.0), Move.right(2.4), Move(4), Move.right(1.6)],
    ],
    name: 'فوق دماغك',
    teaches: 'ماضيك عدّى المراية: بيدوس فوق اللي انت بتدوسه تحت.',
    nameEn: 'Over Your Head',
    teachesEn:
        'Your past went through the mirror: it steps up there on what '
        'you step on down here.',
    delaySeconds: 3,
    spawnX: -880,
    floorTop: 620,
    blocks: [
      // The street.
      const Rect.fromLTRB(-1140, 620, 600, 2200),
      const Rect.fromLTRB(-1180, 100, -1140, 2200),
      const Rect.fromLTRB(600, 100, 640, 2200),
      // The floor above it, the street's twin.
      const Rect.fromLTRB(-1140, 320, 300, 340),
    ],
    barberMirrors: const [
      BarberMirrorSpec(
        from: Rect.fromLTRB(-830, 608, -770, 620),
        to: Rect.fromLTRB(-830, 308, -770, 320),
      ),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-1040, 308, -960, 320), opens: 'door'),
    ],
    doors: const [
      DoorSpec(
        id: 'door',
        closed: Rect.fromLTRB(-400, 370, -374, 620),
        lingerSeconds: 0.5,
      ),
    ],
    goal: const Rect.fromLTRB(-200, 548, -120, 620),
  );

  /// **Your past upstairs.** The street, and the floor above it, and the
  /// lift between them; the way out is up there, past the lift, and the
  /// lift's UP button is on the upper floor, behind you, where you cannot
  /// go. The barber's mirror is on the street just ahead of you, and its
  /// twin is right above it.
  ///
  /// Step on the mirror. Then walk back to the spot under the button, as if
  /// you were up there — and then to the lift, and in. D seconds after you
  /// stepped on the mirror your past steps on it, and goes on upstairs: it
  /// walks back to where you walked, which up there is the button, and the
  /// lift takes you up.
  static final Level yourPastUpstairs = Level(
    id: 'your-past-upstairs',
    solution: const [
      Move.right(0.55), // onto the mirror
      Move.left(1.5), // back, under the button upstairs
      Move.right(4.1), // to the lift
      Move.right(0.35, jump: true), // in
      Move(2.4), // until your past, upstairs, calls it
      Move.right(2.5), // off at the top, and out
    ],
    wrongIdeas: const [
      // The mirror, and straight on to the lift: upstairs your past walks
      // the same way, and the button is behind it.
      [
        Move.right(0.55),
        Move.right(2.6),
        Move.right(0.35, jump: true),
        Move(7),
        Move.right(2.5),
      ],
      // Under the button first, then the mirror on the way to the lift:
      // your past goes upstairs after it has been under the button, and
      // walks on, away from it.
      [
        Move.left(1.0),
        Move.right(4.1),
        Move.right(0.35, jump: true),
        Move(7),
        Move.right(2.5),
      ],
    ],
    name: 'ماضيك فوق',
    teaches: 'ماضيك عدّى المراية: اللي تعمله تحت، هو بيعمله فوق.',
    nameEn: 'Your Past Upstairs',
    teachesEn:
        'Your past went through the mirror: what you do down here, '
        'it does up there.',
    delaySeconds: 5,
    spawnX: -700,
    floorTop: 620,
    blocks: [
      // The street.
      const Rect.fromLTRB(-1140, 620, 120, 2200),
      const Rect.fromLTRB(-1180, 100, -1140, 2200),
      // The floor above it, the street's twin, up to the lift.
      const Rect.fromLTRB(-1140, 320, 0, 340),
      // Past the lift: the way out.
      const Rect.fromLTRB(120, 320, 1100, 2200),
      const Rect.fromLTRB(1100, 100, 1140, 2200),
    ],
    barberMirrors: const [
      BarberMirrorSpec(
        from: Rect.fromLTRB(-630, 608, -570, 620),
        to: Rect.fromLTRB(-630, 308, -570, 320),
      ),
    ],
    lifts: const [
      LiftSpec(
        id: 'lift',
        area: Rect.fromLTRB(0, 600, 120, 620),
        rise: 280,
        // Out of the way at the far end, past the way out: nobody calls it
        // down in this level.
        callDown: Rect.fromLTRB(1000, 308, 1080, 320),
        callUp: Rect.fromLTRB(-940, 308, -860, 320),
      ),
    ],
    goal: const Rect.fromLTRB(400, 248, 480, 320),
  );

  /// The street every one of these is set on, with the floor above it: the
  /// mirror on the street at -800 and its twin above it, the door on the
  /// street, and [up] — whatever the floor above has that the street does
  /// not — between the mirror and the button behind you.
  static List<Rect> _floors(List<Rect> up) => [
    const Rect.fromLTRB(-1440, 620, 600, 2200),
    const Rect.fromLTRB(-1480, 100, -1440, 2200),
    const Rect.fromLTRB(600, 100, 640, 2200),
    const Rect.fromLTRB(-1440, 320, 300, 340),
    ...up,
  ];

  static const _pair = BarberMirrorSpec(
    from: Rect.fromLTRB(-830, 608, -770, 620),
    to: Rect.fromLTRB(-830, 308, -770, 320),
  );

  static const _door = DoorSpec(
    id: 'door',
    closed: Rect.fromLTRB(-400, 370, -374, 620),
    lingerSeconds: 0.5,
  );

  static const _goal = Rect.fromLTRB(-200, 548, -120, 620);

  /// **Jump over there.** The button behind you is upstairs again — and up
  /// there, between the mirror and the button, is a wall knee-high, which
  /// down here there is not. Your past over there walks the floor it is on:
  /// it walks into that wall and stops, unless you jumped. So jump, down
  /// here, over nothing at all, at the spot where the wall is up there.
  static final Level jumpOverThere = Level(
    id: 'jump-over-there',
    solution: const [
      Move.right(0.3), // onto the mirror
      Move.left(0.5),
      Move.left(0.8, jump: true), // over nothing: over the wall, up there
      Move.left(0.3), // onto the spot under the button
      Move(0.6),
      Move.right(4.4), // to the door, and through
    ],
    wrongIdeas: const [
      // The same, and walk: up there your past walks into the wall.
      [
        Move.right(0.3),
        Move.left(1.6),
        Move(0.6),
        Move.right(4.4),
        Move(3),
        Move.right(2),
      ],
      // No mirror: you jump over nothing, and so does your past, down here.
      [
        Move.left(0.3),
        Move.left(0.8, jump: true),
        Move.left(0.3),
        Move(0.6),
        Move.right(4.6),
        Move(3),
        Move.right(2),
      ],
    ],
    name: 'نط هناك',
    teaches: 'فوق فيه حيطة مش هنا: نط انت عشان ماضيك ينط.',
    nameEn: 'Jump Over There',
    teachesEn:
        'There is a wall up there and not down here: jump, so your '
        'past jumps.',
    delaySeconds: 3,
    spawnX: -880,
    floorTop: 620,
    blocks: _floors(const [
      // The wall, up there only.
      Rect.fromLTRB(-980, 262, -960, 320),
    ]),
    barberMirrors: const [_pair],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-1140, 308, -1060, 320), opens: 'door'),
    ],
    doors: const [_door],
    goal: _goal,
  );

  /// **Duck for it.** Up there the ceiling comes down low between the mirror
  /// and the button, and only a ducked body gets under it. Down here the
  /// street is as tall as ever. So duck, down here, under nothing, for as
  /// long as the low ceiling is up there — and slower, ducked, which is the
  /// price.
  static final Level duckForIt = Level(
    id: 'duck-for-it',
    solution: const [
      Move.right(0.3), // onto the mirror
      Move.left(0.6),
      Move.left(1.3, crouch: true), // under nothing: under it, up there
      Move.left(0.3),
      Move(0.6),
      Move.right(4.6), // to the door, and through
    ],
    wrongIdeas: const [
      // The same, standing: up there your past walks into the ceiling.
      [
        Move.right(0.3),
        Move.left(1.4),
        Move(0.6),
        Move.right(4.6),
        Move(3),
        Move.right(2),
      ],
    ],
    name: 'وطّي عشانه',
    teaches: 'فوق السقف واطي: وطّي انت تحت ولا حاجة.',
    nameEn: 'Duck for It',
    teachesEn: 'The ceiling is low up there: duck down here, under nothing.',
    delaySeconds: 3,
    spawnX: -880,
    floorTop: 620,
    blocks: _floors(const [
      // The low ceiling, up there only: a standing head hits it, a ducked
      // one clears it.
      Rect.fromLTRB(-1030, 180, -940, 246),
    ]),
    barberMirrors: const [_pair],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-1160, 308, -1080, 320), opens: 'door'),
    ],
    doors: const [_door],
    goal: _goal,
  );

  /// **Jump, then duck.** Both of them up there, the wall first and then the
  /// low ceiling, and the button past both — all of it planned down here on
  /// a street with nothing on it, for a body you will not see do it until
  /// you are already walking to the door.
  static final Level jumpThenDuck = Level(
    id: 'jump-then-duck',
    solution: const [
      Move.right(0.3), // onto the mirror
      Move.left(0.5),
      Move.left(0.8, jump: true), // the wall, up there
      Move.left(0.2),
      Move.left(1.4, crouch: true), // the ceiling, up there
      Move.left(0.3),
      Move(0.6),
      Move.right(5.4), // to the door, and through
    ],
    wrongIdeas: const [
      // The jump and not the duck.
      [
        Move.right(0.3),
        Move.left(0.5),
        Move.left(0.8, jump: true),
        Move.left(1.0),
        Move(0.6),
        Move.right(5.4),
        Move(3),
        Move.right(2),
      ],
      // The duck and not the jump.
      [
        Move.right(0.3),
        Move.left(0.7),
        Move.left(2.4, crouch: true),
        Move.left(0.3),
        Move(0.6),
        Move.right(5.4),
        Move(3),
        Move.right(2),
      ],
    ],
    name: 'نط ووطّي',
    teaches: 'الحيطة الأول، وبعدين السقف: كله فوق، وكله منك تحت.',
    nameEn: 'Jump, Then Duck',
    teachesEn:
        'The wall first, then the ceiling: all of it up there, all of '
        'it from you down here.',
    delaySeconds: 4,
    spawnX: -880,
    floorTop: 620,
    blocks: _floors(const [
      Rect.fromLTRB(-980, 262, -960, 320),
      Rect.fromLTRB(-1130, 180, -1040, 246),
    ]),
    barberMirrors: const [_pair],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-1260, 308, -1180, 320), opens: 'door'),
    ],
    doors: const [_door],
    goal: _goal,
  );

  static final List<Level> all = [
    overYourHead,
    yourPastUpstairs,
    jumpOverThere,
    duckForIt,
    jumpThenDuck,
  ];
}
