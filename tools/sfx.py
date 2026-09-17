#!/usr/bin/env python3
"""Synthesise the game's sound effects from scratch, with no samples.

There is no audio artist on this project and no sample library in the repo, so
the sounds are generated the same way the silhouettes are: by a script that
lives next to the assets it produces, so any of them can be regenerated or
retuned instead of being a mystery binary.

The palette matches the art direction -- dry, muted, low-fi. Nothing here is a
musical note; every sound is noise or a low sweep shaped by an envelope, which
is what footsteps, thumps and latches actually are.

Stdlib only: `wave` writes the files and `math`/`random` make the samples.
Deliberately no numpy, so this runs on a bare Python.

Usage:
    python3 tools/sfx.py                 # write every sound to assets/audio/
    python3 tools/sfx.py --verify        # ...and print what came out
    python3 tools/sfx.py -o /tmp/sounds  # somewhere else
"""

from __future__ import annotations

import argparse
import cmath
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100

Samples = list[float]


# --------------------------------------------------------------------------
# building blocks
# --------------------------------------------------------------------------


def silence(seconds: float) -> Samples:
    return [0.0] * int(RATE * seconds)


def noise(seconds: float, rng: random.Random) -> Samples:
    """White noise in -1..1."""
    return [rng.uniform(-1.0, 1.0) for _ in range(int(RATE * seconds))]


def sweep(seconds: float, start_hz: float, end_hz: float, curve: float = 1.0) -> Samples:
    """A sine whose frequency glides from start to end.

    `curve` above 1 makes the glide happen late, below 1 early. Phase is
    integrated rather than recomputed per sample, or the waveform clicks every
    time the frequency changes.
    """
    count = int(RATE * seconds)
    out: Samples = []
    phase = 0.0
    for i in range(count):
        t = (i / count) ** curve if count else 0.0
        hz = start_hz + (end_hz - start_hz) * t
        phase += 2 * math.pi * hz / RATE
        out.append(math.sin(phase))
    return out


def lowpass(samples: Samples, cutoff_hz: float) -> Samples:
    """One-pole lowpass. Crude, and exactly right for taking the fizz off
    noise so it reads as a thud rather than as static."""
    if not samples:
        return samples
    dt = 1 / RATE
    rc = 1 / (2 * math.pi * cutoff_hz)
    alpha = dt / (rc + dt)
    out: Samples = []
    value = 0.0
    for sample in samples:
        value += alpha * (sample - value)
        out.append(value)
    return out


def highpass(samples: Samples, cutoff_hz: float) -> Samples:
    """One-pole highpass, for keeping a click from booming."""
    if not samples:
        return samples
    dt = 1 / RATE
    rc = 1 / (2 * math.pi * cutoff_hz)
    alpha = rc / (rc + dt)
    out: Samples = []
    previous_in = samples[0]
    value = 0.0
    for sample in samples:
        value = alpha * (value + sample - previous_in)
        previous_in = sample
        out.append(value)
    return out


def envelope(samples: Samples, attack: float, decay: float, curve: float = 2.5) -> Samples:
    """Fade in over `attack` seconds, then fall away over `decay`.

    The attack is never zero: a waveform that starts at full amplitude begins
    with a step, and a step is a click you did not ask for.
    """
    count = len(samples)
    attack_n = max(1, int(RATE * attack))
    out: Samples = []
    for i, sample in enumerate(samples):
        if i < attack_n:
            gain = i / attack_n
        else:
            t = (i - attack_n) / max(1, int(RATE * decay))
            gain = max(0.0, 1.0 - t) ** curve
        out.append(sample * gain)
    return out


def mix(*layers: Samples) -> Samples:
    length = max((len(layer) for layer in layers), default=0)
    out = [0.0] * length
    for layer in layers:
        for i, sample in enumerate(layer):
            out[i] += sample
    return out


def gain(samples: Samples, amount: float) -> Samples:
    return [sample * amount for sample in samples]


def normalise(samples: Samples, peak: float = 0.85) -> Samples:
    """Scale to a target peak, then soft-clip.

    Every sound is normalised to the same ceiling so the mix is balanced by
    the deliberate per-sound gains below, not by whichever synthesis happened
    to come out loudest.
    """
    highest = max((abs(sample) for sample in samples), default=0.0)
    if highest == 0:
        return samples
    scaled = [sample / highest * peak for sample in samples]
    return [math.tanh(sample * 1.2) / math.tanh(1.2) * peak for sample in scaled]


# --------------------------------------------------------------------------
# the sounds
# --------------------------------------------------------------------------


