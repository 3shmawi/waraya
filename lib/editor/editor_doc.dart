import 'dart:ui';

import '../level/level.dart';
import '../level/level_check.dart';
import '../level/playthrough.dart';

/// Every kind of thing the editor can put in a level — each one a field the
/// level schema already has (`docs/phase-9-editor.md` §٢). The editor builds
/// levels out of the vocabulary; it does not add to it.
enum PieceKind {
  block('wall / floor', 240, 40),
  plate('plate', 100, 12),
  toggle('key', 80, 12),
  door('door', 26, 260),
  light('light', 200, 360),
  goal('goal', 80, 72),
  marker('marker', 70, 72),

  /// On the bench (`Level.mirrors`): the slab its glass stands on.
  mirror('mirror', 60, 12),

  /// On the bench (`Level.dogs`): the ground it keeps — its bottom edge is
  /// the floor it runs on, its ends are where it stops. Where it sits and
  /// where it sees you off to go with it when it is moved ([Piece.dogHome],
  /// [Piece.dogBack]).
  dog('dog', 600, 60);

  const PieceKind(this.label, this.width, this.height);

  final String label;

  /// Size of a fresh one. A door starts taller than [Levels.minDoorHeight]
  /// so a new door is never a door you can climb.
  final double width;
  final double height;

  /// The ones that point at a door.
  bool get links => this == plate || this == toggle;
}

/// One rectangle in the level, with whatever else its kind carries.
class Piece {
  Piece(
    this.kind,
    this.rect, {
    this.link = noDoor,
    this.inverts = false,
    this.doorId = '',
    this.lightId = '',
    this.linger = 0,
    this.dogHome = 420,
    this.dogBack = 300,
  });

  /// What a plate or a key points at before it points at anything. Not empty,
  /// because an empty name does not survive the round trip through JSON; a
  /// name no door has does, and the check names it.
  static const String noDoor = '?';

  final PieceKind kind;
  Rect rect;

  /// The door a plate opens or a key flips.
  String link;

  /// A plate that holds its door shut.
  bool inverts;

  /// A door's name.
  String doorId;

  /// A light's name, which plates and keys can switch it by; empty for a light
  /// nothing switches (`LightSpec.id`).
  String lightId;

  /// How long a door stays open after its plate is let go.
  double linger;

  /// A dog's: where it sits, from its ground's left end, and how far before
  /// that left end it sees you off to (`DogSpec.home`, `DogSpec.backTo`).
  /// Kept from the ground's edge so they move with it.
  double dogHome;
  double dogBack;

  Piece copy() => Piece(
    kind,
    rect,
    link: link,
    inverts: inverts,
    doorId: doorId,
    lightId: lightId,
    linger: linger,
    dogHome: dogHome,
    dogBack: dogBack,
  );
}

/// A level being edited: everything a [Level] holds, held so it can change.
///
/// A plain Dart class and not a tree of game components, so it can be tested
/// with no game at all (`test/editor/editor_doc_test.dart`) and so there is
/// exactly one way from it to what is played — [toLevel], and then the same
/// [LevelGame] every level runs on.
///
/// The pieces are one list rather than a list per kind so the editor can
/// stack and pick them the way they are drawn. [toLevel] splits them back out
/// by kind in the order they were added, which is what keeps a level opened
/// here and saved untouched **identical** to the one that was opened — every
/// number, every list in the same order.
class EditorDoc {
  EditorDoc({
    required this.id,
    required this.name,
    required this.teaches,
    this.nameEn,
    this.teachesEn,
    required this.delays,
    required this.spawnX,
    required this.floorTop,
    required this.pieces,
    this.shadowIsSolid = true,
    this.solidWhen = ShadowSolidity.crouched,
    this.shadowKills = false,
    this.solution = const [],
    this.wrongIdeas = const [],
    this.prelude = const [],
    this.leash,
    this.baskets = const [],
    this.lifts = const [],
    this.barberMirrors = const [],
    this.place = LevelPlace.rooftops,
  });

