import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'atmosphere/dust_field.dart';
import 'atmosphere/god_rays.dart';
import 'atmosphere/haze_veils.dart';
import 'atmosphere/vignette.dart';
import 'ground.dart';
import 'palm_row.dart';
import 'photo_band.dart';
import 'power_line.dart';
import 'sky_backdrop.dart';

/// The photographed environment, as something any scene can stand in.
///
/// It was assembled inline in `WarayaGame`, which was fine while there was one
/// scene. The puzzles want the same sky and the same dust, so it moved here
/// rather than being copied — and it takes the ground line as a parameter,
/// because a level's floor is wherever that level put it, not where the Phase
/// 1 walker's horizon happened to be.
///
/// Nothing here compiles a fragment program. Every layer is a photograph, a
/// gradient or a blend mode, which is why none of it can break on a web build.
class Scenery {
  const Scenery({
    required this.images,
    required this.view,
    required this.groundY,
    this.withGround = true,
    this.withPowerLine = true,
  });

  final Images images;

  /// The camera's visible rectangle, read every frame.
  final ValueGetter<Rect> view;

  /// World y the environment treats as the ground. The bands sit on it.
  final double groundY;

  /// Whether to draw the graded road and its roadside detail.
  ///
  /// False for the puzzles: a level brings its own floor, and a second ground
  /// plane underneath it is just haze in the wrong place.
  final bool withGround;

  /// Whether the poles and their wires are drawn.
  ///
  /// False for the puzzles. They are the one piece of this scene that stands
  /// *in* the play plane rather than behind it, and a dark vertical post the
  /// same value as a platform is a thing the player tries to stand on. Good
  /// atmosphere is not worth a misread jump.
  final bool withPowerLine;

  /// The photographs this scene is made of.
  static const List<String> assets = [
    'layer_far_treeline.webp',
    'layer_mid_treeline.webp',
    'palm_01.webp',
  ];

  /// Reads them into the cache. Call once, before [world].
  Future<void> preload() => images.loadAll(assets);

  /// The layers that belong in the world, behind whatever is in front of them.
  ///
  /// Synchronous, and that is load-bearing rather than tidy. The puzzles
  /// rebuild the world between levels; an `await` in the middle of that rebuild
  /// leaves the scene with no player in it for however long the decode takes,
  /// and input in that gap goes nowhere. Requiring [preload] first moves the
  /// waiting to startup, where there is nothing to interrupt.
  List<Component> world() {
    final far = images.fromCache(assets[0]);
    final mid = images.fromCache(assets[1]);
    final palm = images.fromCache(assets[2]);

    return [
      PhotoBand(
        image: far,
        depth: 0.15,
        heightUnits: 120,
        // Above the mid band's top edge, or it is hidden behind it entirely.
        bottomY: groundY - 96,
        visibleWorldRect: view,
        priority: -40,
      ),
      // Behind the mid band on purpose: only the crown clears the trees, which
      // is both how a village skyline looks and why the missing trunk in the
      // cut-out never shows.
      PalmRow(
        sprite: Sprite(palm),
        visibleWorldRect: view,
        heightUnits: 215,
        baseY: groundY - 130,
        priority: -35,
      ),
      PhotoBand(
        image: mid,
        depth: 0.45,
        heightUnits: 230,
        bottomY: groundY + 4,
        visibleWorldRect: view,
        priority: -30,
      ),
      if (withGround) ...[
        GroundPlane(
          // The horizon end carries the same haze the bands fade into; the
          // near end is the shadow the road sits in right under the camera.
          horizonColor: const Color(0xFF3D2609),
          nearColor: const Color(0xFF0E0805),
          visibleWorldRect: view,
          priority: -20,
        ),
        // Behind the walker, at the character's own depth.
        GroundDetail(
          color: const Color(0xFF1A1009),
          visibleWorldRect: view,
          baseY: groundY + 14,
          spacing: 110,
          seed: 29,
          priority: -18,
        ),
        // In front of the walker: the closest thing in the scene, so it sells
        // the speed of everything behind it.
        GroundDetail(
          color: const Color(0xFF0D0705),
          visibleWorldRect: view,
          baseY: groundY + 178,
          sizeScale: 3.4,
          spacing: 240,
          seed: 31,
          priority: 200,
        ),
      ],
      if (withPowerLine)
        PowerLine(
          color: const Color(0xFF1B1119),
          visibleWorldRect: view,
          baseY: groundY,
          priority: -5,
        ),
    ];
  }

  /// The sky. Goes in the camera's backdrop: the camera renders backdrop →
  /// world → viewport, so a sky in the viewport paints over the entire scene.
  Component sky() => SkyBackdrop();

  /// Dust, haze, light shafts and edge darkening, over the world and under
  /// any readout.
  List<Component> air() => [
    GodRays(color: const Color(0xFFFFE7B0), priority: 90),
    HazeVeils(color: const Color(0xFFE8B55E), priority: 95),
    DustField(color: const Color(0xFFF6D79A), priority: 100),
    Vignette(color: const Color(0xFF120A04), priority: 110),
  ];
}
