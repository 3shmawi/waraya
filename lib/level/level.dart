import 'dart:ui';

import 'lang.dart';
import 'playthrough.dart';

/// A puzzle, as data.
///
/// Phase 4 is about designing puzzles, and a puzzle you can only read by
/// reading the code that draws it is a puzzle nobody will tune. So a level is
/// a value: rectangles, a spawn, a goal, and the three numbers that change how
/// the shadow behaves. It can be diffed, printed, and — the part that matters
/// — replayed in a test to prove it is still solvable.
///
/// Everything is in world units, y down, with 0 at the top of the screen and
/// [Level.floorTop] wherever the level puts its ground.
class Level {
  Level({
    required this.id,
    required this.name,
    required this.teaches,
    this.nameEn,
    this.teachesEn,
    double? delaySeconds,
    List<double>? delays,
    required this.spawnX,
    required this.goal,
    this.blocks = const [],
    this.plates = const [],
    this.toggles = const [],
    this.doors = const [],
    this.lights = const [],
    this.markers = const [],
    this.shadowIsSolid = true,
    this.solidWhen = ShadowSolidity.crouched,
    this.shadowKills = false,
    this.floorTop = 620,
    this.solution = const [],
    this.wrongIdeas = const [],
    this.prelude = const [],
    this.leash,
    this.mirrors = const [],
    this.dogs = const [],
    this.baskets = const [],
    this.lifts = const [],
    this.place = LevelPlace.rooftops,
  }) : assert(
         leash == null || leash > 0,
         'a leash with no length holds you to the spot, which is not a level',
       ),
       assert(
         (delaySeconds == null) != (delays == null),
         'a level sets either delaySeconds or delays, never both',
       ),
       assert(
         delays == null || delays.isNotEmpty,
         'a level with no delay has no shadow, which is not a level',
       ),
       delays = delays ?? [delaySeconds!];

  /// Stable key, used by save files later and by test names now.
  final String id;

  /// Shown in the corner while the level is on screen.
  final String name;

  /// One line, shown under the name. Not a tutorial — the plan's whole point
  /// is that the player works the mechanic out. This is the nudge that stops
  /// a first-time player thinking the game is broken.
  final String teaches;

  /// [name] and [teaches] in English, for a player whose device does not ask
  /// for Arabic. Null shows the Arabic — every level written before these
  /// existed, and any level whose author wrote one language.
  ///
  /// Words, not play: neither is in [requires], because a build that drops
  /// them puts up the same level with the other language's line over it.
  final String? nameEn;
  final String? teachesEn;

  /// The name to show to somebody reading [lang].
  String nameIn(Lang lang) => lang == Lang.en ? nameEn ?? name : name;

  /// The line to show to somebody reading [lang].
  String teachesIn(Lang lang) =>
      lang == Lang.en ? teachesEn ?? teaches : teaches;

  /// Whether both [nameIn] and [teachesIn] are actually in [lang] — false
  /// for an English reader of a level with no English, or with only half of
  /// it.
  bool speaks(Lang lang) =>
      lang == Lang.ar || (nameEn != null && teachesEn != null);

  /// How far behind each shadow runs, nearest first. One entry is one shadow.
  ///
  /// Per level rather than global because the delay *is* a design parameter:
  /// the same layout at 2 seconds and at 5 seconds is two different puzzles,
  /// and the plan lists varying it as one of the mechanic's uses.
  ///
  /// Two entries is not a new rule, it is the rule twice — and what it buys is
  /// the one thing a single shadow cannot do at any delay: **be in two places
  /// at the same moment**. One shadow covers exactly one spot at a time, the
  /// spot you were standing in D ago. Two cover two, and the gap between them
  /// is the gap between the two things you did.
  final List<double> delays;

  /// The nearest shadow's delay, which is what everything that says "the
  /// delay" means — the readout, the bench's slider, and every level written
  /// before there could be more than one.
  double get delaySeconds => delays.first;

  final double spawnX;

  /// Touch this and the level is done.
  final Rect goal;

  /// Everything solid. The floor is one of these like anything else.
  final List<Rect> blocks;

  final List<PlateSpec> plates;
  final List<ToggleSpec> toggles;
  final List<DoorSpec> doors;

  /// Where the light falls, and where the shadow therefore is not.
  ///
  /// **Inside one of these the shadow is nothing.** It is drawn faint, it is
  /// not solid, it presses no plate and throws no key, and it cannot kill.
  /// The shadow needs dark to be a thing at all.
  ///
  /// That is the whole of it, and the restraint is the point. Light that
  /// erases the shadow, or drags it about, or switches on and off on a timer,
  /// was all considered and refused: the first two need a shader, the third is
  /// a stopwatch, and every one of them turns a mechanic the player holds in
  /// one sentence — *that is me, four seconds ago* — into two systems to model
  /// at once. A rectangle the shadow does not exist in keeps the sentence.
  ///
  /// Any overlap counts: a body the beam touches is not there
  /// (`LevelGame._standsInLight` has the history).
  ///
  /// A light with an [LightSpec.id] can be switched off — by a plate or a key
  /// that names it, exactly as one names a door, "open" meaning dark. That is
  /// not the timer refused above: the light still never changes on its own,
  /// only because a body is standing somewhere. See [LightSpec].
  final List<LightSpec> lights;

  /// Squares that fill in when touched but end nothing. Scenery with feedback:
  /// the lab uses them to mark the two things worth reaching without turning
  /// itself into a level to be won.
  final List<Rect> markers;

  /// Can the player stand on the shadow in this level?
  final bool shadowIsSolid;

  /// And *when* — always, or only where it is crouched. See [ShadowSolidity].
  final ShadowSolidity solidWhen;

  /// Does touching the shadow restart the level?
  final bool shadowKills;

  /// Where the ground is, for spawning and for falling out of the world.
  final double floorTop;

