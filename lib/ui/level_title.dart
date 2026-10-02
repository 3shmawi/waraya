import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../level/lang.dart';
import '../level/level_game.dart';
import '../licenses.dart';
import 'level_hud.dart';
import 'words.dart';

/// The level's name and its one line, arriving in the middle of the screen and
/// then settling top right.
///
/// Its own component rather than part of the debug readout, for two reasons:
/// this is the only text in the game meant for the player rather than for the
/// developer, and in Arabic it belongs on the right.
///
/// **It arrives big and then gets out of the way** (`docs/phase-11-feel.md`
/// §3). The first player review said the name and the line under it were not
/// understood — and a line in the corner that is there for the whole level is
/// a line that is easy never to read at all. Big in the middle for a moment,
/// as the level fades up, it is read once; after that the screen is the level.
///
/// The line is deliberately one line and deliberately not instructions. The
/// whole point is that the player works the mechanic out; this is the nudge
/// that stops a first-time player deciding the game is broken.
class LevelTitle extends PositionComponent {
  LevelTitle({required this.game, required this.hud}) : super(priority: 1000);

  final LevelGame game;

  /// The readout in the opposite corner. Read, never written: the title has to
  /// know where it ends to know whether it fits beside it.
  final LevelHud hud;

  /// Seconds the title holds in the middle, then seconds it takes to settle.
  static const double holdSeconds = 2.2;
  static const double settleSeconds = 0.6;

  /// How much bigger it is in the middle than in the corner.
  static const double introScale = 1.6;

  Vector2 _viewport = Vector2.zero();
  int _epoch = -1;
  double _age = 0;

  static TextPaint _paint(double size, Color color, double height, Lang lang) =>
      TextPaint(
        style: TextStyle(
          fontSize: size,
          height: height,
          color: color,
          fontFamily: arabicFontFamily,
        ),
        // Right to left for Arabic. With the default direction a pure-Arabic
        // line still shapes correctly but sits against the wrong edge of its
        // own box, so a right-anchored component lands in the wrong place.
        textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
      );

  static final Map<Lang, TextPaint> _names = {
    for (final lang in Lang.values)
      lang: _paint(24, const Color(0xFF1A1A1A), 1.3, lang),
  };
  static final Map<Lang, TextPaint> _lines = {
    for (final lang in Lang.values)
      lang: _paint(14, const Color(0xFF454545), 1.5, lang),
  };

  late final TextComponent _nameText;
  late final TextComponent _teachesText;

  /// How far through its entrance the title is: 0 big in the middle, 1 in
  /// its corner.
  double get settled {
    if (!game.titleIntro) return 1;
    if (_age <= holdSeconds) return 0;
    final t = ((_age - holdSeconds) / settleSeconds).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(t);
  }

  @override
  Future<void> onLoad() async {
    _nameText = TextComponent(anchor: Anchor.topRight);
    _teachesText = TextComponent(
      anchor: Anchor.topRight,
      position: Vector2(0, 32),
    );
    await addAll([_nameText, _teachesText]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _viewport = size;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_epoch != game.levelEpoch) {
      _epoch = game.levelEpoch;
      _age = 0;
    }
    _age += dt;

    final level = game.level;
    final lang = game.lang;
    // The language of the words decides the direction, not the language that
    // was asked for — each line on its own, since a level can have its name
    // in English and its line only in Arabic.
    final english = lang == Lang.en;
    final done = game.completed;
    _direct(_nameText, _names, english && level.nameEn != null);
    _direct(_teachesText, _lines, english && (done || level.teachesEn != null));
    _nameText.text = level.nameIn(lang);
    _teachesText.text = done ? Words(lang).done : level.teachesIn(lang);
    _place();
  }

  /// Sets a line's paint, only when it changes. Flame lays the text out again
  /// on every assignment, and this runs every frame.
  static void _direct(
    TextComponent line,
    Map<Lang, TextPaint> paints,
    bool english,
  ) {
    final paint = paints[english ? Lang.en : Lang.ar]!;
    if (!identical(line.textRenderer, paint)) line.textRenderer = paint;
  }

  /// Between the middle and the corner, by [settled].
  void _place() {
    if (_viewport.x == 0) return;
    final small = LevelHud.readoutScale(_viewport);
    final corner = _corner(small);
    final t = settled;
    if (t >= 1) {
      scale.setAll(small);
      position = corner;
      return;
    }
    final big = small * introScale;
    final width = _widest * big;
    // Centred across, a little above the middle: the player is standing on
    // the ground line, and the title should not sit on top of them.
    final middle = Vector2(_viewport.x / 2 + width / 2, _viewport.y * 0.26);
    scale.setAll(big + (small - big) * t);
    position = middle + (corner - middle) * t;
  }

  double get _widest => max(_nameText.size.x, _teachesText.size.x);

  /// Top right, unless the readout or the buttons are already using that
  /// room.
  ///
  /// On a phone held upright the readout and the title landed on top of each
  /// other — the level's name printed straight through "delay 3.5s" — and
  /// later the retry and menu buttons did the same to the line under it,
  /// because this only knew about the readout. Rather than pick a breakpoint,
  /// it measures: if what is left of the width beside the readout and the
  /// buttons cannot hold the title, the title drops below both, still
  /// against the right edge.
  Vector2 _corner(double small) {
    final widest = _widest * small;
    final reserved = game.reservedTopRight;
    final hudRight = hud.position.x + hud.size.x * hud.scale.x;
    final right = _viewport.x - 16 - reserved.width;
    final fitsBeside = right - hudRight - 24 >= widest;
    if (fitsBeside) return Vector2(right, 14);
    final below = max(
      hud.position.y + hud.size.y * hud.scale.y,
      reserved.height,
    );
    return Vector2(_viewport.x - 16, below + 12);
  }
}
