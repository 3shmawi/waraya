#!/usr/bin/env python3
"""Turn a backlit photograph into a tileable silhouette layer for Flame.

The pipeline the Phase 1 plan calls for: photograph a real place against a
bright sky, cut the dark subject out as a flat silhouette, and hand the result
to a ParallaxComponent.

Two things this does that a threshold in an image editor does not:

* Soft, luminance-based matting. A hard threshold eats thin structures --
  wires, palm fronds, antennas, laundry lines -- which are exactly the shapes
  that make an Egyptian skyline read as Egyptian. The alpha ramp keeps them.
* Seamless horizontal tiling. Flame's ParallaxLayer defaults to
  ImageRepeat.repeatX, so a layer is repeated forever rather than stretched.
  The seam is cross-faded so the repeat is invisible, which means one ordinary
  phone photo is enough -- no panorama needed.

Usage:
    python3 tools/silhouette.py photo.jpg -o assets/images/layer_far.png \
        --height 720 --crop 0.35,0.75 --tile --verify

Run with --help for every option.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# Rec. 709 luma weights: matches how the eye reads brightness, so the matte
# follows what actually looks dark rather than what is numerically dark.
_LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def luminance(rgb: np.ndarray) -> np.ndarray:
    """Perceptual brightness of an RGB float array in 0..1."""
    return rgb @ _LUMA


def otsu_threshold(values: np.ndarray, bins: int = 256) -> float:
    """Pick the split between dark subject and bright sky automatically.

    Otsu's method: the threshold that minimises variance within each of the two
    groups. A backlit photo is close to bimodal -- dark ground, bright sky --
    which is the case Otsu handles well, so this is usually within a nudge of
    what you would dial in by hand.
    """
    hist, edges = np.histogram(values, bins=bins, range=(0.0, 1.0))
    hist = hist.astype(np.float64)
    total = hist.sum()
    if total == 0:
        return 0.5

    centres = (edges[:-1] + edges[1:]) / 2
    weight_bg = np.cumsum(hist)
    weight_fg = total - weight_bg
    # Guard the ends, where one group is empty and the variance is undefined.
    valid = (weight_bg > 0) & (weight_fg > 0)
    if not valid.any():
        return 0.5

    sum_all = np.cumsum(hist * centres)
    mean_bg = np.divide(sum_all, weight_bg, out=np.zeros_like(sum_all), where=weight_bg > 0)
    mean_fg = np.divide(
        sum_all[-1] - sum_all, weight_fg, out=np.zeros_like(sum_all), where=weight_fg > 0
    )
    between = weight_bg * weight_fg * (mean_bg - mean_fg) ** 2
    between[~valid] = -1.0
    return float(centres[int(np.argmax(between))])


def flatten(lum: np.ndarray, radius_fraction: float) -> np.ndarray:
    """Divide out the sky's large-scale gradient so one threshold fits the frame.

    A sunset sky is dark at the zenith and bright at the horizon, so a single
    brightness cut classifies the top of the sky as subject. Dividing by a
    heavily blurred copy of the image keeps only local contrast: the dark
    objects stay dark relative to whatever sky is directly around them, and
    the gradient stops mattering.
    """
    from PIL import ImageFilter

    radius = max(1.0, lum.shape[0] * radius_fraction)
    blurred = np.asarray(
        Image.fromarray((np.clip(lum, 0, 1) * 255).astype(np.uint8))
        .filter(ImageFilter.GaussianBlur(radius)),
        dtype=np.float32,
    ) / 255.0
    ratio = lum / np.maximum(blurred, 1e-3)
    # Re-centre on 0.5 so the usual threshold range still means something.
    return np.clip(ratio * 0.5, 0.0, 1.0)


def matte(lum: np.ndarray, threshold: float, softness: float, invert: bool) -> np.ndarray:
    """Alpha in 0..1: opaque where the subject is, transparent for sky.

    `softness` is the half-width of the ramp around `threshold`. Zero gives a
    hard cut; 0.05-0.10 keeps wires and fronds as partial coverage instead of
    dropping them.
    """
    if softness <= 0:
        alpha = (lum <= threshold).astype(np.float32)
    else:
        alpha = (threshold + softness - lum) / (2.0 * softness)
        alpha = np.clip(alpha, 0.0, 1.0).astype(np.float32)
    if invert:
        alpha = 1.0 - alpha
    return alpha


def apply_alpha_gamma(alpha: np.ndarray, gamma: float) -> np.ndarray:
    """Push partial coverage toward solid (gamma < 1) or toward thin (> 1).

    Mid-tone objects -- a grey water tank, a concrete parapet -- land near the
    threshold and come out half transparent. A gamma below 1 solidifies them
    without losing the wires that the soft ramp exists to keep.
    """
    if gamma == 1.0:
        return alpha
    return np.clip(alpha, 0.0, 1.0) ** gamma


def parse_crop(spec: str) -> tuple[float, float]:
    try:
        top, bottom = (float(part) for part in spec.split(","))
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "--crop wants two fractions, e.g. 0.3,0.8 (top,bottom)"
        ) from exc
    if not 0.0 <= top < bottom <= 1.0:
        raise argparse.ArgumentTypeError("--crop needs 0 <= top < bottom <= 1")
    return top, bottom


def parse_haze(spec: str) -> tuple[tuple[int, int, int], float]:
    """Parse `RRGGBB:amount` for aerial perspective."""
    colour, _, amount = spec.partition(":")
    if not amount:
        raise argparse.ArgumentTypeError("--haze wants COLOUR:AMOUNT, e.g. e8b274:0.5")
    try:
        strength = float(amount)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"--haze amount is not a number: {amount}") from exc
    if not 0.0 <= strength <= 1.0:
        raise argparse.ArgumentTypeError("--haze amount must be between 0 and 1")
    return parse_color(colour), strength


def parse_color(spec: str) -> tuple[int, int, int]:
    text = spec.lstrip("#")
    if len(text) != 6:
        raise argparse.ArgumentTypeError("--color wants six hex digits, e.g. 1a1320")
    try:
        return tuple(int(text[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"--color is not hex: {spec}") from exc


def make_tileable(rgba: np.ndarray, blend_fraction: float) -> np.ndarray:
    """Cross-fade the right edge onto the left so repeatX shows no seam.

    The tail `blend` columns are faded over the head and then dropped, so the
    last column of the result continues naturally into the first.
    """
    height, width = rgba.shape[:2]
    blend = int(round(width * blend_fraction))
    blend = max(1, min(blend, width // 3))

    head = rgba[:, :blend].astype(np.float32)
    tail = rgba[:, width - blend :].astype(np.float32)

    # Ramp 0 -> 1 across the blend: the head dominates at the far end.
    ramp = np.linspace(0.0, 1.0, blend, dtype=np.float32)[None, :, None]
    merged = tail * (1.0 - ramp) + head * ramp

    out = rgba[:, : width - blend].astype(np.float32).copy()
    out[:, :blend] = merged
    return np.clip(out, 0, 255).astype(np.uint8)


def next_pot(value: int) -> int:
    pot = 1
    while pot < value:
        pot *= 2
    return pot


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Photo -> tileable silhouette PNG for a Flame parallax layer.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("input", type=Path, help="source photograph")
    parser.add_argument("-o", "--output", type=Path, help="output PNG (default: <input>_silhouette.png)")
    parser.add_argument(
        "--threshold",
        default="auto",
        help="brightness split in 0..1, or 'auto' for Otsu",
    )
    parser.add_argument(
        "--softness",
        type=float,
        default=0.07,
        help="half-width of the alpha ramp; raise it to keep wires and fronds",
    )
    parser.add_argument(
        "--color", type=parse_color, default="1a1320", help="silhouette fill, six hex digits"
    )
    parser.add_argument(
        "--keep-texture",
        action="store_true",
        help="keep the photo's own (darkened) colour instead of a flat fill",
    )
    parser.add_argument(
        "--texture-gain",
        type=float,
        default=0.35,
        help="how much original colour survives with --keep-texture",
    )
    parser.add_argument(
        "--alpha-gamma",
        type=float,
        default=1.0,
        help="below 1 solidifies mid-tone objects, above 1 thins the matte",
    )
    parser.add_argument(
        "--flatten",
        type=float,
        default=0.0,
        help="divide out the sky gradient before thresholding; try 0.15 on a "
        "sunset sky whose zenith is darker than the buildings (0 disables)",
    )
    parser.add_argument(
        "--haze",
        type=parse_haze,
        help="aerial perspective as COLOUR:AMOUNT, e.g. e8b274:0.55 -- mixes the "
        "layer toward the sky colour so distance reads as lost contrast. Use a "
        "larger amount the further back the layer sits.",
    )
    parser.add_argument("--invert", action="store_true", help="keep the bright side instead")
    parser.add_argument(
        "--crop",
        type=parse_crop,
        help="vertical slice to keep as fractions, e.g. 0.35,0.8",
    )
    parser.add_argument(
        "--height", type=int, default=720, help="output height in pixels (0 keeps the source)"
    )
    parser.add_argument("--tile", action="store_true", help="make the layer seamless under repeatX")
    parser.add_argument("--tile-blend", type=float, default=0.12, help="seam width as a fraction")
    parser.add_argument(
        "--pot", action="store_true", help="pad width up to a power of two (atlas friendly)"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="also write a 2x-tiled strip so the seam can be eyeballed",
    )
    parser.add_argument("--webp", action="store_true", help="also write a lossless WebP")
    args = parser.parse_args(argv)

    if not args.input.exists():
        print(f"no such file: {args.input}", file=sys.stderr)
        return 1

    image = Image.open(args.input).convert("RGB")
    rgb = np.asarray(image, dtype=np.float32) / 255.0

    if args.crop:
        top, bottom = args.crop
        height = rgb.shape[0]
        rgb = rgb[int(height * top) : int(height * bottom)]
        if rgb.size == 0:
            print("--crop removed every row", file=sys.stderr)
            return 1

    lum = luminance(rgb)
    if args.flatten > 0:
        lum = flatten(lum, args.flatten)
    threshold = (
        otsu_threshold(lum) if args.threshold == "auto" else float(args.threshold)
    )
    alpha = matte(lum, threshold, args.softness, args.invert)
    alpha = apply_alpha_gamma(alpha, args.alpha_gamma)

    if args.keep_texture:
        base = np.asarray(args.color, dtype=np.float32) / 255.0
        fill = base * (1.0 - args.texture_gain) + rgb * args.texture_gain
    else:
        fill = np.broadcast_to(
            np.asarray(args.color, dtype=np.float32) / 255.0, rgb.shape
        )

    if args.haze:
        haze_rgb, strength = args.haze
        target = np.asarray(haze_rgb, dtype=np.float32) / 255.0
        fill = fill * (1.0 - strength) + target * strength

    rgba = np.dstack([fill, alpha])
    rgba = (np.clip(rgba, 0.0, 1.0) * 255.0).round().astype(np.uint8)

    if args.tile:
        rgba = make_tileable(rgba, args.tile_blend)

    out_image = Image.fromarray(rgba, mode="RGBA")

    if args.height:
        scale = args.height / out_image.height
        out_image = out_image.resize(
            (max(1, round(out_image.width * scale)), args.height), Image.LANCZOS
        )

    if args.pot:
        target = next_pot(out_image.width)
        if target != out_image.width:
            padded = Image.new("RGBA", (target, out_image.height), (0, 0, 0, 0))
            padded.paste(out_image, (0, 0))
            out_image = padded

    output = args.output or args.input.with_name(f"{args.input.stem}_silhouette.png")
    output.parent.mkdir(parents=True, exist_ok=True)
    out_image.save(output, optimize=True)

    coverage = float(np.asarray(out_image)[..., 3].mean()) / 255.0
    print(f"{output}  {out_image.width}x{out_image.height}  {output.stat().st_size / 1024:.0f} KB")
    print(f"  threshold {threshold:.3f}{' (auto)' if args.threshold == 'auto' else ''}"
          f"   coverage {coverage * 100:.1f}%")
    if coverage < 0.02:
        print("  ! almost nothing was kept -- try --invert or a higher --threshold")
    elif coverage > 0.9:
        print("  ! almost everything was kept -- try a lower --threshold")

    if args.webp:
        webp = output.with_suffix(".webp")
        out_image.save(webp, lossless=True, method=6)
        print(f"  {webp.name}  {webp.stat().st_size / 1024:.0f} KB")

    if args.verify:
        strip = Image.new("RGBA", (out_image.width * 2, out_image.height), (0, 0, 0, 0))
        strip.paste(out_image, (0, 0))
        strip.paste(out_image, (out_image.width, 0))
        # Flatten onto a sky-ish colour so the seam is visible at a glance.
        backdrop = Image.new("RGB", strip.size, (232, 178, 116))
        backdrop.paste(strip, (0, 0), strip)
        check = output.with_name(f"{output.stem}_tilecheck.png")
        backdrop.save(check)
        print(f"  {check.name}  seam sits at x={out_image.width}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
