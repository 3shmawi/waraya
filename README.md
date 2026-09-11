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

## Status — Friday 1 of 5: setup + skeleton ✅

A camera-following walker moves through a layered sunset scene, driven by a
platform-agnostic input layer. Everything visual right now is a **placeholder**
for the photographed silhouette layers that land on Friday 2.

| Friday | Scope | State |
| --- | --- | --- |
| 1 | Project, Flame, skeleton on all targets | done |
| 2 | Parallax background from real photographs | next |
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
    placeholder_village.dart     stand-in village bands   → Friday 2
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

## Verified so far

- Flutter 3.47.3 / Dart 3.13.3, flame 1.38.2 — matches the plan's minimums.
- `flutter analyze` clean, 14 tests passing.
- Web release build renders and responds to keyboard input at both 1600×900 and
  844×390, with no console errors.
- Linux desktop release binary builds and bundles.
- `tools/silhouette.py` on a synthetic backlit frame: seamless under repeat,
  thin wires preserved, `--alpha-gamma` solidifies mid-tones, and `--flatten`
  fixes a dark zenith at the documented cost above. **Not yet run on a real
  photograph** — no source photos are in the repo yet.

Not yet verified anywhere: **Android, iOS and macOS**. Those need the M1 with
Xcode and the Android SDK — the CI container has neither. FPS numbers in the
debug HUD from a headless software renderer are meaningless; measure on real
hardware.
