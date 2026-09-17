import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'level/level.dart';
import 'level/level_game.dart';
import 'level/level_source.dart';
import 'licenses.dart';
import 'progress/progress.dart';
import 'progress/stored_progress.dart';
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

  // Where the levels come from is one line, and today it is the ones that
  // ship in the app. When there is a server, it becomes:
  //
  //   LevelsThenExtras(const BuiltInLevels(), SupabaseLevels(...))
  //
  // and nothing below this line changes. See docs/backend-plan.md.
  const source = BuiltInLevels();
  final levels = await source.load();
  final progress = await StoredProgress.open();

  runApp(
    WarayaLevels(
      levels: levels,
      progress: progress,
      beaten: await progress.beaten(),
    ),
  );
}

class WarayaLevels extends StatefulWidget {
  const WarayaLevels({
    super.key,
    required this.levels,
    required this.progress,
    required this.beaten,
  });

  final List<Level> levels;
  final Progress progress;

  /// What was already finished when the app started. Read once here rather
  /// than awaited inside `build`, so the first frame is the game and not a
  /// spinner.
  final Set<String> beaten;

  @override
  State<WarayaLevels> createState() => _WarayaLevelsState();
}

class _WarayaLevelsState extends State<WarayaLevels> {
  static const String _menu = 'levels';

  late final Set<String> _beaten = {...widget.beaten};
  late final LevelGame _game;

  @override
  void initState() {
    super.initState();
    _game = LevelGame(
      levels: widget.levels,
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
      startAt: resumeIndex(widget.levels, _beaten),
      onBeaten: _remember,
      onCampaignFinished: () => _openMenu(finished: true),
      onMenuRequested: _openMenu,
    );
  }

  void _remember(Level level) {
    // Written every time, awaited nowhere: the player is mid-stride and a
    // storage write is not worth a frame.
    widget.progress.record(level.id);
    if (_beaten.add(level.id)) setState(() {});
  }

  bool _finished = false;

  void _openMenu({bool finished = false}) {
    if (_game.overlays.isActive(_menu)) return;
    setState(() => _finished = finished);
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
                levels: widget.levels,
                unlocked: unlockedCount(widget.levels, _beaten),
                current: game.levelIndex,
                finished: _finished,
                onPick: _pick,
                onClose: _closeMenu,
              ),
            },
          ),
          // The only way into the menu on a touch screen, and a reminder on a
          // keyboard that escape does something. Small and top centre: the
          // readout owns the left corner and the level's name owns the right.
          _MenuHandle(onTap: _openMenu),
        ],
      ),
    );
  }
}

/// The button that opens the level list, hung above the game.
class _MenuHandle extends StatelessWidget {
  const _MenuHandle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0x33140E08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x40FFE7B0)),
              ),
              child: const Text(
                'المراحل',
                style: TextStyle(
                  fontFamily: arabicFontFamily,
                  fontSize: 13,
                  color: Color(0xE6FFE7B0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