  /// A run that finishes this level, and runs that do not.
  ///
  /// Part of the level, not of a test, and the reason is the whole of how this
  /// project stays changeable. The recorded solution proves the puzzle can
  /// still be finished; the recorded wrong idea proves it still has to be
  /// **thought about**, and the second is the one that matters. The first
  /// draft of the first level could be beaten by holding one arrow — the plate
  /// happened to sit on the way to the door — and only a recording of that
  /// idea failing says so.
  ///
  /// They travel in the JSON because a level can arrive from somewhere else,
  /// and a level nobody can check is a level nobody should publish: the gate
  /// in front of `docs/backend-plan.md` replays exactly these, through exactly
  /// the harness the tests use, and takes the level's word for nothing.
  final List<Move> solution;

  /// The obvious ideas that do not work. Each is a run that must **not**
  /// finish the level.
  final List<List<Move>> wrongIdeas;

  /// A past you never lived, shown before you move (`docs/phase-11-feel.md`
  /// §4.1). Empty — every level but one — shows nothing.
  ///
  /// The level opens with a pale body already walking these moves from the
  /// spawn, over and over, and the moment the player moves it is gone; D
  /// seconds later their own past arrives and does what *they* did. The
  /// comparison is the rule, said without a word.
  ///
  /// It is **seen and nothing else**: it presses no plate, holds no door,
  /// carries and kills nobody, so a level's recorded solution and wrong ideas
  /// play the same with it or without it. It is still named in [requires],
  /// and for the dangerous reason: a level built around showing the rule is a
  /// level that makes no sense to a build that drops the showing.
  final List<Move> prelude;

  /// How far you can get from your past, if this level holds you to it at
  /// all (`docs/phase-12-more.md` §3). Null — every level but the bench's —
  /// is no leash.
  ///
  /// It **stops, it never pulls**: a step that would take you further than
  /// this from a past that is here is cut short, and nothing else happens.
  /// A past that walks away from you on its own leaves you where you are;
  /// you just cannot add to the distance. That is what keeps it out of the
  /// loop the pulling version fell into (`phase-7-hard-levels.md` §14): your
  /// past is you D seconds ago, and a force from it would be recorded and
  /// replayed and pull differently every time.
  ///
  /// Measured in a straight line between the middles of the two bodies, so
  /// it holds you up as well as back: step off a ledge your past is standing
  /// on, and you slide down the end of the leash to hang under it, until it
  /// steps off after you. And you cannot jump further from it than this
  /// either.
  ///
  /// Every past is there from the first tick, standing at the start —
  /// where you stood D seconds ago — until the delay has passed. A past in
  /// the light does not hold you at all: it is not there.
  ///
  /// Soft at the end: the further from a past you get, the slower a step
  /// away from it goes, to nothing at the leash's length.
  final double? leash;

  /// Mirrors (`docs/phase-12-more.md` §9), on the bench: floor slabs, as
  /// drawn. Empty — every level but the bench's — is none.
  ///
  /// **When your past arrives on one, you are where it is.** Wherever you
  /// were, you are put on the mirror, in your past's place, and it walks on
  /// along your old path to where you were. A swap, spread over D seconds.
  ///
  /// It moves *you*, not your past, and that is the whole of the design. Your
  /// past can only ever be somewhere you have been — the rule every level
  /// leans on — so a mirror that threw it to where you stand now would put it
  /// somewhere you never were. Moving you keeps the sentence: you decided D
  /// seconds ago, by standing here, that you would be back here now.
  ///
  /// On the edge, like a key: arriving, not standing. A past that got onto
  /// the mirror *by* a mirror does not arrive — otherwise every return would
  /// be recorded and replayed as another, D seconds later, for ever. A past
  /// in the light is not there and moves nobody.
  final List<Rect> mirrors;

  /// Street dogs (`docs/phase-12-more.md` §10), on the bench. Empty — every
  /// level but the bench's — is none. See [DogSpec].
  final List<DogSpec> dogs;

  /// Baskets on a rope (`docs/media/drops.md` §3.1), on the bench: floors
  /// that go up while someone pulls them, named by a plate or a key the way
  /// a door is. Empty — every level but the bench's — is none.
  final List<BasketSpec> baskets;

  /// Lifts (`docs/media/drops.md` §3.2), on the bench: a cabin between two
  /// floors that goes to whichever floor's button was stepped on last.
  final List<LiftSpec> lifts;

  /// Where the level is drawn standing (`docs/phase-12-more.md` §4).
  ///
  /// Paint, not play — the same rule as [nameEn]: it is not in [requires],
  /// because a build that has never heard of it puts the same rectangles up
  /// on the rooftops, and that is the same puzzle somewhere else. Consecutive
  /// levels in one place are a chapter, and the campaign is told where one
  /// ends by the place changing, not by a second list that can drift from
  /// this one.
  final LevelPlace place;

  /// Whether this level can be checked by somebody who did not write it.
  ///
  /// A level with no recorded solution cannot be shown to be finishable, and
  /// one with no recorded wrong idea cannot be shown to be a puzzle rather
  /// than a corridor. The gate in front of published levels replays both
  /// through the same harness the tests use — `Playthrough` — and a level that
  /// carries neither gives it nothing to replay, so it is refused rather than
  /// taken on trust.
  bool get canBeChecked => solution.isNotEmpty && wrongIdeas.isNotEmpty;

  /// The names of the mechanics **this build knows how to play**.
  ///
  /// Everything a level could hold when this set was written — blocks, plates,
  /// doors, markers, one delay — is the baseline and is not named here. The
  /// set is for what comes *after*: a mechanic gets its name added in the same
  /// commit that implements it, never before.
  ///
  /// It exists for one failure that has no other cure. A level served from
  /// somewhere else can reach a client older than the mechanic it uses, and
  /// the old parser does the worst possible thing with a field it has never
  /// heard of: it **ignores it in silence** and puts up a level that is either
  /// unsolvable or solvable without ever touching the thing the puzzle is
  /// about. Neither says anything is wrong. A level that names what it needs
  /// can be refused instead, which is the only honest answer.
  static const Set<String> knownMechanics = <String>{
    // Both landed in the commit that made them play, which is the only order
    // that is safe: a name in here before the code behind it means a level is
    // accepted and then played wrong, which is the exact failure this set
    // exists to prevent.
    'toggles',
    'inverted-plates',
    'lights',
    'delays',
    'crouched-solid',
    // Promoted from the bench with the levels that prove it
    // (`docs/phase-12-more.md` §2.1). Nothing released had refused it, so no
    // level a player could reach was ever played without it.
    'light-switch',
  };

