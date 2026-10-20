import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../level/lang.dart';
import '../licenses.dart';

/// The dark that covers the join between one level and the next.
///
/// Finishing a level used to be a cut: the goal filled in, and on some later
/// frame the whole screen was a different place — different ground, different
/// name in the corner, the body somewhere else. Nothing said *this level is
/// over*, so it read as the game jumping rather than as it moving on.
///
/// It is also hiding something real. `_build` empties the world and fills it
/// again, and between those two the scene is bare sky. That gap used to be
/// visible.
///
/// The opposite of [ResetFlash], on purpose. A reset is darkest on the frame
/// you are put back and clears while you are already moving, because the delay
/// never stops for you. This one goes the other way — down slowly, then up —
/// because here there is nothing left to play: the level is won, and the beat
/// of dark is the sentence ending.
class LevelFade extends PositionComponent {
  /// Above the readout and the level's name (both at 1000), which is the
  /// point: the name in the corner changes with the level, and watching the
  /// next level's title arrive before the next level does is the seam this
  /// exists to cover.
  LevelFade({super.priority = 1500});

  /// Seconds from clear to black once [cover] is called.
  static const double coverSeconds = 0.45;

  /// How long before the swap the covering starts, measured back from it.
  ///
  /// Deliberately longer than [coverSeconds]. Starting exactly one
  /// [coverSeconds] out would have the screen reach black on the very frame
  /// the world is emptied, with no margin — and it did not even manage that,
  /// because a tween summed one frame at a time lands a hair short. A tenth
  /// of a second of held black either side costs nothing and means the swap
  /// is never the frame that is still fading.
  static const double startsAt = 0.6;

  /// Seconds from black back to clear. Slower than the way down: arriving
  /// somewhere wants longer than leaving.
  static const double revealSeconds = 0.6;

  /// How long the dark holds with a new place's name in it, between the
  /// last level somewhere and the first level somewhere else
  /// (`docs/phase-12-more.md` §4). The name and nothing else: the place is
  /// the sentence.
  static const double chapterSeconds = 2.4;

  /// Seconds the name takes to come up out of the dark.
  static const double nameSeconds = 0.5;

  static const Color _ink = Color(0xFF0B0709);
  static const Color _nameColor = Color(0xFFF3E2C6);

  double _dark = 0;
  bool _covering = false;

  String? _chapter;
  Lang _chapterLang = Lang.ar;
  double _name = 0;

  /// The place being announced, while it is on screen. Read by tests.
  String? get chapter => _name > 0 || _covering ? _chapter : null;

  /// How much of the name is showing, 0 to 1. Read by tests.
  double get nameShowing => _name;

  /// How black the screen is, 0 to 1. Read by tests; the game writes it
  /// through [cover] and [reveal].
  double get darkness => _dark;

  /// Start going dark.
  void cover() => _covering = true;

  /// The swap has happened — come back. A place's name, if one is up, goes
  /// with the dark: the new place fades in through it.
  void reveal() => _covering = false;

  /// Holds the dark and puts [name] up in the middle of it. The game calls
  /// [reveal] once the new place is built, [chapterSeconds] later.
  void announce(String name, Lang lang) {
    _covering = true;
    _chapter = name;
    _chapterLang = lang;
  }

  /// Straight to black, with no tween on the way in.
  ///
  /// For a level put up from the menu: there is no level being left behind to
  /// fade out of, but there is still one arriving, and it should arrive the
  /// same way every other one does.
  void blackout() {
    _covering = false;
    _dark = 1;
    _chapter = null;
    _name = 0;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _dark = _covering
        ? (_dark + dt / coverSeconds).clamp(0.0, 1.0)
        : (_dark - dt / revealSeconds).clamp(0.0, 1.0);
    if (_chapter == null) return;
    // Up only once the screen is fully dark, so the name is never read over
    // the level it is leaving; down with the dark, never ahead of it.
    _name = _covering
        ? (_dark >= 1 ? (_name + dt / nameSeconds).clamp(0.0, 1.0) : _name)
        : _name.clamp(0.0, _dark);
    if (!_covering && _dark <= 0) _chapter = null;
  }

  @override
  void render(Canvas canvas) {
    if (_dark <= 0) return;
    canvas.drawRect(
      size.toRect(),
      Paint()..color = _ink.withValues(alpha: _dark),
    );
    final name = _chapter;
    if (name == null || _name <= 0) return;
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          fontFamily: arabicFontFamily,
          fontSize: 34,
          color: _nameColor.withValues(alpha: _name),
        ),
      ),
      textDirection: _chapterLang.isRtl ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
    );
    painter.dispose();
  }
}
