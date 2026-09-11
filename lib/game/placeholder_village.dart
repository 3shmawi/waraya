import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'config.dart';

/// Throwaway art for Friday 1, all of it replaced on Friday 2 by the
/// photographed silhouette layers.
///
/// It reads as a Delta village rather than a city skyline: low wide roofs with
/// water tanks instead of towers, a casuarina windbreak on the horizon, palms
/// breaking the horizontal, and a line of leaning poles carrying sagging wire.
/// None of this is meant to be good -- it exists so camera-follow, the input
/// abstraction and the depth ordering can be judged by eye on a real device,
/// and so Friday 1 screenshots do not advertise the wrong setting.
///
/// Every band is deterministic (fixed seeds) so screenshots stay comparable
/// across platforms, and every band spans [villageSpan] so no edge enters view
/// on an ultrawide desktop.
const double villageSpan = 12000;

/// Base class for the flat bands: build a [Path] once, draw it once.
abstract class _Band extends PositionComponent {
  _Band({required this.color, required int seed, super.priority})
    : random = Random(seed);

  final Color color;
  final Random random;

  late final Paint paint = Paint()..color = color;
  final Path path = Path();

  /// Fills [path] with this band's shapes.
  void build();

  @override
  void onLoad() => build();

  @override
  void render(Canvas canvas) => canvas.drawPath(path, paint);

  /// A uniform double in [min, max).
  double between(double min, double max) =>
      min + random.nextDouble() * (max - min);
}

/// The casuarina windbreak on the horizon: a soft, ragged hedge rather than
/// the hard rectangles a city skyline would give.
class PlaceholderTreeline extends _Band {
  PlaceholderTreeline({
    required super.color,
    required super.seed,
    super.priority,
  });

  @override
  void build() {
    for (var x = -villageSpan / 2; x < villageSpan / 2; x += between(16, 30)) {
      final height = between(70, 135);
      final rx = between(14, 26);
      // The oval has to reach below the horizon, or a sliver of bright sky
      // shows between the hedge and the ground wherever the village row has
      // a gap.
      path.addOval(
        Rect.fromCenter(
          center: Offset(x, WarayaConfig.horizonY + 20 - height / 2),
          width: rx * 2,
          height: height,
        ),
      );
    }
  }
}

/// Low flat roofs, most of them one or two storeys, a good share carrying a
/// water tank and some an antenna. A minaret every so often.
class PlaceholderVillageRow extends _Band {
  PlaceholderVillageRow({
    required super.color,
    required super.seed,
    super.priority,
  });

  @override
  void build() {
    var x = -villageSpan / 2;
    var untilMinaret = random.nextInt(6) + 4;

    while (x < villageSpan / 2) {
      if (untilMinaret == 0) {
        _minaret(x + 40);
        untilMinaret = random.nextInt(7) + 5;
        x += 120;
        continue;
      }
      untilMinaret--;

      final width = between(150, 330);
      final height = between(70, 165);
      final roofY = WarayaConfig.horizonY - height;
      path.addRect(Rect.fromLTWH(x, roofY, width, height));

      if (random.nextDouble() < 0.45) {
        _waterTank(x + between(18, width - 40), roofY);
      }
      if (random.nextDouble() < 0.3) {
        final ax = x + between(20, width - 20);
        path.addRect(Rect.fromLTWH(ax, roofY - between(45, 80), 3, 80));
      }

      // A gap sometimes, so the row does not read as one continuous wall.
      x += width + (random.nextDouble() < 0.35 ? between(30, 90) : 0);
    }
  }

  void _waterTank(double cx, double roofY) {
    const w = 22.0;
    const h = 30.0;
    path.addRRect(
      RRect.fromLTRBR(cx, roofY - h, cx + w, roofY, const Radius.circular(5)),
    );
    // The little stand it always sits on.
    path.addRect(Rect.fromLTWH(cx + 2, roofY - 4, w - 4, 6));
  }

