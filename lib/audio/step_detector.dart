import 'dart:math';

import 'sfx.dart';

/// Turns the walk cycle into footstep sounds.
///
/// The gait is solved from a stride phase rather than played from a sheet
/// (see `Figure`), which means the exact moment a foot lands is already known
/// exactly: once per half-stride, as the phase passes 0 and π. Driving the
/// sound off the phase rather than off a timer keeps the step and the sound
/// together at any speed, including while a crouch slows the whole cycle
/// down.
class StepDetector {
  double? _previous;
  int _variant = 0;

  /// Returns the footstep to play, or null if no foot landed this frame.
  ///
  /// [phase] is the walker's stride phase, which only ever increases and wraps
  /// at 2π.
  Sfx? advance(double phase, {required bool moving, required bool grounded}) {
    final previous = _previous;
    _previous = phase;
    if (!moving || !grounded || previous == null) return null;

    // A footfall every half cycle. Comparing which half of the circle the
    // phase is in also catches the wrap from just under 2π to just over 0,
    // which a plain "did it pass π" check does not.
    if (phase ~/ pi == previous ~/ pi) return null;

    final sfx = Sfx.steps[_variant % Sfx.steps.length];
    _variant++;
    return sfx;
  }

  void reset() {
    _previous = null;
    _variant = 0;
  }
}
