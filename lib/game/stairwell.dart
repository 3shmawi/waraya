import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'atmosphere/dust_field.dart';
import 'atmosphere/god_rays.dart';
import 'atmosphere/haze_veils.dart';
import 'atmosphere/vignette.dart';
import 'config.dart';
import 'endless.dart';
import 'scenery.dart';

/// The second chapter's place: a stairwell (`docs/phase-12-more.md` §4).
///
/// **Placeholder, on purpose.** The art direction is photo-to-silhouette, and
/// the photographs are the owner's to take — a real stairwell, thresholded
/// into bands like the rooftops were. Until they exist, this draws the same
/// shapes with paths: flights of stairs going up behind you, a window onto
/// the light shaft, a timer bulb on each landing, a flat door, the meter
/// boxes and their cables, and the line where the oil paint on the lower
/// half of the wall stops and the whitewash starts. When the photographs
/// arrive they replace [world]'s two rows and nothing else moves.
///
/// Why this place for this chapter: the bulb on a stair landing is on a
/// timer, and it goes out on its own — the light switch the chapter is built
/// on is a thing every reader in Cairo has stood in the dark waiting for.
///
/// The ladder of values is the rooftops' rule turned indoors: the wall is the
/// lightest thing, each row in front of it is darker, and the level's own
/// blocks are the darkest of all. Warm all the way down, so the past — pale
/// and cold — is still the one colour in frame nothing else has.
///
/// Nothing here is random and nothing reads the clock. Every tile is a pure
/// function of its index ([noise]), so a clip rendered twice is the same clip.
class Stairwell implements PlaceScene {
  const Stairwell({required this.view, required this.groundY});

  final ValueGetter<Rect> view;

  /// World y the rows stand on: the level's lowest ground.
  final double groundY;

  /// The plaster, lit from above: the shaft every stairwell is built round
  /// has its sky at the top, so the wall is lightest up there and darkens
  /// towards the floor.
  ///
  /// Not darker at the top, which was the first version: the level's name is
  /// dark ink written up there for a bright sky, and on a dark ceiling it
  /// could not be read. And light enough all the way down for the blocks —
  /// the darkest things in the scene — to stand out of it.
  static const wallStops = <double>[0.0, 0.5, 0.8, 1.0];
  static const wallColors = <Color>[
    Color(0xFFB89466),
    Color(0xFFA68352),
    Color(0xFF8E6E44),
    Color(0xFF7E613C),
  ];

  /// The stairs going up behind you, through the haze. Close to the wall on
  /// purpose: a landing slab drawn any darker is a ledge, and the player
  /// tries to jump on it. What can be stood on has the warm rim on top; the
  /// stairs never do.
  static const farColor = Color(0xFF86683F);

  /// The landing you are on: a door, the meters.
  static const nearColor = Color(0xFF5C4629);

  /// The window onto the shaft. Only a little lighter than the wall: a
  /// bright window behind a lamp of the level's own makes it unclear which
  /// light is the one that switches your past off.
  static const windowColor = Color(0xFFC6A574);

  /// The bulb, and the glow of the timer button beside it.
  static const bulbColor = Color(0xFFFFE7B0);

  @override
  Future<void> preload() async {}

  @override
  List<Component> world() => [
    StairFlights(view: view, groundY: groundY, priority: -40),
    LandingWall(view: view, groundY: groundY, priority: -30),
  ];

  @override
  Component sky() => StairwellWall();

  @override
  List<Component> air() => [
    // Out of the window, high and to the left, and weaker than the sun's: a
    // shaft is a narrow piece of sky.
    GodRays(
      color: const Color(0xFFFFE2A8),
      strength: 0.05,
      count: 4,
      origin: const Offset(0.3, -0.35),
      seed: 71,
      priority: 90,
    ),
    HazeVeils(
      color: const Color(0xFFB08A58),
      maxOpacity: 0.14,
      seed: 59,
      priority: 95,
    ),
    // Fewer motes than the street, and slower to read as still air.
    DustField(
      color: const Color(0xFFE8CFA0),
      motesPerLayer: 140,
      seed: 43,
      priority: 100,
    ),
    // Heavier than outdoors: it is a closed room.
    Vignette(color: const Color(0xFF0A0705), strength: 0.6, priority: 110),
  ];
}

/// The wall behind everything, in the camera's backdrop like the sky is.
class StairwellWall extends PositionComponent {
  StairwellWall() : super(priority: -1000);

