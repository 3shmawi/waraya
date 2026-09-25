import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../game/character/figure.dart';
import '../game/sky_backdrop.dart';
import '../level/level.dart';
import '../licenses.dart';

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
                    child: CustomPaint(painter: _Mark()),
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

/// The game's mark: you, and the two of you still walking behind.
///
/// The same picture as `site/logo.svg`, drawn with the game's own [Figure]
/// rather than a second set of proportions — so the body on the ending is the
/// body in the levels, down to the tilt it runs with.
///
/// It needs its patch of sunset. The two behind are the shadow's pale cold
/// colour and the one in front is the player's black, and black on the near
/// black this screen is painted in would be a gap rather than a body.
class _Mark extends CustomPainter {
  const _Mark();

  /// Walking left, out of the frame they came in through.
  static const double _facing = -1;

  /// Heights and the ground line as fractions of the tile's height, off
  /// `site/logo.svg`.
  static const double _bodyHeight = 0.55;
  static const double _groundY = 0.80;

  /// Where each body stands, across the tile.
  ///
  /// Wider apart than the logo has them, because the logo is a square app
  /// icon and this is not. The bodies are drawn running, and a running stride
  /// is nearly half a body wide — at the icon's spacing the three of them
  /// came out as one blur with six legs.
  static const List<double> _at = [0.78, 0.55, 0.32];
  /// Stronger than the logo's 0.30 and 0.55. The shadow reads in the game
  /// because it is *cold* against a warm sky, and thinning it down towards
  /// the sky's own brightness is what takes that away.
  static const List<double> _alpha = [0.45, 0.72, 1.0];

  /// Half a stride between one body and the next.
  ///
  /// Half rather than some prettier fraction because the gait plants a foot
  /// at 0 and π and lifts the whole body in between: at anything else one of
  /// the three is caught mid-flight, and a body hanging above the ground in a
  /// picture that is not moving reads as floating rather than as running.
  /// Half a stride also alternates which leg is forward, so they do not come
  /// out as three copies of one pose.
  static const double _phaseStep = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(0, 0, size.width, size.height);
    final rounded = RRect.fromRectAndRadius(
      box,
      Radius.circular(size.height * 0.18),
    );
    canvas.save();
    canvas.clipRRect(rounded);

    final ground = size.height * _groundY;
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, ground),
          SkyBackdrop.colors,
          SkyBackdrop.stops,
        ),
    );

    // Oldest first, so the body you are now is painted over the top of them.
    for (var i = 0; i < _at.length; i++) {
      final ahead = _at.length - 1 - i;
      canvas.save();
      canvas.translate(size.width * _at[i], ground);
      Figure(
        height: size.height * _bodyHeight,
        color: i == _at.length - 1
            ? SilhouettePalette.bodyColor
            : SilhouettePalette.shadowColor.withValues(alpha: _alpha[i]),
      ).render(
        canvas,
        phase: -ahead * _phaseStep,
        moving: true,
        airborne: false,
        facing: _facing,
      );
      canvas.restore();
    }

    // The ground they are all walking on, lit along its top edge by the same
    // backlight everything else in this game is cut out of.
    canvas.drawRect(
      Rect.fromLTRB(0, ground, size.width, size.height),
      Paint()..color = SilhouettePalette.blockFill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, size.height * 0.016),
      Paint()..color = SilhouettePalette.blockTop,
    );
    canvas.restore();

    // The ground inside the tile and the screen behind it are both very near
    // black, so without this the mark looks like it stops at the lit line and
    // the two bottom corners are nowhere.
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x33FFE7B0),
    );
  }

  @override
  bool shouldRepaint(_Mark oldDelegate) => false;
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
            color: quiet ? CampaignEnd._dim : CampaignEnd._ink,
          ),
        ),
      ),
    );
  }
}
