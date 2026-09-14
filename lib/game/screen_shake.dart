import 'dart:math';

import 'package:flame/components.dart';

/// A decaying camera lurch.
///
/// Deliberately not a Flame effect on the viewfinder: the viewfinder is
/// already being written every frame by the camera's follow behaviour, and two
/// things setting the same position take turns rather than combining. This
/// produces an offset instead, and the game adds it after the follow has had
/// its say.
class ScreenShake {
  ScreenShake({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// How quickly a shake dies away, in strength per second.
  static const double decay = 6;

  double _strength = 0;
  final Vector2 _offset = Vector2.zero();

  /// The current displacement, in world units. Valid until the next
  /// [advance].
  Vector2 get offset => _offset;

  bool get isShaking => _strength > 0;

  /// Adds a knock of [strength] world units. Knocks do not stack past the
  /// largest one in flight, so a bad landing during a bad landing is not
  /// twice as violent.
  void hit(double strength) {
    if (strength > _strength) _strength = strength;
  }

  void advance(double dt) {
    if (_strength <= 0) {
      _offset.setZero();
      return;
    }
    _strength = max(0, _strength - decay * dt);
    _offset.setValues(
      (_random.nextDouble() * 2 - 1) * _strength,
      (_random.nextDouble() * 2 - 1) * _strength * 0.6,
    );
  }

  void reset() {
    _strength = 0;
    _offset.setZero();
  }
}
