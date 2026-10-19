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

  static final List<Level> all = [theDog, walkOnTheButton];
}
