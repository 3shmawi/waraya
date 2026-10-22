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
    teaches: 'الزرار فوق، والأسانسير تحت.',
    nameEn: 'Your Past Upstairs',
    teachesEn: 'The button is upstairs. The lift is down here.',
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
    name: 'فوق مش زي تحت',
    teaches: 'بص على الدور اللي فوق كويس.',
    nameEn: 'Up There Is Not Down Here',
    teachesEn: 'Look closely at the floor above.',
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
    name: 'سقف واطي',
    teaches: 'فوق، السقف قريب.',
    nameEn: 'A Low Ceiling',
    teachesEn: 'Up there, the ceiling is close.',
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
    name: 'حاجتين فوق',
    teaches: 'واحدة ورا التانية.',
    nameEn: 'Two Things Up There',
    teachesEn: 'One after the other.',
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

  /// **The long way up.** The last three together: the lift is waiting at
  /// the top, its UP button is upstairs behind you, and up there a wall is
  /// between the mirror and the button. So: the mirror; back, with a jump
  /// over nothing; stand under the button; then bring the cabin down
  /// yourself and get in. And this once your past does not take it away
  /// from under you — it is upstairs, nowhere near the button down here.
  static final Level theLongWayUp = Level(
    id: 'the-long-way-up',
    solution: const [
      Move.right(0.55), // onto the mirror
      Move.left(1.0),
      Move.left(0.8, jump: true), // over nothing: the wall, up there
      Move.left(0.4), // under the button
      Move(0.3),
      Move.right(2.9), // onto DOWN
      Move(1.2), // while it comes down
      Move.right(0.3),
      Move.right(0.35, jump: true), // in
      Move(2.6), // until your past calls it up
      Move.right(3), // off, and out
    ],
    wrongIdeas: const [
      // The same, walking: up there your past walks into the wall.
      [
        Move.right(0.55),
        Move.left(2.2),
        Move(0.3),
        Move.right(2.9),
        Move(1.2),
        Move.right(0.3),
        Move.right(0.35, jump: true),
        Move(5),
        Move.right(3),
      ],
      // The mirror and straight to the lift: nobody up there calls it.
      [
        Move.right(1.0),
        Move(1.2),
        Move.right(0.3),
        Move.right(0.35, jump: true),
        Move(8),
        Move.right(3),
      ],
    ],
    name: 'الطلعة الطويلة',
    teaches: 'كل اللي فات، مع بعض.',
    nameEn: 'The Long Way Up',
    teachesEn: 'Everything so far, together.',
    delaySeconds: 6,
    spawnX: -700,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1440, 620, -230, 2200),
      const Rect.fromLTRB(-1480, 100, -1440, 2200),
      // The floor above, up to the lift.
      const Rect.fromLTRB(-1440, 320, -350, 340),
      // The wall, up there only.
      const Rect.fromLTRB(-880, 262, -860, 320),
      // Past the lift: the way out.
      const Rect.fromLTRB(-230, 320, 900, 2200),
      const Rect.fromLTRB(900, 100, 940, 2200),
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
        area: Rect.fromLTRB(-350, 600, -230, 620),
        rise: 280,
        callDown: Rect.fromLTRB(-480, 608, -400, 620),
        callUp: Rect.fromLTRB(-1080, 308, -1000, 320),
        startsUp: true,
      ),
    ],
    goal: const Rect.fromLTRB(300, 248, 380, 320),
  );

  /// **One way.** Upstairs, going back from the mirror: a key, and past it a
  /// button. The button holds the near door on the street; the key opens
  /// the far gate — for as long as nobody arrives on it again. And your past
  /// arrives on it twice: going to the button, and coming back.
  ///
  /// The second time shuts the gate, D seconds after you passed under the
  /// key, which is a little before you get to the gate. So coming back,
  /// jump — over nothing, down here — where the key is up there, and your
  /// past hops it.
  static final Level oneWay = Level(
    id: 'one-way',
    solution: const [
      Move.right(0.3), // onto the mirror
      Move.left(1.85), // under the key, and on, under the button
      Move(0.5),
      Move.right(0.85),
      Move.right(0.8, jump: true), // over nothing: over the key, up there
      Move.right(5.0), // the door, the gate, out
    ],
    wrongIdeas: const [
      // There and back, walking: your past flips the key back on its way.
      [
        Move.right(0.3),
        Move.left(1.85),
        Move(0.5),
        Move.right(6.6),
        Move(3),
        Move.right(1),
      ],
      // Hopping it both ways: the gate never opens.
      [
        Move.right(0.3),
        Move.left(0.4),
        Move.left(0.8, jump: true),
        Move.left(0.65), // under the button, where the run turns
        Move(0.5),
        Move.right(0.85),
        Move.right(0.8, jump: true),
        Move.right(5.0),
        Move(3),
        Move.right(1),
      ],
    ],
    name: 'رايح بس',
    teaches: 'المفتاح بيتقلب كل ما حد يوصله.',
    nameEn: 'One Way',
    teachesEn: 'A key flips every time somebody arrives on it.',
    delaySeconds: 3,
    spawnX: -880,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1440, 620, 600, 2200),
      const Rect.fromLTRB(-1480, 100, -1440, 2200),
      const Rect.fromLTRB(600, 100, 640, 2200),
      const Rect.fromLTRB(-1440, 320, 300, 340),
    ],
    barberMirrors: const [_pair],
    toggles: const [
      ToggleSpec(area: Rect.fromLTRB(-1000, 308, -920, 320), flips: 'gate'),
    ],
    plates: const [
      PlateSpec(area: Rect.fromLTRB(-1240, 308, -1160, 320), opens: 'door'),
    ],
    doors: const [
      DoorSpec(
        id: 'door',
        closed: Rect.fromLTRB(-400, 370, -374, 620),
        lingerSeconds: 3,
      ),
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(-100, 370, -74, 620)),
    ],
    goal: const Rect.fromLTRB(100, 548, 180, 620),
  );

  static final List<Level> all = [
    overYourHead,
    yourPastUpstairs,
    jumpOverThere,
    duckForIt,
    jumpThenDuck,
    theLongWayUp,
    oneWay,
  ];
}
