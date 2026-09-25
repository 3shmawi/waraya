import 'package:flutter/widgets.dart';

import '../level/level.dart';
import '../licenses.dart';
import 'game_mark.dart';

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
class CampaignEnd extends StatelessWidget {
  const CampaignEnd({
    super.key,
    required this.levels,
    required this.onLevels,
    required this.onRestart,
  });

  final List<Level> levels;

  /// Open the level list, to go back for one in particular.
  final VoidCallback onLevels;

  /// Start the campaign again from level one. Progress is not wiped: nothing
  /// re-locks, and this is a replay rather than an erasure.
  final VoidCallback onRestart;

  static const Color _ink = Color(0xFFF3E2C6);
  static const Color _dim = Color(0xFF9A8B7A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        // Nearly opaque, unlike the level list. The list sits over a level
        // that is still there to go back to; this sits over one that is over.
        color: const Color(0xF70B0709),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 208,
                    height: 128,
                    child: CustomPaint(painter: GameMark.panel()),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'خلصت',
                    style: TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 40,
                      height: 1.2,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    // The thesis, said out loud exactly once.
                    'كل باب عدّيت منه،\nانت اللي فتحته من قبل ما تحتاجه.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 17,
                      height: 1.9,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${_count(levels.length)}. وفيه كمان جاي.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: arabicFontFamily,
                      fontSize: 14,
                      height: 1.7,
                      color: _dim,
                    ),
                  ),
                  const SizedBox(height: 34),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _Button(label: 'المراحل', onTap: onLevels),
                      _Button(
                        label: 'من أول مرحلة',
                        onTap: onRestart,
                        quiet: true,
                      ),
                    ],
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

/// How many levels, in Arabic that agrees with itself.
///
/// Not `'$n مراحل'`: three to ten take the plural, eleven and up take the
/// singular, and the campaign is a list that is meant to grow — a server can
/// append to it, so the number here is not a constant anybody will remember to
/// re-read.
String _count(int levels) => switch (levels) {
  1 => 'مرحلة واحدة',
  2 => 'مرحلتين',
  <= 10 => '${_arabicDigits(levels)} مراحل',
  _ => '${_arabicDigits(levels)} مرحلة',
};

/// Western digits read as a foreign object in the middle of an Arabic
/// sentence set in an Arabic face. The readout in the corner keeps its Latin
/// ones — that is a gauge, in a monospace, and it is not a sentence.
String _arabicDigits(int value) => '$value'.replaceAllMapped(
  RegExp(r'[0-9]'),
  (digit) => String.fromCharCode(0x0660 + int.parse(digit[0]!)),
);

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
            color: quiet ? CampaignEnd._dim : CampaignEnd._ink,
          ),
        ),
      ),
    );
  }
}
