# waraya · ورايا

An atmospheric side-scroller set in a contemporary Egyptian village, built with
Flutter + Flame. One codebase, shipped to mobile, desktop and web.

Phase 1 is **environment and art foundation only** — no gameplay. The research
and week-by-week plan it follows is in [`docs/phase-1-research.md`](docs/phase-1-research.md).

**Setting note.** The plan was researched for a Cairo rooftop. The setting moved
to a village once the available photographs turned out to be rural — palms,
casuarina windbreaks, irrigation canals, red brick with exposed rebar. Section 5
of the plan (visual and cultural references) was rewritten for that and is
flagged there as the least-verified part of the document. Whether the village
is Delta or Upper Egypt is still open, and the two look different.

## Status — Friday 1 done, Friday 2 under way

A camera-following walker moves through a layered dust-storm scene, driven by a
platform-agnostic input layer. Three of the bands are now cut from real
photographs in `art/source`; the ground is still a flat stand-in.

| Friday | Scope | State |
| --- | --- | --- |
| 1 | Project, Flame, skeleton on all targets | done |
| 2 | Parallax background from real photographs | three bands in, palms blocked |
| 3 | Character sprite + camera follow | |
| 4 | Atmosphere without shaders (particles, god rays, fog, vignette) | |
| 5 | Polish, web hardening, optional shaders | |

## Two decisions worth not re-litigating

**1. Fixed world height, elastic width.** The camera uses the default
`MaxViewport` and `onGameResize` sets the zoom so exactly
`WarayaConfig.worldHeight` (720) world units are visible vertically. A tall
phone sees a narrower horizontal slice, a wide desktop sees a wider one, and
nothing gets letterbox bars. **Art must therefore be authored wider than the
widest viewport** — the placeholder layers span 12000 units for this reason.

The camera tracks the walker horizontally only; its vertical position is pinned
so the horizon stays where the art was composed for it.

**2. All input arrives as `InputIntent`.** Nothing below `WarayaGame` asks what
platform it is on. `InputController` merges every `InputSource` once per frame,
before anything consumes it. Sources are all live simultaneously rather than
selected by platform, so a phone in a desktop browser still gets touch and a
tablet with a keyboard gets both. Adding a gamepad means adding one list entry.

- Keyboard: arrows / WASD to walk, space / up / W to jump.
- Touch: hold lower-left or lower-right to walk, touch the upper band to jump.

## Layout

```
lib/
  main.dart                      app entry
  game/
    config.dart                  world height, horizon, speeds
    waraya_game.dart             scene assembly, camera, input wiring
    sky_backdrop.dart            sunset gradient (camera backdrop)
    photo_band.dart              a photographed band, tiled and parallaxed
    ground.dart                  stand-in surface         → Friday 2
    probe_walker.dart            stand-in character       → Friday 3
  input/
    input.dart                   InputIntent + InputSource
    input_controller.dart        per-frame merge
    keyboard_input_source.dart
    touch_input_source.dart
  ui/
    debug_hud.dart               per-platform readout
```

Render order inside the camera is **backdrop → world → viewport**. The sky sits
in `camera.backdrop`; a sky in the viewport paints over the entire scene.

## Running

```bash
flutter pub get
flutter run -d macos        # or windows, linux
flutter run -d chrome
flutter run                 # attached phone
```

Checks:

```bash
flutter analyze
flutter test
```

### Web builds

```bash
flutter build web --release
```

Add `--no-web-resources-cdn` to bundle CanvasKit locally instead of pulling it
from `gstatic.com` — required behind a restrictive network, and worth measuring
either way since the plan treats web download size as the main risk. A `--wasm`
build (skwasm, ~1.1 MB versus CanvasKit's ~1.5 MB) passes the dry run and is
worth testing once real assets exist.

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

`src_01.jpg` — the dust storm — carried the scene. Its sky is flat and bright
and its trees are dark, which is the one case a brightness matte handles
cleanly, and all three bands come from it: a hazed far treeline, a
full-texture mid treeline, and the wires. Because they share one frame they
share one light, which is most of why the scene holds together.

**No palms yet, and not for want of trying.** Every palm in the fourteen source
frames is partly occluded by something as dark as it is — a balcony awning in
`src_12`, a tarp in `src_13`, a water tower beside the trunk. Dark-on-dark
cannot be separated by a brightness cut, and the occluders overlap the crowns
in both axes so no rectangular crop divides them either. Unblocking it takes
one of:

- one new frame of a single palm standing clear against sky, shot in the same
  light as the bands; or
- a hand mask in Photopea, roughly five minutes per palm.

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
