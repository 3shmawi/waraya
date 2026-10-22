import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'level.dart';

/// What a barber's mirror did to a past this frame.
enum Crossing { across, back }

/// The two mirrors facing each other in a barber's shop
/// (`Level.barberMirrors`, on the bench): your past arrives on one and goes
/// on from the other ([BarberMirrorSpec]).
///
/// It keeps only who was on which glass last frame, by past, so that it can
/// tell an arrival from somebody still standing there — the same edge a key
/// and the other mirror answer. Where each past is, and how far away, is the
/// past's own ([ShadowFigure.away]); the game asks this which way to send it.
///
/// Drawn as what it is: two wide panes on the wall of a barber's shop, pale
/// glass in a thin frame with a strip of bulbs along the top, each over its
/// slab on the floor. Pale for the reason every upright in the game is pale
/// or lit — a dark slab standing in reach is something to climb — and not
/// solid. Both panes light together when a past goes through.
class BarberMirror extends PositionComponent {
  BarberMirror(this.spec, {this.look = LevelLook.greyBox, super.priority = -7});

  final BarberMirrorSpec spec;
  final LevelLook look;

  final Set<int> _onFrom = {};
  final Set<int> _onTo = {};

  /// From 1 the moment a past goes through, down to 0 a moment later.
  double _flash = 0;
  static const double _flashSeconds = 0.4;

  Rect get fromTrigger => BarberMirrorSpec.triggerOf(spec.from);
  Rect get toTrigger => BarberMirrorSpec.triggerOf(spec.to);

  /// Feeds where past [past] is this frame, and says what to do with it.
  ///
  /// [over] is whether it is across already. A past arriving on [from] goes
  /// across; one across arriving on [to] comes back. [warped] is a past put
  /// here by the other mirror, which did not arrive. Whatever it says, the
  /// past is then recorded as standing on the glass it is now at, so going
  /// through is never itself an arrival on the other side.
  Crossing? arrive(
    int past, {
    required bool onFrom,
    required bool onTo,
    required bool over,
    required bool warped,
  }) {
    final arrivedFrom = onFrom && !_onFrom.contains(past) && !warped;
    final arrivedTo = onTo && !_onTo.contains(past) && !warped;
    _set(_onFrom, past, onFrom);
    _set(_onTo, past, onTo);
    if (!over && arrivedFrom) {
      _onFrom.remove(past);
      _onTo.add(past);
      _flash = 1;
      return Crossing.across;
    }
    if (over && arrivedTo) {
      _onTo.remove(past);
      _onFrom.add(past);
      _flash = 1;
      return Crossing.back;
    }
    return null;
  }

  void _set(Set<int> on, int past, bool value) {
    if (value) {
      on.add(past);
    } else {
      on.remove(past);
    }
  }

  void reset() {
    _onFrom.clear();
    _onTo.clear();
    _flash = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flash = max(0, _flash - dt / _flashSeconds);
  }

  @override
  void render(Canvas canvas) {
    _pane(canvas, spec.from);
    _pane(canvas, spec.to);
  }

  /// One mirror: the slab on the floor, and the pane on the wall above it.
  void _pane(Canvas canvas, Rect slab) {
    final lit = look == LevelLook.silhouette;
    canvas.drawRect(
      slab,
      Paint()..color = lit ? SilhouettePalette.plateUp : Palette.plateDown,
    );
    final pane = Rect.fromLTRB(
      slab.left - 12,
      slab.top - 132,
      slab.right + 12,
      slab.top - 36,
    );
    final glass = lit ? const Color(0xFFDCE4EE) : const Color(0xFFE8E8E8);
    canvas.drawRect(
      pane,
      Paint()..color = glass.withValues(alpha: 0.32 + 0.4 * _flash),
    );
    // The sheen across the glass, which is what says glass.
    final sheen = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(pane.left + pane.width * 0.2, pane.bottom - 8),
      Offset(pane.left + pane.width * 0.45, pane.top + 8),
      sheen,
    );
    canvas.drawLine(
      Offset(pane.left + pane.width * 0.32, pane.bottom - 8),
      Offset(pane.left + pane.width * 0.52, pane.top + 22),
      sheen,
    );
    canvas.drawRect(
      pane,
      Paint()
        ..color = lit ? const Color(0x99FFE7B0) : const Color(0x99FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // The bulbs along the top, as every barber's mirror has.
    final bulb = Paint()
      ..color = lit ? const Color(0xFFFFE7B0) : const Color(0xFFFFFFFF);
    for (var x = pane.left + 10; x < pane.right - 4; x += 16) {
      canvas.drawCircle(Offset(x, pane.top - 5), 2.6, bulb);
    }
  }
}
