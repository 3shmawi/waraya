import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'audio/flame_audio_out.dart';
import 'audio/haptics.dart';
import 'audio/sfx.dart';
import 'input/touch_input_source.dart';
import 'level/attempts.dart';
import 'level/lang.dart';
import 'level/level.dart';
import 'level/level_game.dart';
import 'level/level_source.dart';
import 'level/supabase_attempts.dart';
import 'level/supabase_levels.dart';
import 'licenses.dart';
import 'progress/progress.dart';
import 'progress/stored_progress.dart';
import 'settings/game_settings.dart';
import 'ui/campaign_end.dart';
import 'ui/level_select.dart';
import 'ui/pause_menu.dart';
import 'ui/settings_page.dart';
import 'ui/top_bar.dart';
import 'ui/words.dart';

/// The puzzles, in teaching order.
///
/// ```sh
/// flutter run -t lib/main_levels.dart
/// ```
///
/// An entry point rather than a mode: `main_scene.dart` is the finished
/// environment, `main_lab.dart` is the bench with all the sliders, and this is
/// the campaign with none of them — and what `main.dart` ships. Nothing here can be tuned mid-play on
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
  final settings = await SettingsKeeper.open();

  runApp(
    WarayaLevels(
      levels: levels,
      progress: progress,
      beaten: await progress.beaten(),
      settings: settings,
      // Asked on every row, not once: switching statistics off on the
      // settings page stops the very next one (site/privacy.html).
      attempts: AttemptLog(
        ConsentedSink(
          await SupabaseAttempts.open(),
          allowed: () => settings.value.sendStats,
        ),
      ),
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
    this.settings,
  });

  final List<Level> levels;

  /// Levels from somewhere else, added after [levels] once they arrive. A
  /// failure is silent: the player has the campaign either way.
  final LevelSource? extras;

  /// Where each go at each level is reported, or null for none.
  final AttemptLog? attempts;
  final Progress progress;

  /// The settings page's choices. Null keeps them in memory for this run —
  /// tests, and nothing else.
  final SettingsKeeper? settings;

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
  static const String _pause = 'pause';
  static const String _settingsPage = 'settings';

  late final Set<String> _beaten = {...widget.beaten};
  late final SettingsKeeper _settings = widget.settings ?? SettingsKeeper();
  late final LevelGame _game;
  late List<Level> _levels = widget.levels;

  /// Why the game is stopped, if it is. The engine runs only while this is
  /// empty: closing the settings page over the pause menu must not set the
  /// level going behind the menu that is still open.
  final Set<String> _holds = {};

  /// Whether the phone is held upright and the game is waiting for it to be
  /// turned (`TurnPhone`).
  bool _upright = false;

  Lang get _deviceLang => Lang.forDevice(
    WidgetsBinding.instance.platformDispatcher.locale.languageCode,
  );

  Lang get _lang => _settings.value.langFor(_deviceLang.name);

  Words get _words => Words(_lang);

  @override
  void initState() {
    super.initState();
    _game = LevelGame(
      levels: _levels,
      // Through the settings page's volume, read on every sound.
      audio: ScaledAudio(
        FlameAudioOut(),
        loudness: () => _settings.value.loudness,
      ),
      haptics: PlatformHaptics(enabled: () => _settings.value.haptics),
      buttonScale: () => _settings.value.buttons.scale,
      buttonOpacity: () => _settings.value.buttonOpacity,
      // The puzzles are played in the scene from Phase 1, not on the bench's
      // grey boxes. Same class, same geometry, same numbers — only the paint
      // differs. `main_lab.dart` keeps the grey deliberately: art flatters a
      // mechanic, and the bench exists to find out whether one holds up
      // without help.
      look: LevelLook.silhouette,
      // The delay, and nothing else. Ticks buffered, solid on/off, fps and
      // the reload count are the bench's instruments; to a player they are
      // a debug panel over the sky, and the one number that explains the
      // game was lost among them.
      readoutDetail: false,
      // Straight back to where they stopped. No title screen in the way: a
      // first-time visitor starts in level one because nothing is beaten yet,
      // and everyone else carries on.
      startAt: resumeIndex(_levels, _beaten),
      onBeaten: _remember,
      onCampaignFinished: _showEnd,
      onMenuRequested: _openMenu,
      attempts: widget.attempts,
    )..lang = _lang;
    _settings.addListener(_settingsChanged);
    WidgetsBinding.instance.addObserver(this);
    _addExtras();
  }

  @override
  void dispose() {
    _settings.removeListener(_settingsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _settingsChanged() {
    _game.lang = _lang;
    setState(() {});
  }

  /// The device's language changed under a game following it.
  @override
  void didChangeLocales(List<Locale>? locales) => _settingsChanged();

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

  void _hold(String why) {
    _holds.add(why);
    _game.pauseEngine();
  }

  void _release(String why) {
    _holds.remove(why);
    if (_holds.isEmpty) _game.resumeEngine();
  }

  void _show(String overlay) {
    if (_game.overlays.isActive(overlay)) return;
    // Paused, or your shadow keeps walking while you read — and in the level
    // where it kills you, reading the menu would be fatal.
    _hold(overlay);
    _game.overlays.add(overlay);
    // The bar goes while anything is over the game (see `build`).
    setState(() {});
  }

  void _hide(String overlay) {
    if (!_game.overlays.isActive(overlay)) return;
    _game.overlays.remove(overlay);
    _release(overlay);
    setState(() {});
  }

  /// Whether a menu, the ending, the pause or the settings are up.
  bool get _overlaid => _game.overlays.activeOverlays.isNotEmpty;

  void _openMenu() {
    _hide(_pause);
    _show(_menu);
  }

  void _closeMenu() => _hide(_menu);

  void _pick(int index) {
    _closeMenu();
    _game.goTo(index);
  }

  void _retry() {
    _hide(_pause);
    _game.retry();
  }

  void _showEnd() => _show(_end);

  /// Leaves the ending and puts the game back where the button says.
  void _leaveEnd({required int? goTo}) {
    _hide(_end);
    if (goTo != null) {
      _game.goTo(goTo);
    } else {
      _openMenu();
    }
  }

  /// Stops the game for a phone held upright, and starts it again once it is
  /// turned — after the frame, since this is learned while building one.
  void _noticeUpright(bool upright) {
    if (upright == _upright) return;
    _upright = upright;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_upright) {
        _hold('upright');
      } else {
        _release('upright');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    final words = _words;
    final media = MediaQuery.maybeOf(context);
    final size = media?.size ?? Size.zero;
    final inset = media?.padding ?? EdgeInsets.zero;
    _noticeUpright(TouchInputSource.isTouchPlatform && TurnPhone.applies(size));
    _game.reservedTopRight = Size(
      TopBar.footprint.width + inset.right,
      TopBar.footprint.height + inset.top,
    );
    // No MaterialApp: the game owns the whole surface, and skipping Material
    // keeps the web bundle a little smaller. What Material would have provided
    // and is needed anyway is `Directionality` — `Stack` resolves its
    // alignment against it and `Text` cannot lay out without it. Leaving it
    // out threw, and a release build renders a thrown widget as a plain grey
    // rectangle, which is why this is easy to ship without noticing.
    return Directionality(
      textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
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
                lang: _lang,
              ),
              _end: (context, game) => CampaignEnd(
                levels: _levels,
                onLevels: () => _leaveEnd(goTo: null),
                onRestart: () => _leaveEnd(goTo: 0),
                lang: _lang,
              ),
              _pause: (context, game) => PauseMenu(
                lang: _lang,
                onResume: () => _hide(_pause),
                onRetry: _retry,
                onLevels: _openMenu,
                onSettings: () => _show(_settingsPage),
              ),
              _settingsPage: (context, game) => SettingsPage(
                settings: _settings,
                deviceLang: _deviceLang,
                showTouch: TouchInputSource.isTouchPlatform,
                onClose: () => _hide(_settingsPage),
              ),
            },
          ),
          // The only way to retry, pause or reach the menu on a touch screen,
          // and on a keyboard a reminder that R and escape do something.
          //
          // Top right, out of the thumbs' way: an accidental retry is a level
          // thrown away. All three are deliberate acts and worth reaching for.
          // Not over a menu. Each of them has its own close button in the same
          // corner — in English, under the pause icon — and a bar that stayed
          // on top swallowed the tap meant for it.
          if (!_overlaid)
            TopBar(
              onRetry: _game.retry,
              onMenu: _openMenu,
              onPause: () => _show(_pause),
              labels: (words.retry, words.levels, words.pause),
            ),
          if (_upright) Positioned.fill(child: TurnPhone(lang: lang)),
        ],
      ),
    );
  }
}