  void _minaret(double cx) {
    final height = between(230, 300);
    final top = WarayaConfig.horizonY - height;
    path.addRect(
      Rect.fromLTRB(cx - 9, top + 40, cx + 9, WarayaConfig.horizonY),
    );
    // Balcony and cap.
    path.addRect(Rect.fromLTRB(cx - 16, top + 34, cx + 16, top + 44));
    path.addOval(Rect.fromLTRB(cx - 9, top, cx + 9, top + 38));
  }
}

/// Date palms: the single most legible Egyptian silhouette, and the shape that
/// stops the band reading as a city.
class PlaceholderPalms extends _Band {
  PlaceholderPalms({required super.color, required super.seed, super.priority});

  final Path _fronds = Path();
  late final Paint _frondPaint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;

  @override
  void build() {
    for (
      var x = -villageSpan / 2;
      x < villageSpan / 2;
      x += between(260, 620)
    ) {
      _palm(x, between(190, 330));
    }
  }

  void _palm(double cx, double height) {
    // Real palms lean and no two crowns match, so vary both -- a row of
    // identical palms reads as wallpaper rather than as trees.
    final lean = between(-14, 14);
    final topX = cx + lean;
    final top = WarayaConfig.horizonY - height;
    path.addPath(
      Path()
        ..moveTo(cx - 7, WarayaConfig.horizonY)
        ..lineTo(topX - 5, top)
        ..lineTo(topX + 5, top)
        ..lineTo(cx + 7, WarayaConfig.horizonY)
        ..close(),
      Offset.zero,
    );

    final count = 8 + random.nextInt(5);
    final length = height * between(0.30, 0.40);
    final droop = between(0.40, 0.75);
    for (var i = 0; i < count; i++) {
      final t = i / (count - 1);
      final angle = -pi * 0.95 + t * pi * 0.9 + between(-0.06, 0.06);
      final dx = cos(angle);
      final dy = sin(angle);
      final reach = length * between(0.8, 1.15);
      _fronds.moveTo(topX, top);
      _fronds.quadraticBezierTo(
        topX + dx * reach * 0.55,
        top + dy * reach * 0.8,
        topX + dx * reach,
        top + dy * reach + reach * droop,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(path, paint);
    canvas.drawPath(_fronds, _frondPaint);
  }
}

/// The nearest band: poles with crossbars and the wire sagging between them.
class PlaceholderPoles extends _Band {
  PlaceholderPoles({required super.color, required super.seed, super.priority});

  final Path _wires = Path();
  late final Paint _wirePaint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  @override
  void build() {
    double? previousX;
    double previousTop = 0;

    for (
      var x = -villageSpan / 2;
      x < villageSpan / 2;
      x += between(380, 520)
    ) {
      final height = between(210, 280);
      final top = WarayaConfig.horizonY - height;
      path.addRect(Rect.fromLTRB(x - 5, top, x + 5, WarayaConfig.horizonY));
      path.addRect(Rect.fromLTRB(x - 46, top + 16, x + 46, top + 24));

      if (previousX != null) {
        for (final offset in const [20.0, 44.0]) {
          final y1 = previousTop + offset;
          final y2 = top + offset;
          _wires.moveTo(previousX, y1);
          _wires.quadraticBezierTo(
            (previousX + x) / 2,
            max(y1, y2) + between(40, 70),
            x,
            y2,
          );
        }
      }
      previousX = x;
      previousTop = top;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawPath(path, paint);
    canvas.drawPath(_wires, _wirePaint);
  }
}

/// Flat fill from the horizon down, so the scene reads as ground the character
/// stands on rather than sky all the way to the bottom.
class PlaceholderGround extends PositionComponent {
  PlaceholderGround({required this.color, super.priority});

  final Color color;

  late final Paint _paint = Paint()..color = color;
  late final Rect _rect = Rect.fromLTRB(
    -villageSpan / 2,
    WarayaConfig.horizonY,
    villageSpan / 2,
    // Overdraw past the bottom so no device height exposes an edge.
    WarayaConfig.worldHeight * 2,
  );

  @override
  void render(Canvas canvas) => canvas.drawRect(_rect, _paint);
}
