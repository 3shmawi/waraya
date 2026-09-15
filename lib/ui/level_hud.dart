import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../level/level_game.dart';

/// The in-world readout for the shadow lab.
///
/// The delay gets its own oversized line for a reason that is not debugging:
/// the plan's TikTok note says the clip that explains this game is the player,
/// the shadow, and **the delay number visible on screen**. A number burned
/// into the frame needs no caption and no voiceover.
class LevelHud extends PositionComponent {
  LevelHud({required this.game})
    : super(position: Vector2.all(12), priority: 1000);

  final LevelGame game;

  static final _big = TextPaint(
    style: const TextStyle(
      fontSize: 30,
      height: 1.1,
      color: Color(0xFF1A1A1A),
      fontFamily: 'LiberationMono',
    ),
  );

  static final _small = TextPaint(
    style: const TextStyle(
      fontSize: 13,
      height: 1.45,
      color: Color(0xFF2C2C2C),
      fontFamily: 'LiberationMono',
    ),
  );

  final FpsComponent _fps = FpsComponent();
  late final TextComponent _delayText;
  late final TextComponent _statusText;
  final Paint _panel = Paint()..color = const Color(0x33FFFFFF);

  @override
  Future<void> onLoad() async {
    await add(_fps);
    _delayText = TextComponent(
      textRenderer: _big,
      position: Vector2.all(10),
      priority: 1,
    );
    _statusText = TextComponent(
      textRenderer: _small,
      position: Vector2(10, 48),
      priority: 1,
    );
    await addAll([_delayText, _statusText]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    scale.setAll((size.y / 720).clamp(0.55, 1.0));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final settings = game.settings;
    final recorder = game.recorder;
    final waiting = recorder.secondsUntilPlaying;

    _delayText.text = 'delay ${settings.delaySeconds.toStringAsFixed(1)}s';
    final many = game.levels.length > 1;
    _statusText.text = [
      // The level's own name is in the level data and is in Arabic, which the
      // bundled monospace font has no glyphs for. Rendering it needs an Arabic
      // face bundled and licensed the way Liberation Mono is — a real task,
      // not a line, and until then a number beats a row of empty boxes.
      if (many) 'level      ${game.levelIndex + 1} / ${game.levels.length}',
      if (game.completed) 'done       ✓',
      waiting > 0
          ? 'shadow     arrives in ${waiting.toStringAsFixed(1)}s'
          : 'shadow     live · ${recorder.delayTicks} ticks buffered',
      'solid      ${_onOff(settings.shadowIsSolid)}    '
          'kills ${_onOff(settings.shadowKills)}',
      if (!many)
        'opacity    ${settings.shadowOpacity.toStringAsFixed(2)}    '
            'trail ${_onOff(settings.showTrail)}',
      'reloads    ${game.reloads}   (R)',
      'fps        ${_fps.fps.toStringAsFixed(0)}',
    ].join('\n');

    size = Vector2(
      _delayText.size.x > _statusText.size.x
          ? _delayText.size.x + 20
          : _statusText.size.x + 20,
      _statusText.position.y + _statusText.size.y + 10,
    );
  }

  static String _onOff(bool value) => value ? 'on ' : 'off';

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(6)),
      _panel,
    );
  }
}
