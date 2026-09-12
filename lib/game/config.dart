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

  /// Upward speed at the moment of a jump, in world units per second.
  ///
  /// With [gravity] this clears about 136 units, a little over the walker's own
  /// height, and stays in the air for roughly 0.8s.
  static const double jumpSpeed = 700;

  /// Downward acceleration, in world units per second squared.
  static const double gravity = 1800;

  /// Taps landing in the top fraction of the screen mean "jump" rather than
  /// "walk", so a thumb resting low never fires a jump by accident.
  static const double touchJumpBandFraction = 0.45;

  /// Width of the crouch zone, as a fraction of the screen, centred between
  /// the two walk halves of the lower band.
  static const double touchCrouchBandFraction = 0.2;

  /// How tall the character is while crouched, as a fraction of its standing
  /// height. Matched to the pose `Figure` draws at full crouch, so the head
  /// you can see clears exactly what the box you cannot see clears.
  static const double crouchHeightFactor = 0.72;

  /// How fast a crouched character moves, as a fraction of [walkSpeed].
  static const double crouchSpeedFactor = 0.45;

  /// How fast the character folds up and stands back up, in crouch fractions
  /// per second. Fast enough to feel like a button press, slow enough that
  /// the body does not teleport between two heights.
  static const double crouchRate = 9;
}
