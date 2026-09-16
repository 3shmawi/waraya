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

  /// The least world width the camera will ever show.
  ///
  /// Pinning the world height and letting the width stretch is right on
  /// anything wider than it is tall, and falls apart on a phone held upright:
  /// a 412x915 screen shows 412 * 720 / 915 = 324 world units across, which is
  /// two jumps end to end. Reported from playing on a phone, and it makes a
  /// side-scroller unreadable — you cannot see what you are walking towards.
  ///
  /// So the height stays pinned right up until honouring it would show less
  /// world than this, and past that the width takes over and the screen simply
  /// shows more of the sky and more of the ground. Still no letterbox bars,
  /// which is the part of the original rule that actually mattered.
  static const double minVisibleWorldWidth = 760;

  /// Where the ground sits on screen, as a fraction of the height.
  ///
  /// Sampled from what a 16:9 screen already did, so nothing changes there.
  /// It matters on a phone: zooming out to get a usable width also shows far
  /// more vertically, and with the camera simply centred on the middle of the
  /// world that extra room all appeared *below* the floor as a dead black
  /// band. Holding the ground at a fixed height puts it in the sky instead,
  /// which is a sunset with dust in it rather than a slab of nothing.
  static const double groundOnScreen = 0.86;

  /// Where to point the camera vertically so [groundY] lands on
  /// [groundOnScreen] of a viewport [height] pixels tall at [zoom].
  static double viewpointY(double groundY, double height, double zoom) =>
      groundY - (groundOnScreen - 0.5) * (height / zoom);

  /// How far to zoom the camera for a viewport of [width] by [height] pixels.
  ///
  /// Shared by both scenes rather than written twice: the bench and the
  /// campaign have to frame the world identically or the numbers tuned in one
  /// are not the numbers played in the other.
  static double zoomFor(double width, double height) {
    final byHeight = height / worldHeight;
    final byWidth = width / minVisibleWorldWidth;
    return byHeight < byWidth ? byHeight : byWidth;
  }

  /// Ground line, measured in world units from the top.
  static const double horizonY = worldHeight * 0.72;

  /// How fast the probe walker moves, in world units per second.
  static const double walkSpeed = 220;

  /// Upward speed at the moment of a jump, in world units per second.
  ///
  /// With [gravity] this clears about 136 units, a little over the walker's own
  /// height, and stays in the air for roughly 0.8s.
  static const double jumpSpeed = 700;

  /// Upward-phase gravity, in world units per second squared.
  ///
  /// Deliberately unchanged by Phase 3: the reachable heights in the test
  /// scene are measured against it, and moving it would silently redesign the
  /// puzzles. Weight comes from the *fall*, not from the rise.
  static const double gravity = 1800;

  /// Downward-phase gravity. A body that falls faster than it rose is the
  /// oldest trick in platformers: it reads as weight without costing any of
  /// the airtime the player uses to aim.
  static const double fallGravity = 2900;

  /// Ceiling on falling speed, so a long drop stays survivable to look at and
  /// cannot tunnel through a floor in one frame.
  static const double maxFallSpeed = 1700;

  /// Releasing the jump key while still rising clips the climb to this
  /// fraction of [jumpSpeed] — a tap hops, a hold clears the platform.
  static const double jumpCutFactor = 0.4;

  /// How long after walking off an edge a jump still counts.
  ///
  /// The player pressed it, and on their screen they were still on the ledge.
  /// A tenth of a second is invisible and removes most "the game ate my
  /// input" complaints.
  static const double coyoteSeconds = 0.1;

  /// How early a jump can be pressed before landing and still fire on
  /// landing. The other half of the same complaint.
  static const double jumpBufferSeconds = 0.12;

  /// Ground acceleration, in world units per second squared: about a tenth of
  /// a second from standing to full speed.
  static const double groundAccel = 2400;

  /// Ground deceleration when nothing is held.
  static const double groundFriction = 3000;

  /// Turning around is sharper than setting off, or a change of direction
  /// feels like wading.
  static const double turnAccelFactor = 1.8;

  /// In the air you steer, you do not run: less authority than on the ground.
  static const double airAccel = 1500;

  /// Air drag is low, so a jump keeps the speed it launched with.
  static const double airFriction = 700;

  /// Landings softer than this do not shake the camera at all.
  static const double landingShakeThreshold = 700;

  /// How far the camera lurches on the hardest possible landing, in world
  /// units.
  static const double landingShakeMax = 7;

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