  final Paint _paint = Paint();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
    // Ending at the same height the sky's ramp does, for the same reason:
    // the brightest plaster is just above the floor, where the bulb is.
    final horizonOnScreen =
        size.y * WarayaConfig.horizonY / WarayaConfig.worldHeight;
    _paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, horizonOnScreen),
      Stairwell.wallColors,
      Stairwell.wallStops,
    );
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _paint);
  }
}

/// One row of tiles, scrolled by depth the way `PhotoBand` scrolls a
/// photograph, each tile recorded once into a picture and kept while it is
/// near the view.
abstract class DepthRow extends PositionComponent {
  DepthRow({
    required this.view,
    required this.groundY,
    required this.depth,
    required this.tileWidth,
    super.priority,
  });

  final ValueGetter<Rect> view;
  final double groundY;

  /// 0 = infinitely distant, 1 = in the world plane.
  final double depth;
  final double tileWidth;

  final Map<int, ui.Picture> _tiles = {};

  /// Draws tile [index] with its left edge at x 0 and the ground at y 0, so
  /// up is negative.
  void paintTile(Canvas canvas, int index);

  ui.Picture _tile(int index) => _tiles.putIfAbsent(index, () {
    final recorder = ui.PictureRecorder();
    paintTile(Canvas(recorder), index);
    return recorder.endRecording();
  });

