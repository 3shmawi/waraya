# Phase 1: turning photographs into layers

How the environment was made, and exactly what the source photographs did
and did not yield. Moved out of the README once the game had a mechanic to
lead with; none of it is out of date.

The tool is `tools/silhouette.py`.

## Turning photographs into layers

`tools/silhouette.py` converts a backlit photo into a tileable silhouette PNG.
It needs `pillow` and `numpy` (`pip install pillow numpy`).

```bash
python3 tools/silhouette.py photo.jpg \
    -o assets/images/layer_far_treeline.png \
    --crop 0.45,0.80 --height 720 --tile --verify
```

Because Flame repeats parallax layers (`ImageRepeat.repeatX`), **one ordinary
phone photo is enough — no panorama.** `--tile` cross-fades the right edge onto
the left so the repeat is invisible, and `--verify` writes a doubled strip so
the seam can be checked by eye.

Two knobs matter more than the rest, both verified against a gradient-sky test
frame:

- `--alpha-gamma 0.5` solidifies mid-tone objects. A grey water tank or a
  concrete parapet sits near the brightness threshold and otherwise comes out
  half transparent. Values below 1 also slightly thicken thin structures.
- `--flatten 0.15` divides out the sky's vertical gradient, for a sunset frame
  whose zenith is darker than the buildings. **It also eats large uniform dark
  regions** — the solid ground below the horizon goes semi-transparent — so
  prefer cropping to the horizon band and reach for `--flatten` only when a
  crop cannot separate them.

`--softness` (default 0.07) is the width of the alpha ramp and is what keeps
wires, antennas and palm fronds alive; a hard threshold deletes them.

Other options earned by real frames rather than guessed at:

- `--x-crop left,right` cuts a foreground object out of a band that is
  otherwise good — a tea glass sitting in the middle of a treeline, say.
- `--rotate degrees` levels a frame before cropping (positive is
  counter-clockwise). Phone frames are rarely level, and a sloped band
  staircases when it tiles. It fixes tilt, **not perspective** — see below.
- `--trim` crops transparent margins, for a discrete cut-out that code places
  rather than a band that tiles.
- `--feather-bottom 0.35` fades the bottom edge. A band floating above the
  horizon otherwise ends in a hard horizontal line straight across the screen.
- `--threshold` beats `--threshold auto` whenever a frame holds three tonal
  groups rather than two. Measure first: Otsu split a bright awning from
  everything else and left the sky opaque, where a measured 0.15 separated palm
  from sky exactly.
- The output extension picks the format. `.webp` cut the layer set from 808 KB
  to 320 KB; `--webp-quality 0` keeps a cut-out lossless so its alpha edges do
  not fringe.

### How photographic to make the layers

`--keep-texture --texture-gain 1.0` keeps the photograph's own colour and
detail instead of a flat fill, and `--haze <colour>:<amount>` mixes a layer
toward the sky so distance reads as lost contrast. Use a larger haze amount the
further back a layer sits — that is what makes depth read once the layers are
no longer flat shapes.

**The matte is a brightness cut, so it can only keep things darker than the
sky.** A backlit palm, pole or parapet comes out cleanly. A sunlit red brick
wall at midday is *brighter* than parts of the sky, so it is classified as sky
and cut away. Photographic realism therefore only works on frames shot against
the light; a full-colour daylight scene needs real masking (pen tool or
segmentation), which is a different order of work per layer.

Two further costs, both measured on a textured test frame: keeping texture
roughly doubled the file (57 KB flat, 123 KB textured, 110 KB textured+hazed),
and a textured layer makes the horizontal repeat obvious where a flat
silhouette hides it. Since web download size is the plan's main risk, prefer
texture on near layers, where it is most visible, and flatter, hazier art
further back.

## Verified so far

- Flutter 3.47.3 / Dart 3.13.3, flame 1.38.2 — matches the plan's minimums.
- `flutter analyze` clean, 14 tests passing.
- Web release build renders and responds to keyboard input at both 1600×900 and
  844×390, with no console errors.
- Linux desktop release binary builds and bundles.
- Three photographed bands render with parallax on the web build, 320 KB of
  WebP in total.
- `tools/silhouette.py` on the real photographs in `art/source`, not only on a
  synthetic frame.

### What the photographs actually yielded

`duststorm.jpg` carried the scene. Its sky is flat and bright and its trees are
dark, which is the one case a brightness matte handles cleanly, and both bands
come from it: a hazed far treeline and a full-texture mid treeline. Because
they share one frame they share one light, which is most of why the scene holds
together.

It is named rather than numbered on purpose. A later batch of photographs was
copied in as `src_01`–`src_05` and overwrote the numbered files, including the
frame these layers were cut from; it was recovered from git history and given a
name no numbered batch will claim.

**The bands are cut above the source's own wires.** `duststorm.jpg` has two
long horizontal wires at about 0.66 of frame height and a diagonal fan from a
pole at the right edge. The first crop started at 0.66 and took the lower edge
of both, so the bands carried photographed wire that broke at every tile
boundary — which read as the drawn wires being cut, when they never were. The
crops now start at 0.715 and stop at 0.76 of the width, above the horizontals
and left of the fan.

**Wires are drawn, not photographed.** They were a band cut from the same frame,
but the wires run diagonally across it, so every tile boundary chopped them
mid-span and the repeat read as broken cable — no seam blend fixes a wire that
enters one edge at a different height and angle than it leaves the other. A wire
at this scale is a two-pixel dark line, so the photograph contributed no texture
worth keeping, while a catenary computed between known poles is continuous
forever, tiles by construction, and costs no download. See
`lib/game/power_line.dart`.

**The palms are crowns, and that is deliberate.** Every palm in `art/source` has
its lower trunk crossing something as dark as itself — a balcony awning, a tarp,
a water tower, a row of houses — and dark-on-dark cannot be separated by a
brightness cut, nor by any rectangular crop, since the occluders overlap the
crowns in both axes.

The fix was not a better matte but a better place to stand it: `PalmRow` renders
*behind* the mid treeline band, with each crown's feathered lower edge sunk
inside it. Only the part that cut cleanly is ever on screen, and a palm showing
just its head above the trees is what a village skyline actually looks like. The
crown itself comes from `src_04.jpg` as a flat dark silhouette, so it carries no
light of its own to clash with the dust-storm bands.

`src_13` (the sunset) is a beautiful photograph and a poor layer source: its
subjects are discrete objects rather than continuous bands, and its sky is a
strong vertical gradient. Its real value was the measured sky palette.

**The balcony railing in `src_12` does not tile.** The ironwork itself cuts out
well once the frame is levelled, but it was shot from above and along its
length, so the top rail slopes and the bars crowd together toward the far end.
Rotation levels the tilt and cannot touch the perspective, so the two ends meet
at different heights and spacings and the repeat shows a step no seam blend
hides. A face-on, level frame of the same railing would tile cleanly.

### What one more photo session would unblock

Both open items are the same shot discipline, and neither is a tooling problem:

1. **A palm standing clear against sky** — nothing dark touching its crown.
2. **A face-on foreground** — a railing, a parapet or a laundry line, camera
   level and square to it rather than looking along it.

Shoot both in the same dusty or golden light as `src_01`, since sharing one
light is most of what makes the current bands sit together.

Not yet verified anywhere: **Android, iOS and macOS**. Those need the M1 with
Xcode and the Android SDK — the CI container has neither. FPS numbers in the
debug HUD from a headless software renderer are meaningless; measure on real
hardware.
