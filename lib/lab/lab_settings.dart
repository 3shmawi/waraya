import 'package:flutter/foundation.dart';

/// The four-and-a-half numbers Phase 2 exists to answer.
///
/// The plan is blunt about this: the point of the phase is not writing the
/// shadow, it is *playing with the numbers* until the mechanic either becomes
/// fun or provably isn't. So every one of these is live-tunable while the game
/// runs, and none of them has a "correct" value baked in yet — especially not
/// the delay.
class LabSettings extends ChangeNotifier {
  static const double minDelay = 0.5;
  static const double maxDelay = 6.0;
  static const double minOpacity = 0.2;
  static const double maxOpacity = 1.0;

  /// Deliberately not 3. The plan says not to assume it; 2.6s is just where
  /// the button test in this scene happens to be walkable, and it is meant to
  /// be dragged around.
  double _delaySeconds = 2.6;
  double get delaySeconds => _delaySeconds;
  set delaySeconds(double value) =>
      _set(() => _delaySeconds = value.clamp(minDelay, maxDelay));

  /// Can the player stand on the shadow?
  bool _shadowIsSolid = true;
  bool get shadowIsSolid => _shadowIsSolid;
  set shadowIsSolid(bool value) => _set(() => _shadowIsSolid = value);

  /// Does touching the shadow kill the player?
  bool _shadowKills = false;
  bool get shadowKills => _shadowKills;
  set shadowKills(bool value) => _set(() => _shadowKills = value);

  /// Where "a real thing in the world" turns into "a ghost".
  double _shadowOpacity = 0.5;
  double get shadowOpacity => _shadowOpacity;
  set shadowOpacity(double value) =>
      _set(() => _shadowOpacity = value.clamp(minOpacity, maxOpacity));

  /// Draw the path the shadow is about to walk. Does knowing kill the puzzle?
  bool _showTrail = false;
  bool get showTrail => _showTrail;
  set showTrail(bool value) => _set(() => _showTrail = value);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }
}