  /// Mechanics whose code is here but which are **still being tried on the
  /// bench** (`docs/lab.md` §1).
  ///
  /// The bench reads levels with these; the game and the gate do not, so a
  /// level using one is refused by name everywhere a player could meet it.
  /// Promotion is moving the name into [knownMechanics], in the commit that
  /// puts the level proving it into the campaign, with its solution, its
  /// wrong idea, and a version bump. A mechanic that fails is deleted from
  /// here and from the code, and its levels stay refused.
  static const Set<String> labMechanics = <String>{
    'prelude',
    'leash',
    'mirror',
    'dog',
    'baskets',
    'lifts',
  };

  /// What the bench accepts: everything the game does, and what is on trial.
  static Set<String> get benchMechanics => {...knownMechanics, ...labMechanics};

  /// What this level needs beyond the baseline, worked out from its contents.
  ///
  /// Derived rather than stored, so it cannot be forgotten: the level says
  /// what it needs because the code that can see what it holds says it, not
  /// because whoever wrote the file remembered to.
  ///
  /// A plate that inverts is named as well as a key, and for the more
  /// dangerous of the two reasons. An older build that drops `toggles` puts up
  /// a level with no way to open the door, which is at least obviously broken;
  /// one that drops `inverts` puts up a level whose door simply opens when it
  /// should have been held shut, and that plays like a level — a slightly easy
  /// one — with nothing anywhere saying it is the wrong puzzle.
  Set<String> get requires => {
    if (toggles.isNotEmpty) 'toggles',
    if (plates.any((plate) => plate.inverts)) 'inverted-plates',
    if (lights.isNotEmpty) 'lights',
    // A named light. An older build has never seen a light that is anything
    // but a bare rectangle, and would either fail to read one or — worse, if
    // it read the rectangle and dropped the name — keep a light on that the
    // level was drawn around switching off. Named at all, not only when
    // something switches it: the name is only there to be switched.
    if (lights.any((light) => light.id != null)) 'light-switch',
    // One delay is the baseline and says nothing. More than one is the
    // dangerous kind of new field: an older build reading `delaySeconds`
    // alone puts up a level with one shadow, which is a level that looks
    // right, plays, and cannot be finished.
    if (delays.length > 1) 'delays',
    // The most dangerous of the lot to drop, and now on nearly every level.
    // A build that has never heard of it reads a level drawn around "a walk
    // leaves no ladder" and plays it with a ladder along every step the
    // player takes — which does not look broken, it looks easy, and it
    // finishes without the player ever ducking.
    if (solidWhen != ShadowSolidity.always) 'crouched-solid',
    if (prelude.isNotEmpty) 'prelude',
    // A build that drops it plays the level loose, and a leash level loose
    // is a walk to the goal.
    if (leash != null) 'leash',
    // Dropped, a mirror is a slab that does nothing: the level puts you down
    // somewhere with no way back out, and looks like a level while it does.
    if (mirrors.isNotEmpty) 'mirror',
    // Dropped, the dog is not there, and the stretch it guards is a walk.
    if (dogs.isNotEmpty) 'dog',
    // Dropped, a basket is not there at all: no way up to what it lifts you
    // to, and nothing anywhere saying why.
    if (baskets.isNotEmpty) 'baskets',
    // Dropped, the cabin is not there and neither is the floor it goes to.
    if (lifts.isNotEmpty) 'lifts',
  };
}

/// When the shadow is a thing you can stand on.
///
/// [crouched] is the game's rule: your past is furniture **only where you
/// chose to duck**. It started as one level's opt-in and became the whole
/// game after that level was played, because it fixes the thing the original
/// rule got wrong.
///
/// [always] is what the game used to be — furniture wherever your past
/// happens to be — and it is kept because a level is data that outlives the
/// build that wrote it. Nothing in the campaign uses it.
///
/// The reason the rule changed: "furniture wherever it happens to be" is
/// this project's single largest source of broken levels. Every patch of open floor within
/// reach of a surface is a second way onto that surface, whether the designer
/// drew it or not — it is why `Levels.ladderCarry` exists, and it quietly
/// unsolved two finished levels months after they were closed. Under
/// [crouched] a walk leaves nothing behind, so the ladder is a decision
/// rather than a side effect, and the level has the one route it was drawn
/// with.
///
/// What it does **not** change: the shadow still presses plates, throws keys
/// and kills, standing or not. Only whether you can put your feet on it. A
/// past that stopped pressing buttons when it stood up would not be a
/// variation on this game, it would be a different one.
///
/// The price is height. A crouched body is [WarayaConfig.crouchHeightFactor]
/// of a standing one, so the staircase is shorter — see
/// [Levels.crouchedLadderReach].
enum ShadowSolidity { always, crouched }

/// A pressure plate, and the door it holds open while something stands on it.
class PlateSpec {
  const PlateSpec({
    required this.area,
    required this.opens,
    this.inverts = false,
  });

  /// The slab itself, as drawn.
  final Rect area;

  /// Id of the [DoorSpec] this plate holds open — or, with [inverts], holds
  /// shut. Or of a [LightSpec], which "open" switches off.
  final String opens;

  /// Holds the door **shut** while a body rests on it, instead of open.
  ///
  /// It beats everything else, which is what makes it worth having: a door
  /// with an inverted plate held down cannot be opened by any plate, any key
  /// or any linger. The point is not the extra rule, it is what it does to
  /// the shadow. Every mechanic up to here makes your past an *asset* —
  /// something that presses what you cannot reach. This one makes it a
  /// liability: a place you must not have been standing, D seconds ago.
  final bool inverts;

  /// Slightly taller than the slab, so a body resting on it counts as on it.
  Rect get trigger =>
      Rect.fromLTRB(area.left, area.top - 28, area.right, area.bottom + 2);
}

