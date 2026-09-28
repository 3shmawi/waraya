import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'level/attempts.dart';
import 'level/level.dart';
import 'level/level_game.dart';
import 'level/level_source.dart';
import 'level/supabase_attempts.dart';
import 'level/supabase_levels.dart';
import 'licenses.dart';
import 'progress/progress.dart';
import 'progress/stored_progress.dart';
import 'ui/campaign_end.dart';
import 'ui/level_select.dart';

/// The puzzles, in teaching order.
///
/// ```sh
/// flutter run -t lib/main_levels.dart
/// ```
///
/// A third entry point rather than a mode: `main.dart` is the finished
/// environment, `main_lab.dart` is the bench with all the sliders, and this is
/// the campaign with none of them. Nothing here can be tuned mid-play on
/// purpose — a level is meant to be beaten at the numbers it was designed
/// around.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  // The campaign that ships is what the first frame is built from, and the
  // server is never waited for: its levels are added to the end whenever it
  // answers, or never. See docs/phase-8-server.md.
  final levels = await const BuiltInLevels().load();
  final progress = await StoredProgress.open();

  runApp(
    WarayaLevels(
      levels: levels,
      progress: progress,
      beaten: await progress.beaten(),
      attempts: AttemptLog(await SupabaseAttempts.open()),
      extras: SupabaseLevels(
        cache: const StoredLevelCache(),
        onRefused: (verdict) => debugPrint('refused from server: $verdict'),
      ),
    ),
  );
}

class WarayaLevels extends StatefulWidget {
  const WarayaLevels({
    super.key,
    required this.levels,
    required this.progress,
    required this.beaten,
    this.extras,
    this.attempts,
  });

  final List<Level> levels;

  /// Levels from somewhere else, added after [levels] once they arrive. A
  /// failure is silent: the player has the campaign either way.
  final LevelSource? extras;

  /// Where each go at each level is reported, or null for none.
  final AttemptLog? attempts;
  final Progress progress;

  /// What was already finished when the app started. Read once here rather
  /// than awaited inside `build`, so the first frame is the game and not a
  /// spinner.
  final Set<String> beaten;

  @override
  State<WarayaLevels> createState() => _WarayaLevelsState();
}

class _WarayaLevelsState extends State<WarayaLevels>
    with WidgetsBindingObserver {
  static const String _menu = 'levels';
  static const String _end = 'campaign-end';

  late final Set<String> _beaten = {...widget.beaten};
  late final LevelGame _game;
  late List<Level> _levels = widget.levels;

  @override
  void initState() {
    super.initState();
    _game = LevelGame(
      levels: _levels,
      audio: FlameAudioOut(),
      // The puzzles are played in the scene from Phase 1, not on the bench's
      // grey boxes. Same class, same geometry, same numbers — only the paint
      // differs. `main_lab.dart` keeps the grey deliberately: art flatters a
      // mechanic, and the bench exists to find out whether one holds up
      // without help.
      look: LevelLook.silhouette,
      // Straight back to where they stopped. No title screen in the way: a
      // first-time visitor starts in level one because nothing is beaten yet,
      // and everyone else carries on.
      startAt: resumeIndex(_levels, _beaten),
      onBeaten: _remember,
      onCampaignFinished: _showEnd,
      onMenuRequested: _openMenu,
      attempts: widget.attempts,
    );
    WidgetsBinding.instance.addObserver(this);
    _addExtras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A game put away mid-level may never be opened again, so the go so far is
  /// sent now. `hidden` is the one state every platform passes through on the
  /// way out — a tab switched away from, a phone locked, a window minimised.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden) widget.attempts?.hidden();
  }

  Future<void> _addExtras() async {
    final extras = widget.extras;
    if (extras == null) return;
    final List<Level> more;
    try {
      more = await extras.load();
    } catch (error) {
      debugPrint('no levels from ${extras.label}: $error');
      return;
    }
    if (!mounted || more.isEmpty) return;
    _game.addLevels(more);
    setState(() => _levels = _game.levels);
  }

  void _remember(Level level) {
    // Written every time, awaited nowhere: the player is mid-stride and a
    // storage write is not worth a frame.
    widget.progress.record(level.id);
    if (_beaten.add(level.id)) setState(() {});
  }

  void _openMenu() {
    if (_game.overlays.isActive(_menu)) return;
    // Paused, or your shadow keeps walking while you read — and in the level
    // where it kills you, reading the menu would be fatal.
    _game.pauseEngine();
    _game.overlays.add(_menu);
  }

  void _closeMenu() {
    _game.overlays.remove(_menu);
    _game.resumeEngine();
  }

  void _pick(int index) {
    _closeMenu();
    _game.goTo(index);
  }

  void _showEnd() {
    if (_game.overlays.isActive(_end)) return;
    _game.pauseEngine();
    _game.overlays.add(_end);
  }

  /// Leaves the ending and puts the game back where the button says.
  void _leaveEnd({required int? goTo}) {
    _game.overlays.remove(_end);
    _game.resumeEngine();
    if (goTo != null) {
      _game.goTo(goTo);
    } else {
      _openMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    // No MaterialApp: the game owns the whole surface, and skipping Material
    // keeps the web bundle a little smaller. What Material would have provided
    // and is needed anyway is `Directionality` — `Stack` resolves its
    // alignment against it and `Text` cannot lay out without it. Leaving it
    // out threw, and a release build renders a thrown widget as a plain grey
    // rectangle, which is why this is easy to ship without noticing.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          GameWidget<LevelGame>(
            game: _game,
            overlayBuilderMap: {
              _menu: (context, game) => LevelSelect(
                levels: _levels,
                unlocked: unlockedCount(_levels, _beaten),
                current: game.levelIndex,
                onPick: _pick,
                onClose: _closeMenu,
              ),
              _end: (context, game) => CampaignEnd(
                levels: _levels,
                onLevels: () => _leaveEnd(goTo: null),
                onRestart: () => _leaveEnd(goTo: 0),
              ),
            },
          ),
          // The only way to retry or reach the menu on a touch screen, and on
          // a keyboard a reminder that R and escape do something.
          //
          // Top centre, not down with the thumbs: the readout owns the left
          // corner and the level's name owns the right, and more to the point
          // an accidental retry is a level thrown away. Both of these are
          // deliberate acts and are worth reaching for.
          _TopBar(onRetry: _game.reload, onMenu: _openMenu),
        ],
      ),
    );
  }
}

/// Retry and the level list, hung above the game.
///
/// `reload` had exactly one route for a player — the **R key** — which meant
/// a phone had no retry at all. Level four is *designed* around failing into a
/// hole you get out of with R, so on a phone it was a hole you stayed in.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onRetry, required this.onMenu});

  final VoidCallback onRetry;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pill(label: 'من الأول', onTap: onRetry),
              const SizedBox(width: 8),
              _Pill(label: 'المراحل', onTap: onMenu),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x33140E08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x40FFE7B0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: arabicFontFamily,
            fontSize: 13,
            color: Color(0xE6FFE7B0),
          ),
        ),
      ),
    );
  }
}
