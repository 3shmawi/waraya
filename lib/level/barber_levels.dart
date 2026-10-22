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

  static final List<Level> all = [overYourHead, yourPastUpstairs];
}