/// A key: step on it and the door it names flips, once, whoever stepped.
///
/// Not a plate. A plate is a question the door asks every frame — *is anyone
/// standing here?* — and a key is an event: the door changes state on the edge
/// and stays changed after you walk off. How long you stand on it makes no
/// difference at all.
///
/// The whole of its value is what that means for the shadow. Your past walks
/// the same path you did, so it steps on the same key D seconds later and
/// flips it **back**. A key opens a door for exactly D seconds, no matter what
/// you do, and the thing it teaches is the one sentence six levels of plates
/// cannot: what you open, you close.
class ToggleSpec {
  const ToggleSpec({required this.area, required this.flips});

  /// The slab itself, as drawn.
  final Rect area;

  /// Id of the [DoorSpec] — or the [LightSpec] — this flips.
  final String flips;

  /// Slightly taller than the slab, so a body resting on it counts as on it.
  /// The same shape as a plate's, deliberately: these two are read at a glance
  /// by what they do, not by how closely you have to stand on them.
  Rect get trigger =>
      Rect.fromLTRB(area.left, area.top - 28, area.right, area.bottom + 2);
}

/// A door. Solid while shut, slides up out of the way while a plate is held.
class DoorSpec {
  const DoorSpec({
    required this.id,
    required this.closed,
    this.lingerSeconds = 0,
  });

  final String id;

  /// Where it sits when shut.
  final Rect closed;

  /// How long it stays open after the plate is let go, in seconds.
  ///
  /// Zero by default: a door that shuts the moment you step off is the first
  /// level's entire lesson, and your own past holding something open for you
  /// is the image the whole game is built on.
  ///
  /// It exists because a door with no linger makes a level a stopwatch. The
  /// window a plate holds a door open for is exactly as long as you happened
  /// to stand on it — which can be under a second — and it arrives one whole
  /// delay later, so a beat of hesitation puts you at a shut door that is
  /// never opening again. A door that drifts shut a few seconds after your
  /// past steps off the plate is forgiving in the way a person needs and is
  /// still visibly a door your past opened. The first attempt at this fix
  /// latched the door open forever, and that came straight back as a bug
  /// report: a door that never shuts is not a door anyone is holding.
  final double lingerSeconds;
}

/// A lit rectangle: inside it your past is not there.
///
/// Without an [id] it is lit for good, which is every light in the game
/// before this field. With one, plates and keys can name it the way they name
/// a door, and **"open" means dark**: a plate held or a key thrown switches it
/// off, an inverted plate held keeps it on whatever else is true — the same
/// order as `Door.hold`. There is no linger; a light is on or off this tick.
///
/// What it adds is *when*. A light says where your past does not exist; a
/// switch says for how long. And because your past inside a lit light presses
/// nothing, a plate under its own light cannot switch it off — somebody in
/// the dark has to (`docs/phase-12-more.md` §2).
/// A street dog, and the stretch of ground it keeps (`docs/phase-12-more.md`
/// §10), on the bench.
///
/// **It runs at the nearest thing that moves** — you, or your past — once it
/// is anywhere near its stretch, and it is faster than you. What stands
/// still it leaves alone, and a past in the light is not there for it any
/// more than for anything else. If it gets to you, it sees you off: you are
/// back at [backTo]. It never kills, and it never leaves [area].
///
/// Your past it cannot see off — your past is a memory. It runs to it and
/// stays with it, barking, for as long as it keeps moving. That is the whole
/// use: your past is bait.
///
/// One rule, worked out on the fixed tick from where the bodies are: no
/// `Random`, no wandering. The same run, the same dog.
class DogSpec {
  const DogSpec({required this.area, required this.home, required this.backTo});

  /// The stretch it keeps: its left and right ends, and the floor it runs
  /// on (the bottom edge). The top is only drawn.
  final Rect area;

  /// Where it sits when nothing is moving.
  final double home;

  /// Where you are when it has seen you off — the x on the floor of
  /// the way you came in.
  final double backTo;

  @override
  bool operator ==(Object other) =>
      other is DogSpec &&
      other.area == area &&
      other.home == home &&
      other.backTo == backTo;

  @override
  int get hashCode => Object.hash(area, home, backTo);
}

/// A basket on a rope — the one a flat lowers from its balcony
/// (`docs/media/drops.md` §3.1), on the bench.
///
/// **It goes up while somebody pulls the rope**, and comes back down when
/// they let go. The rope is a plate or a key that names it, exactly as one
/// names a door, and by the same rule in the same order (`Door.hold`): an
/// inverted plate held keeps it down whatever else is true, then a plate
/// held or a key thrown pulls it up, and otherwise it comes down after
/// [lingerSeconds] — your past's grace, never your own.
///
/// It is a floor you can stand in, and it carries you. What it cannot do is
/// carry your past: your past is where *you* were, D seconds ago, and goes
/// up and down exactly as you did. That is why the rope is a plate rather
/// than a weight. A first plan had two baskets on one rope, the heavier
/// going down, with your past as the weight — and on paper one past can
/// never lift you, because you in one basket and it in the other is one
/// each. Pulling is the same story from the balcony, and your past can do
/// it: it stands at the rope while you ride.
class BasketSpec {
  const BasketSpec({
    required this.id,
    required this.area,
    required this.rise,
    this.lingerSeconds = 0,
  });

  /// What a plate's `opens` or a key's `flips` calls it.
  final String id;

  /// The basket where it rests, down. Its top is what you stand on.
  final Rect area;

  /// How far it goes up when it is pulled all the way.
  final double rise;

  /// How long it stays up after your past lets go. See [DoorSpec].
  final double lingerSeconds;

  /// How fast it travels either way, in world units a second. One speed for
  /// both: a basket that came down faster than it went up would be a clock
  /// the player has to learn as well as the rule.
  static const double speed = 200;

  /// The basket at the top of its rope.
  Rect get up => area.translate(0, -rise);

  @override
  bool operator ==(Object other) =>
      other is BasketSpec &&
      other.id == id &&
      other.area == area &&
      other.rise == rise &&
      other.lingerSeconds == lingerSeconds;

