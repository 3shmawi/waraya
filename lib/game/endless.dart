import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A deterministic pseudo-random value in [0, 1) from an index and a salt.
///
/// Every generator in the scene used to build its contents once, over a fixed
/// span, into a single path. Walking far enough simply ran off the end of it:
/// at 23000 units the poles, palms, weeds and road all stopped and only the
/// camera-relative bands carried on.
///
/// Deriving each item from its own index instead makes the road endless. Any
/// stretch can be produced on demand, identically every time, with nothing
/// stored and no seam where a period repeats.
double noise(int index, int salt) {
  // Deliberately double arithmetic rather than integer hashing. On the web an
  // int is a double and bitwise operations are 32-bit, so a 54-bit mask is not
  // merely slow there -- dart2js refuses to compile the literal at all, and the
  // first version of this function built fine on every other target and broke
  // the web build. IEEE 754 behaves the same everywhere, so this does too.
  final v = sin(index * 127.1 + salt * 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

/// Two paths for one item: [fill] is painted solid, [stroke] outlined.
class EndlessItem {
  EndlessItem();

  final Path fill = Path();
  final Path stroke = Path();
}

/// Scenery generated per index, for as far as the road goes.
///
/// Only the indices overlapping the view are built, and they are cached, so
/// walking costs one new item per [spacing] units travelled rather than a
/// rebuild.
abstract class EndlessRow extends PositionComponent {
  EndlessRow({
    required this.visibleWorldRect,
    required this.spacing,
    required this.seed,
    this.margin = 2,
    super.priority,
  });

  final ValueGetter<Rect> visibleWorldRect;

  /// Nominal distance between items; each is jittered off its slot.
  final double spacing;

  final int seed;

  /// How many items to build past each edge of the view, so nothing pops in.
  final int margin;

  final Map<int, EndlessItem> _cache = {};

  /// Paint for [EndlessItem.fill].
  Paint get fillPaint;

  /// Paint for [EndlessItem.stroke]; return null if the item has no stroke.
  Paint? get strokePaint => null;

  /// Where item [index] sits, in world x.
  double itemX(int index) =>
      index * spacing + (noise(index, seed) - 0.5) * spacing * 0.7;

  /// Builds one item. [x] is its world position.
  void buildItem(EndlessItem item, int index, double x);

  EndlessItem _itemAt(int index) => _cache.putIfAbsent(index, () {
    final item = EndlessItem();
    buildItem(item, index, itemX(index));
    return item;
  });

  @override
  void render(Canvas canvas) {
    final view = visibleWorldRect();
    final first = (view.left / spacing).floor() - margin;
    final last = (view.right / spacing).ceil() + margin;

    // Cheap eviction: the cache only ever holds a neighbourhood of the camera.
    if (_cache.length > 256) {
      _cache.removeWhere((index, _) => index < first - 32 || index > last + 32);
    }

    final stroke = strokePaint;
    for (var i = first; i <= last; i++) {
      final item = _itemAt(i);
      canvas.drawPath(item.fill, fillPaint);
      if (stroke != null) canvas.drawPath(item.stroke, stroke);
    }
  }
}
