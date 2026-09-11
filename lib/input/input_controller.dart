import 'package:flame/components.dart';

import 'input.dart';

/// Fans several [InputSource]s into one [InputIntent] per frame.
///
/// Every source stays live at once instead of being chosen by platform: a
/// phone in a desktop browser still gets touch, a tablet with a bluetooth
/// keyboard gets both, and adding a gamepad later means adding one list entry.
class InputController extends Component {
  InputController(this.sources);

  final List<InputSource> sources;

  InputIntent _intent = InputIntent.none;

  /// The merged intent for the current frame.
  InputIntent get intent => _intent;

  /// Label of the scheme the player is actually using, for the debug HUD.
  String get activeLabel {
    final used = sources.where((s) => s.hasBeenUsed).map((s) => s.label);
    return used.isEmpty ? 'waiting for input' : used.join(' + ');
  }

  /// Polls every source and caches the result. Called once per frame by
  /// `WarayaGame.update` before the rest of the tree updates, so every
  /// consumer sees the same intent.
  void refresh() {
    var merged = InputIntent.none;
    for (final source in sources) {
      merged = merged.merge(source.poll());
    }
    _intent = merged;
  }
}