  factory EditorDoc.fromLevel(Level level) => EditorDoc(
    id: level.id,
    name: level.name,
    teaches: level.teaches,
    nameEn: level.nameEn,
    teachesEn: level.teachesEn,
    delays: [...level.delays],
    spawnX: level.spawnX,
    floorTop: level.floorTop,
    shadowIsSolid: level.shadowIsSolid,
    solidWhen: level.solidWhen,
    shadowKills: level.shadowKills,
    solution: level.solution,
    wrongIdeas: level.wrongIdeas,
    prelude: level.prelude,
    leash: level.leash,
    baskets: level.baskets,
    lifts: level.lifts,
    barberMirrors: level.barberMirrors,
    place: level.place,
    pieces: [
      for (final rect in level.blocks) Piece(PieceKind.block, rect),
      for (final light in level.lights)
        Piece(PieceKind.light, light.area, lightId: light.id ?? ''),
      for (final rect in level.markers) Piece(PieceKind.marker, rect),
      for (final rect in level.mirrors) Piece(PieceKind.mirror, rect),
      for (final dog in level.dogs)
        Piece(
          PieceKind.dog,
          dog.area,
          dogHome: dog.home - dog.area.left,
          dogBack: dog.area.left - dog.backTo,
        ),
      for (final plate in level.plates)
        Piece(
          PieceKind.plate,
          plate.area,
          link: plate.opens,
          inverts: plate.inverts,
        ),
      for (final toggle in level.toggles)
        Piece(PieceKind.toggle, toggle.area, link: toggle.flips),
      for (final door in level.doors)
        Piece(
          PieceKind.door,
          door.closed,
          doorId: door.id,
          linger: door.lingerSeconds,
        ),
      Piece(PieceKind.goal, level.goal),
    ],
  );

  /// Somewhere to start from nothing: a floor, a way out, and one shadow.
  factory EditorDoc.blank() => EditorDoc(
    id: 'new-level',
    name: 'مرحلة جديدة',
    teaches: 'اكتب هنا الدرس في سطر.',
    delays: [3],
    spawnX: 0,
    floorTop: 620,
    pieces: [
      Piece(PieceKind.block, const Rect.fromLTRB(-1400, 620, 1400, 2200)),
      Piece(PieceKind.goal, const Rect.fromLTRB(600, 548, 680, 620)),
    ],
  );

  String id;
  String name;
  String teaches;

  /// The same two in English, or null for none (`Level.nameEn`).
  String? nameEn;
  String? teachesEn;

  /// Nearest first. One or two.
  List<double> delays;

  double spawnX;
  double floorTop;
  bool shadowIsSolid;
  ShadowSolidity solidWhen;
  bool shadowKills;

  List<Move> solution;
  List<List<Move>> wrongIdeas;

  /// The demonstration before the player moves (`Level.prelude`, on trial).
  /// Carried through untouched so opening and saving a level never drops it.
  List<Move> prelude;

  /// The leash (`Level.leash`, on trial), carried through. No
  /// knob for it yet: a level gets one in its data.
  double? leash;

  /// The baskets (`Level.baskets`, on trial), carried through the same way:
  /// no tool to place one yet.
  List<BasketSpec> baskets;

  /// The lifts (`Level.lifts`, on trial), carried through too.
  List<LiftSpec> lifts;

  /// The barber's mirrors (`Level.barberMirrors`, on trial), carried through.
  List<BarberMirrorSpec> barberMirrors;

  /// Where the level is drawn (`Level.place`), carried through. Paint: no
  /// tool to change it yet, and the bench draws grey boxes either way.
  LevelPlace place;

  final List<Piece> pieces;

  /// The level this is, as the game and the gate will see it.
  Level toLevel() {
    Iterable<Piece> of(PieceKind kind) => pieces.where((p) => p.kind == kind);
    return Level(
      id: id,
      name: name,
      teaches: teaches,
      nameEn: nameEn,
      teachesEn: teachesEn,
      delays: [...delays],
      spawnX: spawnX,
      floorTop: floorTop,
      shadowIsSolid: shadowIsSolid,
      solidWhen: solidWhen,
      shadowKills: shadowKills,
      solution: solution,
      wrongIdeas: wrongIdeas,
      prelude: prelude,
      leash: leash,
      dogs: [
        for (final p in of(PieceKind.dog))
          DogSpec(
            area: p.rect,
            home: p.rect.left + p.dogHome,
            backTo: p.rect.left - p.dogBack,
          ),
      ],
      baskets: baskets,
      lifts: lifts,
      barberMirrors: barberMirrors,
      place: place,
      // Exactly one: the editor neither adds nor removes it ([canRemove]).
      goal: of(PieceKind.goal).first.rect,
      blocks: [for (final p in of(PieceKind.block)) p.rect],
      lights: [
        for (final p in of(PieceKind.light))
          LightSpec(p.rect, id: p.lightId.isEmpty ? null : p.lightId),
      ],
      markers: [for (final p in of(PieceKind.marker)) p.rect],
      mirrors: [for (final p in of(PieceKind.mirror)) p.rect],
      plates: [
        for (final p in of(PieceKind.plate))
          PlateSpec(area: p.rect, opens: p.link, inverts: p.inverts),
      ],
      toggles: [
        for (final p in of(PieceKind.toggle))
          ToggleSpec(area: p.rect, flips: p.link),
      ],
      doors: [
        for (final p in of(PieceKind.door))
          DoorSpec(id: p.doorId, closed: p.rect, lingerSeconds: p.linger),
      ],
    );
  }