  @override
  int get hashCode => Object.hash(id, area, rise, lingerSeconds);
}

/// The old lift with the folding iron gate (`docs/media/drops.md` §3.2), on
/// the bench.
///
/// **It goes to the floor whose button was stepped on last.** One button
/// down below ([callDown]) and one up top ([callUp]), each answering an
/// arrival the way a key does — stepping on, not standing on — and the
/// later arrival wins, however the cabin is moving. Your past steps where
/// you stepped, so your past calls it too: up to where you need it, and
/// away again from under you.
///
/// Not a plate held, which is the basket: a call is a decision that stands
/// until somebody makes another. And while it travels its gate is shut, so
/// nobody gets on or off between floors.
class LiftSpec {
  const LiftSpec({
    required this.id,
    required this.area,
    required this.rise,
    required this.callDown,
    required this.callUp,
    this.startsUp = false,
  });

  /// What it is called, for a level's other pieces to tell it apart.
  final String id;

  /// The cabin's floor at the bottom. Its top is what you stand on.
  final Rect area;

  /// How far above [area] the top floor is.
  final double rise;

  /// The button that calls it down, and the one that calls it up: floor
  /// slabs a body steps onto, like a key's.
  final Rect callDown;
  final Rect callUp;

  /// Where it is waiting when the level starts. Bottom unless said.
  final bool startsUp;

  /// How fast it travels, in world units a second — the basket's speed, so
  /// the two read as the same kind of machine.
  static const double speed = 200;

  /// How tall its gate stands above the cabin floor while it travels.
  static const double gateHeight = 110;

  /// The cabin's floor at the top.
  Rect get up => area.translate(0, -rise);

  /// What a body has to be standing on to have arrived at [button]: the
  /// same shape a key's is.
  static Rect triggerOf(Rect button) => Rect.fromLTRB(
    button.left,
    button.top - 28,
    button.right,
    button.bottom + 2,
  );

  @override
  bool operator ==(Object other) =>
      other is LiftSpec &&
      other.id == id &&
      other.area == area &&
      other.rise == rise &&
      other.callDown == callDown &&
      other.callUp == callUp &&
      other.startsUp == startsUp;

  @override
  int get hashCode => Object.hash(id, area, rise, callDown, callUp, startsUp);
}

class LightSpec {
  const LightSpec(this.area, {this.id});

  final Rect area;

  /// What a plate's `opens` or a key's `flips` calls it, or null for a light
  /// nothing switches.
  final String? id;

  @override
  bool operator ==(Object other) =>
      other is LightSpec && other.area == area && other.id == id;

  @override
  int get hashCode => Object.hash(area, id);

  @override
  String toString() => 'LightSpec($area${id == null ? '' : ', id: $id'})';
}

/// Where a level stands — the photographed place behind it.
///
/// Not [LevelLook]: that is whether the scene is drawn at all (the bench is
/// grey boxes wherever its level says it is). This is *which* scene, and it
/// only means something in the lit one.
enum LevelPlace {
  /// The skyline the game was built in: dust, treeline, palms.
  rooftops,

  /// A stairwell, where the bulb on each landing is on a timer and goes out
  /// on its own — which is the light switch, said by the place.
  stairwell,
}

/// How the level is drawn.
///
/// The bench and the game want opposite things from the same rectangles. On
/// the bench they should be legible slabs you can measure; in the game they
/// should be silhouettes against a bright sky, because that is the game.
enum LevelLook {
  /// Grey boxes on a light ground. Deliberately ugly: nice art flatters a
  /// mechanic, and the bench exists to find out whether one stands up without
  /// help.
  greyBox,

  /// Near-black shapes with a warm rim on every standable face, against the
  /// photographed environment. The rim is doing real work — it is the only
  /// thing separating one black shape from another, and it reads as the
  /// backlight the art direction is built on.
  silhouette,
}

/// How solid each body in a line of pasts is drawn, **nearest first**: the
/// one you are now at 1, then each past further back.
///
/// One ladder in one place, because it gets drawn twice — the game fades its
/// shadows with it and the ending screen draws the game's own mark with it —
/// and two copies of a number like this drift the first time one of them is
/// nudged.
///
/// Stronger than the app icon's 0.30 and 0.55 on purpose. The shadow reads in
/// the game because it is *cold* against a warm sky, and thinning it down
/// towards the sky's own brightness is exactly what takes that away.
const List<double> pastFades = [1, 0.72, 0.45];

/// The grey-box palette. Light ground, dark bodies: this is a silhouette game,
/// and a black character on a dark test scene would tell us nothing about the
/// shadow's opacity.
abstract final class Palette {
  static const Color background = Color(0xFFB4B4B4);
  static const Color blockFill = Color(0xFF6E6E6E);
  static const Color blockTop = Color(0xFF8C8C8C);
  static const Color blockEdge = Color(0xFF4A4A4A);
  static const Color plateUp = Color(0xFF8C8C8C);
  static const Color plateDown = Color(0xFF3A3A3A);
  static const Color doorColor = Color(0xFF5A5A5A);
  static const Color goalIdle = Color(0xFF9A9A9A);
  static const Color goalReached = Color(0xFF2B2B2B);
  static const Color bodyColor = Color(0xFF141414);
  static const Color shadowColor = bodyColor;
  static const Color trailColor = Color(0xFF3C3C3C);
}

/// The same scene, lit from behind.
abstract final class SilhouettePalette {
  static const Color blockFill = Color(0xFF0E0A10);
  static const Color blockTop = Color(0xFFD9A25C);
  static const Color blockEdge = Color(0x00000000);
  static const Color plateUp = Color(0xFF241A16);
  static const Color plateDown = Color(0xFFD9A25C);
  static const Color doorColor = Color(0xFF0E0A10);
  static const Color goalIdle = Color(0xFF140E12);
  static const Color goalReached = Color(0xFFFFE7B0);

  /// The player is as black as the scene gets — the cut-out the backlight
  /// leaves.
  static const Color bodyColor = Color(0xFF07050A);

