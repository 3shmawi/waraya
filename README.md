# waraya · ورايا

An atmospheric side-scroller set in contemporary working-class Cairo, built with
Flutter + Flame. One codebase, shipped to mobile, desktop and web.

Phase 1 is **environment and art foundation only** — no gameplay. The research
and week-by-week plan it follows is in [`docs/phase-1-research.md`](docs/phase-1-research.md).

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
    placeholder_skyline.dart     stand-in depth band      → Friday 2
    placeholder_ground.dart      stand-in surface         → Friday 2
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

## Verified so far

- Flutter 3.47.3 / Dart 3.13.3, flame 1.38.2 — matches the plan's minimums.
- `flutter analyze` clean, 14 tests passing.
- Web release build renders and responds to keyboard input at both 1600×900 and
  844×390, with no console errors.
- Linux desktop release binary builds and bundles.

Not yet verified anywhere: **Android, iOS and macOS**. Those need the M1 with
Xcode and the Android SDK — the CI container has neither. FPS numbers in the
debug HUD from a headless software renderer are meaningless; measure on real
hardware.
