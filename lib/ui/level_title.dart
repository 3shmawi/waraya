import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../level/level_game.dart';
import '../licenses.dart';
import 'level_hud.dart';

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
  LevelTitle({required this.game, required this.hud}) : super(priority: 1000);

  final LevelGame game;

  /// The readout in the opposite corner. Read, never written: the title has to
  /// know where it ends to know whether it fits beside it.
  final LevelHud hud;

  Vector2 _viewport = Vector2.zero();

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
    _viewport = size;
    // Same shrink as the readout, so the two stay in proportion.
    scale.setAll(LevelHud.readoutScale(size));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _nameText.text = game.level.name;
    _teachesText.text = game.completed ? 'خلصت.' : game.level.teaches;
    _place();
  }

  /// Top right, unless the readout is already using that room.
  ///
  /// On a phone held upright the two of them landed on top of each other —
  /// the level's name printed straight through "delay 3.5s". Rather than pick
  /// a breakpoint, it measures: if what is left of the width after the readout
  /// cannot hold the title, the title drops below the readout instead, still
  /// against the right edge.
  void _place() {
    if (_viewport.x == 0) return;
    final widest = max(_nameText.size.x, _teachesText.size.x) * scale.x;
    final hudRight = hud.position.x + hud.size.x * hud.scale.x;
    final fitsBeside = _viewport.x - hudRight - 24 >= widest;
    position = fitsBeside
        ? Vector2(_viewport.x - 16, 14)
        : Vector2(
            _viewport.x - 16,
            hud.position.y + hud.size.y * hud.scale.y + 12,
          );
  }
}