  /// The shadow is **not** a darker black, and not a warm one either.
  ///
  /// Black at half opacity over a near-black block is invisible, and that is
  /// fatal here — the thing you have to read at a glance is where your old
  /// body is, because you are about to stand on it. The first warm version was
  /// invisible too, just somewhere else: it matched the brown of the mid
  /// treeline exactly and vanished the moment it walked in front of it.
  ///
  /// Paler and slightly cold is the one colour nothing else in this scene has.
  /// It lightens against the blocks, and against the sunset it reads as the
  /// one thing in frame that is not warm.
  static const Color shadowColor = Color(0xFFDCE4EE);

  static const Color trailColor = Color(0x99FFE7B0);
}

/// Reading and writing a level as JSON.
///
/// This is the whole of what a backend needs. A level is already a value; this
/// makes it a value that survives a network hop, so a level served from
/// somewhere else runs through exactly the same code as a built-in one.
///
/// Rectangles are `[left, top, right, bottom]` rather than objects: a level is
/// mostly rectangles, and four numbers read better than four keys repeated
/// thirty times.
extension LevelJson on Level {
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'requires': requires.toList()..sort(),
    'teaches': teaches,
    // Only when written, so a level with none reads back exactly as it was.
    if (nameEn != null) 'nameEn': nameEn,
    if (teachesEn != null) 'teachesEn': teachesEn,
    // Only when it is not the rooftops, so every level written before places
    // existed reads back exactly as it was.
    if (place != LevelPlace.rooftops) 'place': place.name,
    // Both, always. `delaySeconds` is what a build older than two shadows
    // reads, and it gets the nearest one — which is the right answer for a
    // level with one and the wrong level entirely for a level with two, which
    // is why such a level also declares `delays` in `requires` and is refused
    // outright rather than quietly thinned.
    'delaySeconds': delaySeconds,
    'delays': delays,
    'spawnX': spawnX,
    'floorTop': floorTop,
    'shadowIsSolid': shadowIsSolid,
    'shadowSolidWhen': solidWhen.name,
    'shadowKills': shadowKills,
    'solution': [for (final move in solution) _moveToJson(move)],
    'wrongIdeas': [
      for (final idea in wrongIdeas)
        [for (final move in idea) _moveToJson(move)],
    ],
    if (prelude.isNotEmpty)
      'prelude': [for (final move in prelude) _moveToJson(move)],
    if (leash != null) 'leash': leash,
    if (mirrors.isNotEmpty) 'mirrors': mirrors.map(_rectToJson).toList(),
    if (dogs.isNotEmpty)
      'dogs': [
        for (final dog in dogs)
          {
            'area': _rectToJson(dog.area),
            'home': dog.home,
            'backTo': dog.backTo,
          },
      ],
    if (baskets.isNotEmpty)
      'baskets': [
        for (final basket in baskets)
          {
            'id': basket.id,
            'area': _rectToJson(basket.area),
            'rise': basket.rise,
            if (basket.lingerSeconds != 0)
              'lingerSeconds': basket.lingerSeconds,
          },
      ],
    if (lifts.isNotEmpty)
      'lifts': [
        for (final lift in lifts)
          {
            'id': lift.id,
            'area': _rectToJson(lift.area),
            'rise': lift.rise,
            'callDown': _rectToJson(lift.callDown),
            'callUp': _rectToJson(lift.callUp),
            if (lift.startsUp) 'startsUp': true,
          },
      ],
    'goal': _rectToJson(goal),
    'blocks': blocks.map(_rectToJson).toList(),
    // A bare rectangle, as every light was, unless it has a name.
    'lights': [
      for (final light in lights)
        light.id == null
            ? _rectToJson(light.area)
            : {'area': _rectToJson(light.area), 'id': light.id},
    ],
    'markers': markers.map(_rectToJson).toList(),
    'plates': [
      for (final plate in plates)
        {
          'area': _rectToJson(plate.area),
          'opens': plate.opens,
          'inverts': plate.inverts,
        },
    ],
    'toggles': [
      for (final toggle in toggles)
        {'area': _rectToJson(toggle.area), 'flips': toggle.flips},
    ],
    'doors': [
      for (final door in doors)
        {
          'id': door.id,
          'closed': _rectToJson(door.closed),
          'lingerSeconds': door.lingerSeconds,
        },
    ],
  };
}

List<double> _rectToJson(Rect r) => [r.left, r.top, r.right, r.bottom];

/// Short keys, because a recorded run is a hundred of these and four letters
/// of noise each would be most of the file. `s` seconds, `x` the direction,
/// `j` jump, `c` crouch — and everything that is not held is left out, so a
/// move that is only standing still is `{"s": 1.2}`.
Map<String, Object?> _moveToJson(Move move) => {
  's': move.seconds,
  if (move.axis != 0) 'x': move.axis,
  if (move.jump) 'j': true,
  if (move.crouch) 'c': true,
};

/// Thrown when level data does not describe a level.
///
/// Anything coming from outside the app — a file, a server, a level somebody
/// else authored — is malformed until proven otherwise, and the useful failure
/// is one that names the field.
class LevelFormatException implements Exception {
  LevelFormatException(this.message);

  final String message;

  @override
  String toString() => 'LevelFormatException: $message';
}

/// Thrown when a level is well-formed but asks for a mechanic this build does
/// not have.
///
/// Separate from [LevelFormatException] because it is not a mistake: the level
/// is fine, this copy of the game is simply older than it. The right response
/// is to leave that one level out, not to throw the batch away.
class LevelUnsupportedException implements Exception {
  LevelUnsupportedException(this.levelId, this.missing);

  final String levelId;

  /// The names this build does not know. See [Level.knownMechanics].
  final Set<String> missing;

  /// The ones among [missing] that this build has the code for but has not
  /// let out of the bench yet. See [Level.labMechanics].
  Set<String> get onTheBench => missing.intersection(Level.labMechanics);

  @override
  String toString() =>
      'LevelUnsupportedException: level "$levelId" — '
      '${whyRefused(missing).join('; ')}';

