import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../game/character/figure.dart';
import '../game/sky_backdrop.dart';
import '../level/level.dart';

/// The game's mark: you, and the two of you still walking behind.
///
/// The same picture as `site/logo.svg`, drawn with the game's own [Figure]
/// rather than a second set of proportions — so the body on the mark is the
/// body in the levels, down to the tilt it runs with. `tool/icons.dart`
/// paints this into every app icon the project ships, which is why it lives
/// in `lib` rather than inside the ending screen: the icon on the home screen
/// and the mark on the ending are one drawing, and a change to the figure
/// moves both.
///
/// It needs its patch of sunset. The two behind are the shadow's pale cold
/// colour and the one in front is the player's black, and black on the near
/// black the ending is painted in would be a gap rather than a body.
class GameMark extends CustomPainter {
  const GameMark({
    required this.at,
    required this.cornerRadius,
    required this.border,
    this.bodyHeight = 0.55,
    this.groundY = 0.80,
    this.scale = 1,
    this.phase = 0,
    this.entrance = 1,
  });

  /// On the ending screen, in a panel half again as wide as it is tall.
  ///
  /// The bodies stand wider apart here than the logo has them, because the
  /// logo is a square app icon and this is not. They are drawn running, and a
  /// running stride is nearly half a body wide — at the icon's spacing the
  /// three of them came out as one blur with six legs.
  const GameMark.panel({double entrance = 1})
    : this(
        at: const [0.78, 0.55, 0.32],
        cornerRadius: 0.18,
        border: true,
        entrance: entrance,
      );

  /// In a square tile, at the spacing and the corner `site/logo.svg` uses.
  ///
  /// [rounded] false is the full-bleed square an adaptive or maskable icon
  /// wants: the platform cuts its own shape out of it, and a tile that has
  /// already rounded its corners loses them to a second rounding. The
  /// hairline is dropped with it — it exists to keep the mark's bottom
  /// corners from vanishing into a dark screen, and an icon has no such
  /// screen behind it.
  ///
  /// [maskable] pulls the drawing into the safe zone the maskable-icon spec
  /// asks for — everything that matters inside the middle 80%, because the
  /// platform is allowed to cut a circle out of the tile and a circle loses
  /// the corners entirely. Without it the trailing body's feet, which sit low
  /// and far right, are the part that gets cut.
  const GameMark.icon({bool rounded = true, bool maskable = false})
    : this(
        at: const [0.665, 0.535, 0.405],
        cornerRadius: rounded ? 0.22 : 0,
        border: rounded,
        scale: maskable ? 0.82 : 1,
      );

  /// Where each body stands across the tile, oldest first — which is the
  /// order they are painted in, so the body you are now is on top.
  final List<double> at;

  /// As a fraction of the tile's shorter side. Zero is a plain rectangle.
  final double cornerRadius;

  /// The hairline round the outside. See [GameMark.icon].
  final bool border;

  /// Pulls the bodies and the ground line towards the middle of the tile,
  /// leaving the sky full bleed. One draws the whole tile. See
  /// [GameMark.icon].
  final double scale;

  /// An offset added to every body's pose, in radians.
  final double phase;

  /// How far through the walk-in, zero to one.
  ///
  /// One is settled, and settled is exactly the picture the icon draws — so
  /// an icon never passes this and the ending screen animates it from zero.
  ///
  /// They do not run on the spot. Each body's pose is a pure function of
  /// where it is: the phase it is drawn at is its finished pose minus the
  /// stride it still has to walk, which is the same rule the game itself uses
  /// (`Figure.strideLengthFor`) and the reason the planted foot does not
  /// slide. It also means the last frame of the walk-in *is* the static mark,
  /// down to which leg is forward.
  ///
  /// The order is the game's own. The black body is in front, so it set off
  /// first; the two pale ones are where it was, and they come in behind it,
  /// one after the other. The screen that states the mechanic out loud opens
  /// by doing it.
  final double entrance;

  /// Where they walk in from, in tile widths, right of the frame.
  static const double _entryFrom = 1.45;

  /// How much of the entrance each body waits behind the one ahead of it.
  static const double _stagger = 0.18;

  /// Heights and the ground line as fractions of the tile's height, off
  /// `site/logo.svg`.
  final double bodyHeight;
  final double groundY;

  /// Walking left, out of the frame they came in through.
  static const double _facing = -1;

  /// Oldest first, which is the order these are painted in — [pastFades] is
  /// nearest first, and it is the same ladder the game fades its shadows with.
  static List<double> get _alpha => pastFades.reversed.toList();

  /// Half a stride between one body and the next.
  ///
  /// Half rather than some prettier fraction because the gait plants a foot
  /// at 0 and π and lifts the whole body in between: at anything else one of
  /// the three is caught mid-flight, and a body hanging above the ground in a
  /// picture that is not moving reads as floating rather than as running.
  /// Half a stride also alternates which leg is forward, so they do not come
  /// out as three copies of one pose.
  static const double _phaseStep = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromLTWH(0, 0, size.width, size.height);
    final radius = math.min(size.width, size.height) * cornerRadius;
    final rounded = RRect.fromRectAndRadius(box, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rounded);

    final ground = size.height * (0.5 + (groundY - 0.5) * scale);
    canvas.drawRect(
      box,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, ground),
          SkyBackdrop.colors,
          SkyBackdrop.stops,
        ),
    );

    // Oldest first, so the body you are now is painted over the top of them.
    final bodyPx = size.height * bodyHeight * scale;
    final span = 1 - (at.length - 1) * _stagger;
    for (var i = 0; i < at.length; i++) {
      final ahead = at.length - 1 - i;
      final home = 0.5 + (at[i] - 0.5) * scale;

      // Nought for the body in front: it is the one that set off first.
      final t = ((entrance - ahead * _stagger) / span).clamp(0.0, 1.0);
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      final x = _entryFrom + (home - _entryFrom) * eased;

      // What it has not walked yet, wound back off its finished pose.
      final left = (x - home) * size.width;

      canvas.save();
      canvas.translate(size.width * x, ground);
      Figure(
        height: bodyPx,
        color: i == at.length - 1
            ? SilhouettePalette.bodyColor
            : SilhouettePalette.shadowColor.withValues(alpha: _alpha[i]),
      ).render(
        canvas,
        phase: phase - ahead * _phaseStep - left / (Figure.stride * bodyPx),
        moving: true,
        airborne: false,
        facing: _facing,
      );
      canvas.restore();
    }

    // The ground they are all walking on, lit along its top edge by the same
    // backlight everything else in this game is cut out of.
    canvas.drawRect(
      Rect.fromLTRB(0, ground, size.width, size.height),
      Paint()..color = SilhouettePalette.blockFill,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, ground, size.width, size.height * 0.016),
      Paint()..color = SilhouettePalette.blockTop,
    );
    canvas.restore();

    // The ground inside the tile and the screen behind it are both very near
    // black, so without this the mark looks like it stops at the lit line and
    // the two bottom corners are nowhere.
    if (border) {
      canvas.drawRRect(
        rounded,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x33FFE7B0),
      );
    }
  }

  @override
  bool shouldRepaint(GameMark oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.entrance != entrance;
}
