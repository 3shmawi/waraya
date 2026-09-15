import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../level/level_game.dart';
import '../licenses.dart';

/// The level's name and its one line of teaching, top right.
///
/// Its own component rather than part of the debug readout, for two reasons:
/// this is the only text in the game meant for the player rather than for the
/// developer, and it is in Arabic, which belongs on the right.
///
/// The hint is deliberately one line and deliberately not instructions. The
/// plan's whole point is that the player works the mechanic out; this is the
/// nudge that stops a first-time player deciding the game is broken.
class LevelTitle extends PositionComponent {
  LevelTitle({required this.game}) : super(priority: 1000);

  final LevelGame game;

  static final _name = TextPaint(
    style: const TextStyle(
      fontSize: 24,
      height: 1.3,
      color: Color(0xFF1A1A1A),
      fontFamily: arabicFontFamily,
    ),
    // Right to left because the text is. With the default direction a
    // pure-Arabic line still shapes correctly but sits against the wrong edge
    // of its own box, so a right-anchored component lands in the wrong place.
    textDirection: TextDirection.rtl,
  );

  static final _teaches = TextPaint(
    style: const TextStyle(
      fontSize: 14,
      height: 1.5,
      color: Color(0xFF454545),
      fontFamily: arabicFontFamily,
    ),
    textDirection: TextDirection.rtl,
  );

  late final TextComponent _nameText;
  late final TextComponent _teachesText;

  @override
  Future<void> onLoad() async {
    _nameText = TextComponent(textRenderer: _name, anchor: Anchor.topRight);
    _teachesText = TextComponent(
      textRenderer: _teaches,
      anchor: Anchor.topRight,
      position: Vector2(0, 32),
    );
    await addAll([_nameText, _teachesText]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Same shrink as the debug readout, so the two stay in proportion on a
    // phone.
    scale.setAll((size.y / 720).clamp(0.55, 1.0));
    position = Vector2(size.x - 16, 14);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _nameText.text = game.level.name;
    _teachesText.text = game.completed ? 'خلصت.' : game.level.teaches;
  }
}