  /// Why a level needing [missing] is refused, one line per reason, worded
  /// the same everywhere it is said — here, and by the gate.
  ///
  /// Two reasons, because they have two different answers: a name this build
  /// has never heard of means *wait for a newer build*; a name still on the
  /// bench means *this is being tried, not shipped* (`docs/lab.md` §1).
  static List<String> whyRefused(Set<String> missing) {
    final bench = missing.intersection(Level.labMechanics);
    final absent = missing.difference(bench);
    return [
      if (absent.isNotEmpty)
        'needs ${absent.join(', ')}, which this build does not have',
      if (bench.isNotEmpty)
        '${bench.join(', ')}: still on the bench, not in the game yet',
    ];
  }
}

/// Builds a [Level] from decoded JSON.
///
/// Throws [LevelFormatException] if the data does not describe a level, and
/// [LevelUnsupportedException] if it describes one this build cannot play.
///
/// [accepts] is what this reader will play: [Level.knownMechanics] for the
/// game and the gate, [Level.benchMechanics] for the bench.
Level levelFromJson(Object? source, {Set<String>? accepts}) {
  final json = _asMap(source, 'level');
  final id = _asString(json['id'], 'id');

  // Before anything else is read. A level that needs a mechanic this build
  // has never heard of cannot be parsed into a *smaller* level and played
  // anyway — that is the whole failure this guards.
  final missing = _stringList(
    json['requires'],
    'requires',
  ).toSet().difference(accepts ?? Level.knownMechanics);
  if (missing.isNotEmpty) throw LevelUnsupportedException(id, missing);

  try {
    return Level(
      id: id,
      name: _asString(json['name'], 'name'),
      teaches: _asString(json['teaches'], 'teaches'),
      nameEn: _optionalString(json['nameEn'], 'nameEn'),
      teachesEn: _optionalString(json['teachesEn'], 'teachesEn'),
      place: _place(json['place']),
      delays: json['delays'] == null
          ? [_asDouble(json['delaySeconds'], 'delaySeconds')]
          : _doubleList(json['delays'], 'delays'),
      spawnX: _asDouble(json['spawnX'], 'spawnX'),
      floorTop: _asDouble(json['floorTop'] ?? 620, 'floorTop'),
      shadowIsSolid: _asBool(json['shadowIsSolid'] ?? true, 'shadowIsSolid'),
      solidWhen: _solidity(json['shadowSolidWhen']),
      shadowKills: _asBool(json['shadowKills'] ?? false, 'shadowKills'),
      goal: _rectFromJson(json['goal'], 'goal'),
      solution: _moveList(json['solution'], 'solution'),
      wrongIdeas: [
        for (final (i, idea) in _asList(
          json['wrongIdeas'],
          'wrongIdeas',
        ).indexed)
          _moveList(idea, 'wrongIdeas[$i]'),
      ],
      prelude: _moveList(json['prelude'], 'prelude'),
      leash: json['leash'] == null ? null : _asDouble(json['leash'], 'leash'),
      mirrors: _rectList(json['mirrors'], 'mirrors'),
      dogs: [
        for (final (i, entry) in _asList(json['dogs'], 'dogs').indexed)
          DogSpec(
            area: _rectFromJson(
              _asMap(entry, 'dogs[$i]')['area'],
              'dogs[$i].area',
            ),
            home: _asDouble(_asMap(entry, 'dogs[$i]')['home'], 'dogs[$i].home'),
            backTo: _asDouble(
              _asMap(entry, 'dogs[$i]')['backTo'],
              'dogs[$i].backTo',
            ),
          ),
      ],
      baskets: [
        for (final (i, entry) in _asList(json['baskets'], 'baskets').indexed)
          BasketSpec(
            id: _asString(_asMap(entry, 'baskets[$i]')['id'], 'baskets[$i].id'),
            area: _rectFromJson(
              _asMap(entry, 'baskets[$i]')['area'],
              'baskets[$i].area',
            ),
            rise: _asDouble(
              _asMap(entry, 'baskets[$i]')['rise'],
              'baskets[$i].rise',
            ),
            lingerSeconds: _asDouble(
              _asMap(entry, 'baskets[$i]')['lingerSeconds'] ?? 0,
              'baskets[$i].lingerSeconds',
            ),
          ),
      ],
      lifts: [
        for (final (i, entry) in _asList(json['lifts'], 'lifts').indexed)
          LiftSpec(
            id: _asString(_asMap(entry, 'lifts[$i]')['id'], 'lifts[$i].id'),
            area: _rectFromJson(
              _asMap(entry, 'lifts[$i]')['area'],
              'lifts[$i].area',
            ),
            rise: _asDouble(
              _asMap(entry, 'lifts[$i]')['rise'],
              'lifts[$i].rise',
            ),
            callDown: _rectFromJson(
              _asMap(entry, 'lifts[$i]')['callDown'],
              'lifts[$i].callDown',
            ),
            callUp: _rectFromJson(
              _asMap(entry, 'lifts[$i]')['callUp'],
              'lifts[$i].callUp',
            ),
            startsUp: _asBool(
              _asMap(entry, 'lifts[$i]')['startsUp'] ?? false,
              'lifts[$i].startsUp',
            ),
          ),
      ],
      blocks: _rectList(json['blocks'], 'blocks'),
      lights: [
        for (final (i, entry) in _asList(json['lights'], 'lights').indexed)
          entry is Map
              ? LightSpec(
                  _rectFromJson(entry['area'], 'lights[$i].area'),
                  id: _asString(entry['id'], 'lights[$i].id'),
                )
              : LightSpec(_rectFromJson(entry, 'lights[$i]')),
      ],
      markers: _rectList(json['markers'], 'markers'),
      plates: [
        for (final (i, entry) in _asList(json['plates'], 'plates').indexed)
          PlateSpec(
            area: _rectFromJson(
              _asMap(entry, 'plates[$i]')['area'],
              'plates[$i].area',
            ),
            opens: _asString(
              _asMap(entry, 'plates[$i]')['opens'],
              'plates[$i].opens',
            ),
            // Absent means a plate that opens, which is every plate written
            // before this field existed.
            inverts: _asBool(
              _asMap(entry, 'plates[$i]')['inverts'] ?? false,
              'plates[$i].inverts',
            ),
          ),
      ],
      toggles: [
        for (final (i, entry) in _asList(json['toggles'], 'toggles').indexed)
          ToggleSpec(
            area: _rectFromJson(
              _asMap(entry, 'toggles[$i]')['area'],
              'toggles[$i].area',
            ),
            flips: _asString(
              _asMap(entry, 'toggles[$i]')['flips'],
              'toggles[$i].flips',
            ),
          ),
      ],
      doors: [
        for (final (i, entry) in _asList(json['doors'], 'doors').indexed)
          DoorSpec(
            id: _asString(_asMap(entry, 'doors[$i]')['id'], 'doors[$i].id'),
            closed: _rectFromJson(
              _asMap(entry, 'doors[$i]')['closed'],
              'doors[$i].closed',
            ),
            lingerSeconds: _asDouble(
              _asMap(entry, 'doors[$i]')['lingerSeconds'] ?? 0,
              'doors[$i].lingerSeconds',
            ),
          ),
      ],
    );
  } on LevelFormatException catch (error) {
    // Say which level, not just which field: a campaign is a list, and "goal
    // is not a rectangle" is no use without knowing whose goal.
    throw LevelFormatException('level "$id": ${error.message}');
  }
}

