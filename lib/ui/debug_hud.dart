import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/config.dart';
import '../input/input_controller.dart';

/// On-screen readout of the things that differ per platform.
///
/// This is the actual Friday 1 deliverable: one build, three screens, and a
/// panel proving the viewport strategy and the input abstraction resolved
/// correctly on each of them. Toggle it off before shipping anything.
class DebugHud extends PositionComponent {
  DebugHud({required this.input, required this.visibleWorldRect})
    : super(position: Vector2.all(12), priority: 1000);

  final InputController input;

  /// Supplied by the game so the HUD doesn't need to know about the camera.
  final ValueGetter<Rect> visibleWorldRect;

  static final _style = TextPaint(
    style: const TextStyle(
      fontSize: 13,
      height: 1.45,
      color: Color(0xFFF4ECE2),
      fontFamily: 'monospace',
    ),
  );

  final FpsComponent _fps = FpsComponent();
  late final TextComponent _text;
  final Paint _panel = Paint()..color = const Color(0x66000000);

  @override
  Future<void> onLoad() async {
    await add(_fps);
    _text = TextComponent(
      textRenderer: _style,
      position: Vector2.all(10),
      priority: 1,
    );
    await add(_text);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // A phone in landscape is ~390 logical units tall, where a 13pt panel eats
    // a third of the screen. Shrink with the viewport so the overlay stays an
    // overlay on every target.
    scale.setAll((size.y / 720).clamp(0.55, 1.0));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final view = visibleWorldRect();
    _text.text = [
      'waraya · phase 1 / friday 1',
      'target     ${_targetName()}',
      'fps        ${_fps.fps.toStringAsFixed(0)}',
      'world      ${view.width.toStringAsFixed(0)} x '
          '${WarayaConfig.worldHeight.toStringAsFixed(0)} units',
      'camera x   ${view.center.dx.toStringAsFixed(0)}',
      'input      ${input.activeLabel}',
      'intent     ${input.intent}',
    ].join('\n');
    size = _text.size + Vector2.all(20);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(6)),
      _panel,
    );
  }

  String _targetName() {
    if (kIsWeb) {
      return 'web (${defaultTargetPlatform.name})';
    }
    return defaultTargetPlatform.name;
  }
}
