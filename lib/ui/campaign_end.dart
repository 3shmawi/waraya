import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../level/lang.dart';
import '../level/level.dart';
import '../licenses.dart';
import 'game_mark.dart';
import 'words.dart';

const Color _ink = Color(0xFFF3E2C6);
const Color _dim = Color(0xFF9A8B7A);

/// What comes up when the last level is finished.
///
/// Before this, finishing the campaign opened the **level list** with a
/// different heading on it. That is a menu, and a menu is what you get for
/// asking — it says "pick something", not "you did it". The one moment in the
/// game where the player has earned a sentence was being answered with a
/// scrolling list of things they had already done.
///
/// So: the trail, the word, and one line that is the whole game stated
/// outright — the only place it is ever stated, because everywhere else the
/// player is meant to work it out. Then two ways onward and nothing else.
///
/// It arrives rather than appearing. The three bodies walk across the panel —
/// you first, then your past on the same steps 0.85 and 1.7 seconds behind,
/// over and over, the animation the loading screen opens the game with — and
/// the words come up behind them. The screen that says the mechanic out loud
/// opens by performing it, and the last thing the game shows is the first.
/// A beat of nothing is also the only pause the game ever gives anybody:
/// everywhere else the delay is running and standing still costs something.
///
/// A tap anywhere skips the words to the end. Somebody replaying the campaign
/// has seen this, and an animation you cannot get past is a wall. The walk
/// keeps going — it is in the way of nothing — unless the device asks for
/// less motion, when it is the still mark.
class CampaignEnd extends StatefulWidget {
  const CampaignEnd({
    super.key,
    required this.levels,
    required this.onLevels,
    required this.onRestart,
    this.lang = Lang.ar,
  });

  final List<Level> levels;

  /// The language the ending speaks.
  final Lang lang;

  /// Open the level list, to go back for one in particular.
  final VoidCallback onLevels;

  /// Start the campaign again from level one. Progress is not wiped: nothing
  /// re-locks, and this is a replay rather than an erasure.
  final VoidCallback onRestart;

  @override
  State<CampaignEnd> createState() => _CampaignEndState();
}

class _CampaignEndState extends State<CampaignEnd>
    with SingleTickerProviderStateMixin {
  /// When the last word has faded up. Past this the ticker has nothing left
  /// to say and stops, so a screen that sits there is not also a screen
  /// rebuilding sixty times a second.
  static const double _settled = 2.9;

  late final Ticker _ticker;

  double _at = 0;

  @override
  void initState() {
    super.initState();
    // Built here rather than lazily in a field: a `late final` that only
    // `dispose` ever reads gets created *during* dispose, and a ticker built
    // then goes looking up an element tree that is already coming apart.
    _ticker = createTicker((elapsed) {
      final at = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      if (at >= _settled) return _skip();
      setState(() => _at = at);
    })..start();
  }

  /// Straight to the settled screen, and stop ticking.
  ///
  /// It does its own [setState]: a skip that only moved the number would be a
  /// tap that appears to do nothing, because stopping the ticker also stops
  /// anything else asking for a repaint.
  void _skip() {
    if (_ticker.isActive) _ticker.stop();
    if (_at == _settled) return;
    setState(() => _at = _settled);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Nought until [from], one [over] seconds later.
  double _fade(double from, {double over = 0.5}) =>
      ((_at - from) / over).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final en = widget.lang == Lang.en;
    final words = Words(widget.lang);
    return Directionality(
      textDirection: en ? TextDirection.ltr : TextDirection.rtl,
      child: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.translucent,
        child: ColoredBox(
          // Nearly opaque, unlike the level list. The list sits over a level
          // that is still there to go back to; this sits over one that is over.
          color: const Color(0xF70B0709),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 208, height: 128, child: _Crossing()),
                    const SizedBox(height: 28),
                    _Rise(
                      at: _fade(1.15),
                      child: Text(
                        words.theEnd,
                        style: const TextStyle(
                          fontFamily: arabicFontFamily,
                          fontSize: 40,
                          height: 1.2,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Rise(
                      at: _fade(1.55),
                      child: Text(
                        // The thesis, said out loud exactly once.
                        words.thesis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: arabicFontFamily,
                          fontSize: 17,
                          height: 1.9,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Rise(
                      at: _fade(1.95),
                      child: Text(
                        words.moreComing(widget.levels.length),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: arabicFontFamily,
                          fontSize: 14,
                          height: 1.7,
                          color: _dim,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    _Rise(
                      at: _fade(2.4),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _Button(label: words.levels, onTap: widget.onLevels),
                          _Button(
                            label: words.fromLevelOne,
                            onTap: widget.onRestart,
                            quiet: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark, walking: you across the panel and your past behind you on the
/// same steps, on a loop (`GameMark.crossing`).
///
/// Its own ticker, so the words can settle and stop asking for frames while
/// this goes on repainting only itself. Still when the platform asks for
/// reduced motion — the mark as it stands everywhere else.
class _Crossing extends StatefulWidget {
  const _Crossing();

  @override
  State<_Crossing> createState() => _CrossingState();
}

class _CrossingState extends State<_Crossing>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(
        () =>
            _seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return CustomPaint(
      painter: still
          ? const GameMark.panel()
          : GameMark.panel(crossing: _seconds),
    );
  }
}

/// Fades a line up and lets it settle the last few pixels into place.
///
/// The lift is small on purpose. These are sentences, and a sentence that
/// slides a long way to get where it is going asks to be watched rather than
/// read.
class _Rise extends StatelessWidget {
  const _Rise({required this.at, required this.child});

  /// Nought to one.
  final double at;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: at,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - at)),
        child: child,
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap, this.quiet = false});

  final String label;
  final VoidCallback onTap;

  /// The second choice, drawn as an outline. Restarting is the rarer want.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: quiet ? const Color(0x14FFE7B0) : const Color(0x33D9A25C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: quiet ? const Color(0x33FFE7B0) : const Color(0xAAD9A25C),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: arabicFontFamily,
            fontSize: 16,
            color: quiet ? _dim : _ink,
          ),
        ),
      ),
    );
  }
}