/// Builds a whole campaign from decoded JSON — a list of levels, or one on
/// its own, which is what a file somebody is authoring usually holds.
///
/// A level this build cannot play is **left out**, and [onSkipped] is told.
/// Dropping one level is safe; dropping the batch it arrived in would lose
/// nineteen good levels because the twentieth was ahead of this build, and
/// silently dropping a *field* — the thing [Level.knownMechanics] exists to
/// prevent — is the only version of this that is actually dangerous.
List<Level> levelsFromJson(
  Object? source, {
  void Function(LevelUnsupportedException skipped)? onSkipped,
  Set<String>? accepts,
}) {
  final entries = source is Map ? [source] : _asList(source, 'levels');
  final levels = <Level>[];
  for (final entry in entries) {
    try {
      levels.add(levelFromJson(entry, accepts: accepts));
    } on LevelUnsupportedException catch (error) {
      onSkipped?.call(error);
    }
  }
  return levels;
}

Map<String, Object?> _asMap(Object? value, String field) => value is Map
    ? value.cast<String, Object?>()
    : throw LevelFormatException('$field is not an object');

List<Object?> _asList(Object? value, String field) => switch (value) {
  null => const [],
  final List<Object?> list => list,
  _ => throw LevelFormatException('$field is not a list'),
};

String _asString(Object? value, String field) =>
    value is String && value.isNotEmpty
    ? value
    : throw LevelFormatException('$field is missing or not text');

String? _optionalString(Object? value, String field) =>
    value == null ? null : _asString(value, field);

double _asDouble(Object? value, String field) => value is num
    ? value.toDouble()
    : throw LevelFormatException('$field is not a number');

bool _asBool(Object? value, String field) => value is bool
    ? value
    : throw LevelFormatException('$field is not true or false');

/// Absent means [ShadowSolidity.crouched], which is the game's rule and the
/// constructor's default.
///
/// Every level this build writes names the mode outright, so an absent field
/// only ever comes from something hand-written — and a hand-written level
/// means the rule the game has now, not the one it used to have. A level
/// that wants the old behaviour says so.
///
/// An unknown name is refused rather than defaulted. Defaulting would put up
/// a level whose ladders work in places its author drew as walkable, and
/// `requires` exists precisely so that never happens quietly.
ShadowSolidity _solidity(Object? value) {
  if (value == null) return ShadowSolidity.crouched;
  final name = _asString(value, 'shadowSolidWhen');
  for (final mode in ShadowSolidity.values) {
    if (mode.name == name) return mode;
  }
  throw LevelFormatException('shadowSolidWhen is not a mode: $name');
}

/// Absent, or a place this build has never heard of, is the rooftops.
///
/// The opposite of [_solidity] on purpose. An unknown solidity is a different
/// puzzle and is refused; an unknown place is the same puzzle drawn somewhere
/// this build cannot draw, and the honest answer to that is to draw it
/// somewhere it can.
LevelPlace _place(Object? value) {
  if (value == null) return LevelPlace.rooftops;
  final name = _asString(value, 'place');
  for (final place in LevelPlace.values) {
    if (place.name == name) return place;
  }
  return LevelPlace.rooftops;
}

Rect _rectFromJson(Object? value, String field) {
  final list = _asList(value, field);
  if (list.length != 4) {
    throw LevelFormatException('$field needs four numbers [l, t, r, b]');
  }
  final n = [for (final v in list) _asDouble(v, field)];
  if (n[2] <= n[0] || n[3] <= n[1]) {
    throw LevelFormatException('$field is inside out or empty');
  }
  return Rect.fromLTRB(n[0], n[1], n[2], n[3]);
}

List<Move> _moveList(Object? value, String field) => [
  for (final (i, entry) in _asList(value, field).indexed)
    _moveFromJson(entry, '$field[$i]'),
];

Move _moveFromJson(Object? value, String field) {
  final json = _asMap(value, field);
  final axis = json['x'] ?? 0;
  return Move(
    _asDouble(json['s'], '$field.s'),
    axis: _asDouble(axis, '$field.x'),
    jump: _asBool(json['j'] ?? false, '$field.j'),
    crouch: _asBool(json['c'] ?? false, '$field.c'),
  );
}

List<double> _doubleList(Object? value, String field) {
  final list = [
    for (final (i, entry) in _asList(value, field).indexed)
      _asDouble(entry, '$field[$i]'),
  ];
  if (list.isEmpty) throw LevelFormatException('$field is empty');
  return list;
}

List<String> _stringList(Object? value, String field) => [
  for (final (i, entry) in _asList(value, field).indexed)
    _asString(entry, '$field[$i]'),
];

List<Rect> _rectList(Object? value, String field) => [
  for (final (i, entry) in _asList(value, field).indexed)
    _rectFromJson(entry, '$field[$i]'),
];
