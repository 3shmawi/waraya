import 'package:flutter/widgets.dart';

import '../level/lang.dart';
import '../licenses.dart';
import 'top_bar.dart';
import 'words.dart';

/// The game stopped, and the four ways on from here.
///
/// A real pause (`docs/phase-11-feel.md` §3): the engine is stopped while it is
/// up, so your past is not walking into you while you read it — in the level
/// where your past kills, a menu over a running game would be fatal.
class PauseMenu extends StatelessWidget {
  const PauseMenu({
    super.key,
    required this.lang,
    required this.onResume,
    required this.onRetry,
    required this.onLevels,
    required this.onSettings,
    this.onUpdate,
  });

  /// Take the update that is waiting, when there is one. Here as well as on
  /// the card, because a card waved away is otherwise gone until next time.
  final VoidCallback? onUpdate;

  final Lang lang;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onLevels;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final w = Words(lang);
    return Directionality(
      textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: GestureDetector(
        // A tap on the dark around the buttons carries on, like closing any
        // other sheet.
        onTap: onResume,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: const Color(0xCC0E0A10),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: CustomPaint(painter: GlyphPainter(Glyph.pause)),
                    ),
                    Text(
                      w.paused,
                      style: const TextStyle(
                        fontFamily: arabicFontFamily,
                        fontSize: 28,
                        color: Color(0xFFF3E2C6),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Button(label: w.resume, onTap: onResume, loud: true),
                    _Button(label: w.retry, onTap: onRetry),
                    _Button(label: w.levels, onTap: onLevels),
                    _Button(label: w.settings, onTap: onSettings),
                    if (onUpdate != null)
                      _Button(
                        label: w.updateAvailable,
                        onTap: onUpdate!,
                        loud: true,
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

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap, this.loud = false});

  final String label;
  final VoidCallback onTap;
  final bool loud;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 240,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: loud ? const Color(0x33D9A25C) : const Color(0x14FFE7B0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: loud ? const Color(0xAAD9A25C) : const Color(0x33FFE7B0),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: arabicFontFamily,
              fontSize: 16,
              color: Color(0xFFF3E2C6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Over everything while a phone is held upright: turn it — or, if it will
/// not turn, play anyway.
///
/// A phone build is locked to landscape by its manifest; a browser cannot be
/// locked, so this is what a phone browser held upright gets instead
/// (`docs/phase-11-feel.md` §1). The game is paused underneath it.
///
/// **It always has a way out.** The first version was only a picture and two
/// lines, and the first player to meet it could not leave: the game had been
/// put on their home screen while its manifest still said portrait, which
/// locks an installed web app upright for good, and rotation was locked as
/// well. So: a button that asks the browser to turn the screen (where the
/// browser can be asked), and one that plays upright and remembers it —
/// undone from the settings page.
class TurnPhone extends StatelessWidget {
  const TurnPhone({
    super.key,
    required this.lang,
    required this.onPlayUpright,
    this.onTurn,
  });

  final Lang lang;

  /// Play as it is, and stop asking.
  final VoidCallback onPlayUpright;

  /// Ask the screen to turn. Null where nothing can be asked.
  final VoidCallback? onTurn;

  /// Whether a screen of this size is a phone held upright. A tablet held
  /// upright is a fair view of the level and is left alone.
  static bool applies(Size size) =>
      size.height > size.width && size.shortestSide < 600;

  @override
  Widget build(BuildContext context) {
    final w = Words(lang);
    final turn = onTurn;
    return Directionality(
      textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFF0E0A10),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 96,
                    height: 96,
                    child: CustomPaint(painter: GlyphPainter(Glyph.rotate)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    w.turnPhone,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 22,
                      color: Color(0xFFF3E2C6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    w.turnPhoneWhy,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 14,
                      color: Color(0xFF9A8B7A),
                    ),
                  ),
                  const SizedBox(height: 26),
                  if (turn != null)
                    _Button(label: w.turnForMe, onTap: turn, loud: true),
                  _Button(
                    label: w.playUpright,
                    onTap: onPlayUpright,
                    loud: turn == null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    w.stuckUpright,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 12.5,
                      color: Color(0xFF9A8B7A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
