import '../level/level.dart';

/// What the player has already beaten, across sessions.
///
/// A seam, the same shape as `LevelSource`: the game talks to this interface
/// and never to a storage API, so a test can hand it a map and the web build
/// can hand it the browser's local storage without either knowing about the
/// other.
///
/// **Levels are remembered by id, not by position.** A campaign is a list that
/// is meant to grow — `LevelsThenExtras` exists so a server can append to it —
/// and "you got to level 5" stops meaning anything the moment the list
/// changes underneath it. An id survives insertions, reorderings and a level
/// being pulled.
abstract interface class Progress {
  /// The ids of every level ever finished. Order is not meaningful.
  Future<Set<String>> beaten();

  /// Remembers that [levelId] was finished. Finishing it twice is not an
  /// error, and neither is finishing them out of order.
  Future<void> record(String levelId);

  /// Forgets everything. For a "start again" that means it.
  Future<void> clear();
}

/// Progress that lives for as long as the program does.
///
/// What tests use, and what the game falls back to when storage is
/// unavailable — a private browsing window, a browser with site data blocked.
/// Losing progress is a disappointment; refusing to start is a bug.
class MemoryProgress implements Progress {
  MemoryProgress([Iterable<String> beaten = const []])
    : _beaten = {...beaten};

  final Set<String> _beaten;

  @override
  Future<Set<String>> beaten() async => {..._beaten};

  @override
  Future<void> record(String levelId) async => _beaten.add(levelId);

  @override
  Future<void> clear() async => _beaten.clear();
}

/// How many of [levels] the player is allowed into, given what they have
/// [beaten].
///
/// Everything finished, plus the first thing that is not: you can replay
/// anything you have beaten, and you can always play the one you are stuck on.
/// Ids that are no longer in the list are ignored, which is what makes a
/// campaign safe to reorder or trim.
int unlockedCount(List<Level> levels, Set<String> beaten) {
  var unlocked = 0;
  for (final level in levels) {
    unlocked++;
    if (!beaten.contains(level.id)) break;
  }
  return unlocked;
}

/// Where to drop a returning player: the first level they have not beaten, or
/// the last one if they have beaten everything.
int resumeIndex(List<Level> levels, Set<String> beaten) {
  if (levels.isEmpty) return 0;
  final unlocked = unlockedCount(levels, beaten);
  return (unlocked - 1).clamp(0, levels.length - 1);
}
