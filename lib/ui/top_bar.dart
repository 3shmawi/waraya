import 'dart:math';

import 'package:flutter/widgets.dart';

import '../licenses.dart';

/// Retry, the level list and pause, as three icons in the top right corner.
///
/// They used to be two worded pills in the top middle — «من الأول» and
/// «المراحل» — and on a narrow screen they landed on top of the line under the
/// level's name (`docs/phase-11-feel.md` §3). An icon needs no room for a word
/// and needs no translating: ⟲, ☰ and ⏸ mean the same thing in every game.
///
/// Drawn, not set in a font: the campaign skips Material, and three shapes
/// are not worth the icon font.
///
/// `reload` had exactly one route for a player — the **R key** — before
/// these existed, which meant a phone had no retry at all. Level four is
/// *designed* around failing into a hole you get out of with a retry, so on a
/// phone it was a hole you stayed in.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onRetry,
    required this.onMenu,
    required this.onPause,
    this.labels = const ('من الأول', 'المراحل', 'وقفة'),
    this.onLanguage,
    this.languageLabel = 'EN',
    this.languageName = 'English',
  });

  /// Switches the game to the other language. One tap, from the first
  /// screen: somebody who cannot read the language the game opened in cannot
  /// read their way to the settings page to change it either.
  final VoidCallback? onLanguage;

  /// What the button says: the *other* language, in that language — "EN"
  /// while the game is Arabic, "عربي" while it is English.
  final String languageLabel;

  /// The other language's name, for a screen reader.
  final String languageName;

  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final VoidCallback onPause;

  /// What a screen reader says for each, in the language being shown.
  final (String, String, String) labels;

  /// One button's side, and the gap between them, in logical pixels.
  static const double button = 40;
  static const double gap = 8;
  static const double margin = 10;

  /// The room the bar takes from the top right corner, for the level title to
  /// keep out of. Without the safe area, which the caller adds.
  static const Size footprint = Size(
    margin + button * 4 + gap * 3 + 6,
    margin + button + 4,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: margin, right: margin),
          child: Directionality(
            // Always the same order on screen, whatever the language: the
            // thumb learns where pause is, and it should not move.
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onLanguage != null) ...[
                  _LetterButton(
                    letter: languageLabel,
                    label: languageName,
                    onTap: onLanguage!,
                  ),
                  const SizedBox(width: gap),
                ],
                IconButtonish(
                  glyph: Glyph.retry,
                  label: labels.$1,
                  onTap: onRetry,
                ),
                const SizedBox(width: gap),
                IconButtonish(
                  glyph: Glyph.levels,
                  label: labels.$2,
                  onTap: onMenu,
                ),
                const SizedBox(width: gap),
                IconButtonish(
                  glyph: Glyph.pause,
                  label: labels.$3,
                  onTap: onPause,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round button with a word on it instead of a shape: the language switch.
/// A flag would be wrong — a language is not a country — and a globe says
/// "language" without saying which; the other language's own name does both.
class _LetterButton extends StatelessWidget {
  const _LetterButton({
    required this.letter,
    required this.label,
    required this.onTap,
  });

  final String letter;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: TopBar.button,
          height: TopBar.button,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x33140E08),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x40FFE7B0)),
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: arabicFontFamily,
              // "EN" fills the circle at 15; a whole word has to be smaller.
              // A lone "ع" was tried and read as an ε.
              fontSize: letter.length > 2 ? 11.5 : 15,
              height: 1,
              color: Color(0xE6FFE7B0),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shapes the bar draws.
enum Glyph { retry, levels, pause, rotate }

/// A round button with a drawn glyph on it.
class IconButtonish extends StatelessWidget {
  const IconButtonish({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.size = TopBar.button,
  });

  final Glyph glyph;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0x33140E08),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x40FFE7B0)),
          ),
          child: CustomPaint(painter: GlyphPainter(glyph)),
        ),
      ),
    );
  }
}

/// Paints one [Glyph] centred in its box.
class GlyphPainter extends CustomPainter {
  const GlyphPainter(this.glyph, {this.color = const Color(0xE6FFE7B0)});

  final Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final u = size.shortestSide / 40;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * u
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    switch (glyph) {
      case Glyph.retry:
        final r = 8.5 * u;
        // Most of a circle, open at the top right, with the head on the open
        // end pointing the way round.
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -pi / 2 + 0.5,
          2 * pi - 1.1,
          false,
          stroke,
        );
        final end = c + Offset(sin(0.5 - 0.0) * r, -cos(0.5) * r);
        final head = Path()
          ..moveTo(end.dx - 5 * u, end.dy - 4 * u)
          ..lineTo(end.dx + 2.5 * u, end.dy - 3.5 * u)
          ..lineTo(end.dx - 1 * u, end.dy + 3.5 * u)
          ..close();
        canvas.drawPath(head, fill);
      case Glyph.levels:
        for (final dy in const [-6.0, 0.0, 6.0]) {
          canvas.drawLine(
            c + Offset(-8 * u, dy * u),
            c + Offset(8 * u, dy * u),
            stroke,
          );
        }
      case Glyph.pause:
        for (final dx in const [-4.0, 4.0]) {
          canvas.drawLine(
            c + Offset(dx * u, -7 * u),
            c + Offset(dx * u, 7 * u),
            stroke..strokeWidth = 3 * u,
          );
        }
      case Glyph.rotate:
        // A phone on its side, with the turn drawn over its corner.
        final phone = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 26 * u, height: 15 * u),
          Radius.circular(3 * u),
        );
        canvas.drawRRect(phone, stroke);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 17 * u),
          -pi * 0.9,
          pi * 0.55,
          false,
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(GlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
