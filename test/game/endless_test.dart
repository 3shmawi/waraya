import 'dart:ui' show PictureRecorder;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waraya/game/endless.dart';

class _Row extends EndlessRow {
  _Row(Rect view)
    : super(visibleWorldRect: (() => view), spacing: 100, seed: 3);

  final List<int> built = [];

  @override
  Paint get fillPaint => Paint();

  @override
  void buildItem(EndlessItem item, int index, double x) {
    built.add(index);
    item.fill.addRect(Rect.fromLTWH(x, 0, 4, 4));
  }
}

void main() {
  test('scenery is generated as far out as the camera goes', () {
    // The bug this pins: everything used to be generated once over a fixed
    // span, so walking past about 20000 units ran off the end of the world and
    // the road, poles and palms simply stopped.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    for (final centre in [0.0, 25000.0, 400000.0, -180000.0]) {
      final row = _Row(Rect.fromLTWH(centre, 0, 1280, 720))..render(canvas);
      expect(
        row.built,
        isNotEmpty,
        reason: 'nothing was generated around x = $centre',
      );
      // Every item built has to land inside the view, give or take the margin.
      final xs = row.built.map(row.itemX);
      expect(xs.every((x) => x > centre - 500 && x < centre + 1780), isTrue);
    }
  });

  test('the same stretch of road is always generated the same way', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final view = Rect.fromLTWH(77000, 0, 1280, 720);

    final first = _Row(view)..render(canvas);
    final second = _Row(view)..render(canvas);

    expect(first.built, second.built);
    expect(
      first.built.map(first.itemX).toList(),
      second.built.map(second.itemX).toList(),
    );
  });

  test('noise is stable and stays inside its range', () {
    for (var i = -5000; i < 5000; i += 37) {
      final v = noise(i, 0x11);
      expect(v, inInclusiveRange(0, 1));
      expect(v, noise(i, 0x11));
    }
  });
}
