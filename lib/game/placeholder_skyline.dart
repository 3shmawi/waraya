import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';

/// A band of flat blocks standing in for one silhouette depth layer.
///
/// PLACEHOLDER for Friday 2. It exists now for one reason: without something
/// in the world that has horizontal extent, camera-follow and the input
/// abstraction can't be verified by eye on a target device. The generated
/// shapes are deterministic (fixed [seed]) so screenshots are comparable
/// between platforms.
class PlaceholderSkyline extends PositionComponent {
  PlaceholderSkyline({
    required this.color,
    required this.span,
    required this.minHeight,
    required this.maxHeight,
    required this.blockWidth,
    required int seed,
    super.priority,
  }) : _random = Random(seed);

  final Color color;

  /// Total horizontal extent covered, centred on the world origin.
  final double span;
  final double minHeight;
  final double maxHeight;
  final double blockWidth;

  final Random _random;
  final List<Rect> _blocks = [];
  late final Paint _paint = Paint()..color = color;

  @override
  void onLoad() {
    for (var x = -span / 2; x < span / 2; x += blockWidth) {
      final height = minHeight + _random.nextDouble() * (maxHeight - minHeight);
      final width = blockWidth * (0.75 + _random.nextDouble() * 0.25);
      _blocks.add(
        Rect.fromLTWH(x, WarayaConfig.horizonY - height, width, height),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    for (final block in _blocks) {
      canvas.drawRect(block, _paint);
    }
  }
}
