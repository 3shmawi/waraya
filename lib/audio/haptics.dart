import 'package:flutter/services.dart';

/// How hard a buzz is.
enum Buzz { light, medium, heavy }

/// Somewhere for a buzz to go — the same seam as `AudioOut`, for the same
/// reasons: tests feel nothing, and nothing in the game knows what a phone is.
abstract interface class HapticsOut {
  void buzz(Buzz strength);
}

/// The default: nothing. The bench, the tests and the gate run without one.
class NoHaptics implements HapticsOut {
  const NoHaptics();

  @override
  void buzz(Buzz strength) {}
}

/// Flutter's own haptics, no plugin. A desktop or a browser that has no motor
/// ignores the call, which is the answer wanted there.
class PlatformHaptics implements HapticsOut {
  PlatformHaptics({required this.enabled});

  /// Read on every buzz, so the settings switch takes effect mid-level.
  final bool Function() enabled;

  @override
  void buzz(Buzz strength) {
    if (!enabled()) return;
    // Fire and forget: a buzz that failed is not worth a frame.
    switch (strength) {
      case Buzz.light:
        HapticFeedback.selectionClick();
      case Buzz.medium:
        HapticFeedback.lightImpact();
      case Buzz.heavy:
        HapticFeedback.mediumImpact();
    }
  }
}