  EditorDoc copy() => EditorDoc(
    id: id,
    name: name,
    teaches: teaches,
    nameEn: nameEn,
    teachesEn: teachesEn,
    delays: [...delays],
    spawnX: spawnX,
    floorTop: floorTop,
    shadowIsSolid: shadowIsSolid,
    solidWhen: solidWhen,
    shadowKills: shadowKills,
    solution: solution,
    wrongIdeas: [...wrongIdeas],
    prelude: prelude,
    leash: leash,
    baskets: baskets,
    lifts: lifts,
    barberMirrors: barberMirrors,
    place: place,
    pieces: [for (final p in pieces) p.copy()],
  );

  /// The names of the doors, in order.
  List<String> get doorIds => [
    for (final p in pieces)
      if (p.kind == PieceKind.door) p.doorId,
  ];

  /// The names of the lights that have one, in order.
  List<String> get lightIds => [
    for (final p in pieces)
      if (p.kind == PieceKind.light && p.lightId.isNotEmpty) p.lightId,
  ];

  /// Everything a plate or a key can point at: doors, then named lights.
  List<String> get linkTargets => [...doorIds, ...lightIds];

  /// A door name nobody has used yet.
  String freshDoorId() {
    final taken = doorIds.toSet();
    for (var n = 1; ; n++) {
      final id = n == 1 ? 'gate' : 'gate-$n';
      if (!taken.contains(id)) return id;
    }
  }

  /// Where the player's body is at the start — the gate's own box.
  Rect get spawnBox =>
      Rect.fromLTWH(spawnX - 22, floorTop - bodyHeight, 44, bodyHeight);

  /// Adds a fresh [kind] standing on [at] — its bottom edge there, centred
  /// across it — and returns it. Standing rather than centred because nearly
  /// everything goes on a floor, and a plate whose middle is on the floor is
  /// half inside it.
  ///
  /// A plate or a key comes already pointing at the nearest door, if there is
  /// one — the line from it to its door is the first thing you see, and a
  /// plate pointing at nothing is a plate the check has to tell you about.
  Piece add(PieceKind kind, Offset at) {
    final rect = Rect.fromLTRB(
      at.dx - kind.width / 2,
      at.dy - kind.height,
      at.dx + kind.width / 2,
      at.dy,
    );
    final piece = Piece(
      kind,
      rect,
      doorId: kind == PieceKind.door ? freshDoorId() : '',
      link: kind.links ? _nearestDoor(at) ?? Piece.noDoor : Piece.noDoor,
    );
    pieces.add(piece);
    return piece;
  }

  String? _nearestDoor(Offset at) {
    Piece? best;
    for (final p in pieces) {
      if (p.kind != PieceKind.door) continue;
      if (best == null ||
          (p.rect.center - at).distance < (best.rect.center - at).distance) {
        best = p;
      }
    }
    return best?.doorId;
  }

  /// Whether [piece] may be deleted or copied. Everything but the goal: a
  /// level has exactly one way out, and more than one would be a new field
  /// (`docs/phase-9-editor.md` §٢ — a question, not a tool).
  bool canRemove(Piece piece) => piece.kind != PieceKind.goal;

  /// Renames a door and everything pointing at it with it.
  void renameDoor(Piece door, String to) {
    final from = door.doorId;
    door.doorId = to;
    _relink(from, to);
  }

  /// Names a light, or renames it and everything pointing at it with it. An
  /// empty name makes it a light nothing switches, and whatever pointed at it
  /// is left pointing at nothing — drawn red, and named by the check.
  void renameLight(Piece light, String to) {
    final from = light.lightId;
    light.lightId = to;
    if (from.isNotEmpty && to.isNotEmpty) _relink(from, to);
  }

  void _relink(String from, String to) {
    for (final p in pieces) {
      if (p.kind.links && p.link == from) p.link = to;
    }
  }

  /// The piece drawn at [at], if any — the smallest of those under it, so a
  /// plate on a floor is picked before the floor is.
  Piece? pieceAt(Offset at, {double slop = 0}) {
    Piece? best;
    for (final p in pieces.reversed) {
      if (!p.rect.inflate(slop).contains(at)) continue;
      if (best == null || _area(p.rect) < _area(best.rect)) best = p;
    }
    return best;
  }

  static double _area(Rect r) => r.width * r.height;
}