  @override
  void render(Canvas canvas) {
    final rect = view();
    final shift = rect.center.dx * (1 - depth);
    final left = rect.left - shift;
    final first = (left / tileWidth).floor();
    final count = (rect.width / tileWidth).ceil() + 2;

    if (_tiles.length > 64) {
      _tiles.removeWhere((i, picture) {
        final far = i < first - 8 || i > first + count + 8;
        if (far) picture.dispose();
        return far;
      });
    }

    canvas.save();
    canvas.translate(shift, groundY);
    for (var i = first; i < first + count; i++) {
      canvas.save();
      canvas.translate(i * tileWidth, 0);
      canvas.drawPicture(_tile(i));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  void onRemove() {
    for (final picture in _tiles.values) {
      picture.dispose();
    }
    _tiles.clear();
    super.onRemove();
  }
}

/// The stairs, far back: a flight up to the right, a landing, a flight back
/// up to the left above it, and a window on the landing between them.
class StairFlights extends DepthRow {
  StairFlights({required super.view, required super.groundY, super.priority})
    : super(depth: 0.18, tileWidth: 620);

  static const int _salt = 83;

  final Paint _solid = Paint()..color = Stairwell.farColor;
  final Paint _rail = Paint()
    ..color = Stairwell.farColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  final Paint _baluster = Paint()
    ..color = Stairwell.farColor
    ..strokeWidth = 1.2;
  final Paint _grille = Paint()
    ..color = Stairwell.farColor
    ..strokeWidth = 2;
  final Paint _window = Paint()..color = Stairwell.windowColor;

  @override
  void paintTile(Canvas canvas, int index) {
    const landing = -220.0;
    const top = -440.0;

    // The window onto the shaft, behind the stairs so they cross it.
    final hasWindow = noise(index, _salt) < 0.7;
    if (hasWindow) {
      const window = Rect.fromLTRB(470, -400, 560, -250);
      canvas.drawRect(window, _window);
      // The iron grille, in the stairs' colour: it is between you and the
      // light, so it is a silhouette like everything else.
      for (var x = window.left + 18; x < window.right; x += 18) {
        canvas.drawLine(
          Offset(x, window.top),
          Offset(x, window.bottom),
          _grille,
        );
      }
      canvas.drawLine(
        Offset(window.left, window.center.dy),
        Offset(window.right, window.center.dy),
        _grille,
      );
    }

    _flight(canvas, from: const Offset(40, 0), to: const Offset(330, landing));
    // The landing slab.
    canvas.drawRect(
      const Rect.fromLTRB(330, landing, 460, landing + 22),
      _solid,
    );
    _flight(
      canvas,
      from: const Offset(460, landing),
      to: const Offset(170, top),
    );
    canvas.drawRect(const Rect.fromLTRB(40, top, 170, top + 22), _solid);

    // The timer bulb under the upper landing, and its button on the wall —
    // the only lit things in the row.
    if (noise(index, _salt ^ 0x2F) < 0.6) {
      _bulb(canvas, const Offset(395, landing - 150));
    }
  }

  /// One flight: a stepped top, a straight underside, a rail along it.
  void _flight(Canvas canvas, {required Offset from, required Offset to}) {
    const steps = 12;
    final run = (to.dx - from.dx) / steps;
    final rise = (to.dy - from.dy) / steps;
    final path = Path()..moveTo(from.dx, from.dy);
    var x = from.dx;
    var y = from.dy;
    for (var i = 0; i < steps; i++) {
      y += rise;
      path.lineTo(x, y);
      x += run;
      path.lineTo(x, y);
    }
    // The stringer under the treads, parallel to the pitch.
    path
      ..lineTo(to.dx, to.dy + 26)
      ..lineTo(from.dx + run, from.dy + 26)
      ..close();
    canvas.drawPath(path, _solid);

    // Balusters and the handrail on them.
    const railHeight = 70.0;
    for (var i = 0; i <= steps; i += 2) {
      final bx = from.dx + run * (i + 0.5);
      final by = from.dy + rise * (i + 1);
      canvas.drawLine(Offset(bx, by), Offset(bx, by - railHeight), _baluster);
    }
    canvas.drawLine(
      Offset(from.dx + run * 0.5, from.dy + rise - railHeight),
      Offset(to.dx - run * 0.5, to.dy - railHeight),
      _rail,
    );
  }

  void _bulb(Canvas canvas, Offset at) {
    canvas.drawCircle(
      at,
      60,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(at, 60, const [
          Color(0x40FFE7B0),
          Color(0x00FFE7B0),
        ]),
    );
    canvas.drawLine(at, at.translate(0, -30), _baluster);
    canvas.drawCircle(at, 4, Paint()..color = Stairwell.bulbColor);
    // The button you press for another minute of light.
    canvas.drawRect(
      Rect.fromCenter(center: at.translate(-46, 40), width: 6, height: 8),
      Paint()..color = const Color(0xFFFFB45E),
    );
  }
}

/// The landing you are standing on, nearer: the paint line, a flat door now
/// and then, and the meter boxes with their cables sagging between them.
class LandingWall extends DepthRow {
  LandingWall({required super.view, required super.groundY, super.priority})
    : super(depth: 0.5, tileWidth: 880);

  static const int _salt = 97;

  /// Where the oil paint stops and the whitewash starts.
  static const double dadoHeight = 120;

  final Paint _dado = Paint()..color = const Color(0x1A000000);
  final Paint _dadoLine = Paint()
    ..color = const Color(0x405C4629)
    ..strokeWidth = 2;
  final Paint _solid = Paint()..color = Stairwell.nearColor;
  final Paint _line = Paint()
    ..color = Stairwell.nearColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  final Paint _frame = Paint()
    ..color = Stairwell.nearColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  @override
  void paintTile(Canvas canvas, int index) {
    // Overlapping its neighbours by a unit, so the band has no hairline seams.
    canvas.drawRect(Rect.fromLTRB(-1, -dadoHeight, tileWidth + 1, 0), _dado);
    canvas.drawLine(
      const Offset(-1, -dadoHeight),
      Offset(tileWidth + 1, -dadoHeight),
      _dadoLine,
    );

    if (noise(index, _salt) < 0.65) {
      final x = 120 + noise(index, _salt ^ 0x11) * 260;
      _door(canvas, x);
    }

    if (noise(index, _salt ^ 0x23) < 0.55) {
      final x = 560 + noise(index, _salt ^ 0x37) * 160;
      _meters(canvas, x);
    }
  }

  /// A flat's door: a frame, two panels, a number plate. Outlined, not filled
  /// — a solid dark slab this tall standing in the frame is a thing the
  /// player tries to stand on (CLAUDE.md §8).
  void _door(Canvas canvas, double x) {
    final frame = Rect.fromLTRB(x, -232, x + 104, 0);
    canvas.drawRect(frame, _frame);
    canvas.drawRect(
      Rect.fromLTRB(frame.left + 14, frame.top + 18, frame.right - 14, -128),
      _line,
    );
    canvas.drawRect(
      Rect.fromLTRB(frame.left + 14, -112, frame.right - 14, -18),
      _line,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(frame.center.dx, frame.top + 10),
        width: 22,
        height: 9,
      ),
      _solid,
    );
  }

  /// Three meter boxes high on the wall, and the cable that leaves them.
  void _meters(Canvas canvas, double x) {
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(x + i * 30, -330 + (i.isOdd ? 6 : 0), 24, 34),
        _solid,
      );
    }
    final cable = Path()
      ..moveTo(x + 84, -318)
      ..quadraticBezierTo(x + 200, -270, tileWidth + 1, -322);
    canvas.drawPath(cable, _line);
    final down = Path()
      ..moveTo(x + 12, -296)
      ..quadraticBezierTo(x - 40, -200, x - 120, -300);
    canvas.drawPath(down, _line);
  }
}
