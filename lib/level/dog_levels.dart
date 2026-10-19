import 'dart:ui';

import 'level.dart';
import 'playthrough.dart';

/// The street dog's levels (`docs/phase-12-more.md` §10), on the bench.
abstract final class DogLevels {
  /// **The dog.** It keeps the stretch between you and the way out, it runs
  /// at whatever moves, and it is faster than you.
  ///
  /// There is a ledge over its ground, up two steps from the start. On the
  /// ledge it can see you and cannot get at you: it runs along underneath,
  /// barking. So go up, and at the far end of the ledge keep moving — back
  /// and forth, for a while, for no reason anybody watching could see. Then
  /// come down and walk in. D seconds after you were pacing up there, your
  /// past is pacing up there, and the dog is underneath it and not you. Hop
  /// over it on your way past.
  static final Level theDog = Level(
    id: 'the-dog',
    solution: const [
      Move.right(0.55, jump: true), // up the steps
      Move.right(0.55, jump: true),
      Move.right(0.25),
      Move.right(0.55, jump: true), // onto the ledge
      Move.right(2.0), // along it, over the dog's ground, to the end
      Move.left(0.3), // and keep moving: back and forth, for nobody
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(2.6), // back along the ledge, down onto the step below
      Move.right(8), // off it, and in, past the dog: it is busy
    ],
    wrongIdeas: const [
      // Walk in: it is faster than you.
      [Move.right(14)],
      // The same, but stand at the end of the ledge instead of pacing: a
      // past standing still is nothing to a dog, so it comes for you.
      [
        Move.right(0.55, jump: true),
        Move.right(0.55, jump: true),
        Move.right(0.25),
        Move.right(0.55, jump: true),
        Move.right(2.0),
        Move(3.6),
        Move.left(2.6),
        Move.right(8),
      ],
      // Pace on the floor in front of its ground instead, where it can see
      // you and cannot get at you. Found by playing: it worked, and the
      // ledge was decoration. The lamp under the ledge is there for it.
      [
        Move.right(2.8),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move(2.0),
        Move.right(8),
      ],
    ],
    name: 'الكلب',
    teaches: 'الكلب بيجري ورا أي حاجة بتتحرك. ماضيك كمان.',
    nameEn: 'The Dog',
    teachesEn: 'The dog runs at anything that moves. Your past too.',
    delaySeconds: 6,
    spawnX: -700,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1400, 620, 1600, 2200),
      const Rect.fromLTRB(-1040, 140, -1000, 620),
      const Rect.fromLTRB(1300, 140, 1340, 620),
      // Two steps up to the ledge, thin enough to walk under.
      const Rect.fromLTRB(-660, 510, -500, 524),
      const Rect.fromLTRB(-500, 400, -340, 414),
      // The ledge, over the dog's ground. A body's height above the step
      // below it, so standing on the step you do not knock your head on it.
      const Rect.fromLTRB(-340, 284, 150, 304),
    ],
    lights: const [
      // A lamp under the ledge, on the floor in front of the dog's ground:
      // the one spot down there it can see and not get at. A past pacing
      // there was a second answer — found by playing — that went round the
      // ledge altogether.
      LightSpec(Rect.fromLTRB(-200, 310, 0, 620)),
    ],
    dogs: const [
      DogSpec(area: Rect.fromLTRB(0, 560, 900, 620), home: 650, backTo: -300),
    ],
    goal: const Rect.fromLTRB(1100, 548, 1180, 620),
  );

  /// **Walk on the button.** The door's button is just outside the dog's
  /// ground, and the door is on the far side of it.
  ///
  /// A past standing on the button holds the door, and a past standing is
  /// nothing to a dog. So do not stand on it: walk on it, up and down, for a
  /// good while — then stand still on it and wait, so the dog forgets you,
  /// until your past starts walking up and down there too. It is holding
  /// the door and holding the dog at once. Go.
  static final Level walkOnTheButton = Level(
    id: 'walk-on-the-button',
    solution: const [
      Move.right(1.45), // onto the button
      Move.right(0.3), // and walk on it, back and forth
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move(0.6), // then stand on it, still, until the dog forgets you
      Move.right(6), // and go, as your past starts walking there
    ],
    wrongIdeas: const [
      // Stand on the button for your past to hold the door, as six levels
      // of buttons have taught: a past standing still is nothing to a dog.
      [Move.right(1.45), Move(4.2), Move.right(6)],
      // Walk on it, and go straight on: the dog is after you, not your past.
      [
        Move.right(1.45),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(6),
      ],
    ],
    name: 'امشي على الزرار',
    teaches: 'الواقف بيمسك الباب، والماشي بيمسك الكلب.',
    nameEn: 'Walk on the Button',
    teachesEn: 'Standing holds the door. Moving holds the dog.',
    delaySeconds: 4,
    spawnX: -450,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1400, 620, 1400, 2200),
      const Rect.fromLTRB(-740, 140, -700, 620),
      const Rect.fromLTRB(800, 140, 840, 620),
    ],
    plates: const [
      // Clear of the dog's ground, so it cannot get at you on it, and well
      // inside where it can see.
      PlateSpec(area: Rect.fromLTRB(-210, 608, -70, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(600, 360, 626, 620)),
    ],
    dogs: const [
      DogSpec(area: Rect.fromLTRB(0, 560, 520, 620), home: 300, backTo: -250),
    ],
    goal: const Rect.fromLTRB(680, 548, 760, 620),
  );

  /// **Pace in the dark.** The first dog level again, with a lamp over the
  /// end of the ledge — the spot that level taught you to pace on.
  ///
  /// Pace there and the dog barks at you the whole time, so it looks as if
  /// it works. It does not: a past in the light is nothing to a dog, the same
  /// as it is nothing to a plate. Your past paces under the lamp and the dog
  /// comes for you. Stop short of the lamp, where the ledge is dark and still
  /// in the dog's sight, and pace there.
  static final Level paceInTheDark = Level(
    id: 'pace-in-the-dark',
    solution: const [
      Move.right(0.55, jump: true), // up the steps
      Move.right(0.55, jump: true),
      Move.right(0.25),
      Move.right(0.55, jump: true), // onto the ledge
      Move.right(1.3), // along it, and stop short of the lamp
      Move.left(0.3), // and pace there, in the dark
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(1.6), // back along the ledge, down onto the step below
      Move.right(8), // off it, and in
    ],
    wrongIdeas: const [
      [Move.right(14)],
      // The first dog level's answer: pace at the end of the ledge, right
      // over the dog — in the light, where it cannot see your past.
      [
        Move.right(0.55, jump: true),
        Move.right(0.55, jump: true),
        Move.right(0.25),
        Move.right(0.55, jump: true),
        Move.right(2.0),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(2.6),
        Move.right(8),
      ],
      // Pace on the floor in front of its ground instead, where it can see
      // you and cannot get at you. Found by playing: it worked, and the
      // ledge was decoration. The lamp under the ledge is there for it.
      [
        Move.right(2.8),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move(2.0),
        Move.right(8),
      ],
    ],
    name: 'اتمشّى في الضلمة',
    teaches: 'الكلب مبيشوفش ماضيك في النور.',
    nameEn: 'Pace in the Dark',
    teachesEn: 'The dog cannot see your past in the light.',
    delaySeconds: 6,
    spawnX: -700,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1400, 620, 1600, 2200),
      const Rect.fromLTRB(-1040, 140, -1000, 620),
      const Rect.fromLTRB(1300, 140, 1340, 620),
      const Rect.fromLTRB(-660, 510, -500, 524),
      const Rect.fromLTRB(-500, 400, -340, 414),
      const Rect.fromLTRB(-340, 284, 150, 304),
    ],
    lights: const [
      LightSpec(Rect.fromLTRB(40, 140, 150, 284)),
      // A lamp under the ledge, on the floor in front of the dog's ground:
      // the one spot down there it can see and not get at. The same as in
      // the first dog level.
      LightSpec(Rect.fromLTRB(-200, 310, 0, 620)),
    ],
    dogs: const [
      DogSpec(area: Rect.fromLTRB(0, 560, 900, 620), home: 650, backTo: -300),
    ],
    goal: const Rect.fromLTRB(1100, 548, 1180, 620),
  );

  /// **The dog first, the button second.** The door's button is a few steps
  /// behind where you start, out of the dog's sight; the door is just past
  /// the dog's ground, and nothing holds it but a body on the button.
  ///
  /// Your past does things in the order you did them. You will need the dog
  /// held first, while you cross, and the button held second, while you go
  /// through. So pace at the dog's edge first — for no reason, with the
  /// button right behind you — and only then go back and stand on the
  /// button. Then go: your past is pacing, the dog is on it, and at the door
  /// you stand and wait, still, until your past walks back to the button.
  static final Level theDogFirst = Level(
    id: 'the-dog-first',
    solution: const [
      Move.right(0.4), // to the dog's edge
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.right(0.3),
      Move.left(0.3),
      Move.left(1.0), // and only now back, onto the button
      Move(1.0),
      Move.right(8), // and go; at the door, wait, still
    ],
    wrongIdeas: const [
      [Move.right(14)],
      // The button first, since it is right behind you, then the pacing:
      // your past stands on the button long before you reach the door.
      [
        Move.left(0.45),
        Move(1.0),
        Move.right(1.0),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move(0.6),
        Move.right(8),
      ],
      // The pacing, as on «walk on the button», and go: nobody is on the
      // button.
      [
        Move.right(0.4),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move.right(0.3),
        Move.left(0.3),
        Move(0.6),
        Move.right(8),
      ],
      // The button, and straight in: nothing is holding the dog.
      [Move.left(0.45), Move(1.0), Move.right(14)],
    ],
    name: 'الكلب الأول',
    teaches: 'ماضيك بيعمل الحاجات بالترتيب اللي عملتها بيه.',
    nameEn: 'The Dog First',
    teachesEn: 'Your past does things in the order you did them.',
    delaySeconds: 6,
    spawnX: -200,
    floorTop: 620,
    blocks: [
      const Rect.fromLTRB(-1400, 620, 1400, 2200),
      const Rect.fromLTRB(-800, 140, -760, 620),
      const Rect.fromLTRB(900, 140, 940, 620),
    ],
    plates: const [
      // Out of the dog's sight, so pacing on it is nothing to the dog.
      PlateSpec(area: Rect.fromLTRB(-300, 608, -240, 620), opens: 'gate'),
    ],
    doors: const [
      DoorSpec(id: 'gate', closed: Rect.fromLTRB(600, 140, 626, 620)),
    ],
    dogs: const [
      DogSpec(area: Rect.fromLTRB(0, 560, 500, 620), home: 300, backTo: -190),
    ],
    goal: const Rect.fromLTRB(720, 548, 800, 620),
  );

  static final List<Level> all = [
    theDog,
    walkOnTheButton,
    paceInTheDark,
    theDogFirst,
  ];
}
