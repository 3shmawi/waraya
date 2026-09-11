/// Design constants shared by every platform.
///
/// Phase 1 fixes the WORLD HEIGHT and lets the width stretch (see
/// [MaxViewport] usage in `WarayaGame`): a tall phone shows a narrower
/// horizontal slice, a wide desktop shows a wider one, and nobody gets
/// letterbox bars. Parallax layers must therefore be authored wider than the
/// widest expected viewport.
abstract final class WarayaConfig {
  /// Height of the visible world, in world units. Everything is authored
  /// against this number so art scales predictably across devices.
  static const double worldHeight = 720;

  /// The narrowest viewport we design for — a 19.5:9 phone held upright in
  /// landscape gives roughly this much width at [worldHeight].
  static const double referenceWorldWidth = 1280;

  /// Ground line, measured in world units from the top.
  static const double horizonY = worldHeight * 0.72;

  /// How fast the probe walker moves, in world units per second.
  static const double walkSpeed = 220;

  /// Taps landing in the top fraction of the screen mean "jump" rather than
  /// "walk", so a thumb resting low never fires a jump by accident.
  static const double touchJumpBandFraction = 0.45;
}