def step(seed: int) -> Samples:
    """A foot landing on grit. Short, dull, slightly different every time.

    Three variants exist because one footstep sample played four times a
    second is a woodpecker, and the ear catches the repetition long before it
    catches the sound.
    """
    rng = random.Random(seed)
    cutoff = rng.uniform(1100, 1900)
    scuff = envelope(lowpass(noise(0.09, rng), cutoff), 0.001, 0.075, curve=3.0)
    body = envelope(sweep(0.07, 150, 80), 0.001, 0.06, curve=2.0)
    return normalise(mix(scuff, gain(body, 0.5)), 0.7)


def jump() -> Samples:
    """Effort, not a cartoon boing: a short breathy rise with no pitch to it."""
    rng = random.Random(11)
    breath = envelope(highpass(noise(0.16, rng), 300), 0.004, 0.14, curve=2.0)
    lift = envelope(sweep(0.16, 190, 340, curve=0.6), 0.004, 0.15, curve=2.2)
    return normalise(mix(gain(breath, 0.6), gain(lift, 0.5)), 0.7)


def land() -> Samples:
    """Weight arriving. The low sweep is the body, the noise is the ground."""
    rng = random.Random(23)
    thump = envelope(sweep(0.26, 120, 48, curve=0.5), 0.002, 0.24, curve=2.2)
    impact = envelope(lowpass(noise(0.2, rng), 700), 0.001, 0.16, curve=3.0)
    return normalise(mix(thump, gain(impact, 0.55)), 0.9)


def plate() -> Samples:
    """A latch taking weight: one dry mechanical click."""
    rng = random.Random(31)
    click = envelope(highpass(noise(0.045, rng), 1400), 0.0005, 0.035, curve=4.0)
    body = envelope(sweep(0.05, 700, 420), 0.0005, 0.04, curve=3.0)
    return normalise(mix(click, gain(body, 0.35)), 0.6)


def door() -> Samples:
    """Something heavy sliding. Slow in, slow out, no tone to speak of."""
    rng = random.Random(43)
    grind = envelope(lowpass(noise(0.75, rng), 420), 0.09, 0.62, curve=1.4)
    rumble = envelope(sweep(0.75, 70, 55), 0.09, 0.62, curve=1.4)
    return normalise(mix(grind, gain(rumble, 0.7)), 0.75)


def reset() -> Samples:
    """The level being taken back.

    Downward, and further down than anything else in the set: every other sound
    is something happening *in* the world, and this one is the world being
    wound back. Short, because it fires the instant you die and a long sound
    would still be playing while you are moving again.
    """
    rng = random.Random(59)
    fall = envelope(sweep(0.36, 300, 70, curve=0.6), 0.004, 0.32, curve=2.0)
    air = envelope(lowpass(noise(0.3, rng), 900), 0.006, 0.26, curve=2.6)
    return normalise(mix(fall, gain(air, 0.4)), 0.8)


SOUNDS = {
    "step_1.wav": lambda: step(1),
    "step_2.wav": lambda: step(2),
    "step_3.wav": lambda: step(3),
    "jump.wav": jump,
    "land.wav": land,
    "plate.wav": plate,
    "door.wav": door,
    "reset.wav": reset,
}


# --------------------------------------------------------------------------
# output
# --------------------------------------------------------------------------


def write_wav(path: Path, samples: Samples) -> None:
    frames = b"".join(
        struct.pack("<h", max(-32768, min(32767, int(sample * 32767))))
        for sample in samples
    )
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)


def centroid_hz(samples: Samples) -> float:
    """Rough spectral centroid: where the sound sits, bright to dark.

    A single DFT over a decimated copy -- enough to tell a click from a thud,
    which is the only question --verify is asking.
    """
    step_size = 8
    window = samples[::step_size][:512]
    if not window:
        return 0.0
    rate = RATE / step_size
    size = len(window)
    weighted = 0.0
    total = 0.0
    for k in range(1, size // 2):
        acc = sum(
            sample * cmath.exp(-2j * math.pi * k * n / size)
            for n, sample in enumerate(window)
        )
        magnitude = abs(acc)
        weighted += magnitude * (k * rate / size)
        total += magnitude
    return weighted / total if total else 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-o", "--out", default="assets/audio", type=Path)
    parser.add_argument(
        "--verify",
        action="store_true",
        help="print duration, peak and brightness of each sound",
    )
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        samples = make()
        write_wav(args.out / name, samples)
        if args.verify:
            peak = max(abs(sample) for sample in samples)
            rms = math.sqrt(sum(s * s for s in samples) / len(samples))
            print(
                f"{name:12s} {len(samples) / RATE * 1000:6.0f}ms  "
                f"peak {peak:.2f}  rms {rms:.3f}  "
                f"centre {centroid_hz(samples):6.0f}Hz"
            )
        else:
            print(f"wrote {args.out / name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
