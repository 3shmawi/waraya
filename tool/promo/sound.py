"""The game's own sound under a clip: the steps, the plate, the dog's bark.

    python3 tool/promo/sound.py FRAMES_DIR OUT.wav [--from S] [--to S]

FRAMES_DIR is a clip's folder from tool/clips.dart, with the `sounds.json`
it writes: every sound the game asked for, when, and how loud. This lays the
same wav files the game plays (assets/audio/) down at those times — so the
footage sounds as the game does, without recording a screen. --from/--to
trim it the way the footage is trimmed. Standard library only.
"""
import argparse
import array
import json
import os
import wave

RATE = 44100
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    """A wav as mono floats at RATE (the game's files are written that way)."""
    with wave.open(path) as w:
        assert w.getsampwidth() == 2, path
        frames = w.readframes(w.getnframes())
        channels = w.getnchannels()
        rate = w.getframerate()
    data = array.array('h', frames)
    mono = [sum(data[i:i + channels]) / channels / 32768 for i in range(0, len(data), channels)]
    if rate != RATE:  # nearest sample: these are short effects
        mono = [mono[int(i * rate / RATE)] for i in range(int(len(mono) * RATE / rate))]
    return mono


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('frames')
    ap.add_argument('out')
    ap.add_argument('--from', dest='start', type=float, default=0)
    ap.add_argument('--to', dest='end', type=float, default=None)
    ap.add_argument('--fps', type=float, default=30)
    a = ap.parse_args()
    played = json.load(open(os.path.join(a.frames, 'sounds.json')))
    count = len([f for f in os.listdir(a.frames) if f.endswith('.png')])
    length = (a.end if a.end is not None else count / a.fps) - a.start
    mix = [0.0] * int(length * RATE)
    cache = {}
    for p in played:
        at = int((p['t'] - a.start) * RATE)
        if at >= len(mix):
            continue
        clip = cache.setdefault(p['file'], read(os.path.join(REPO, 'assets', 'audio', p['file'])))
        for i, v in enumerate(clip):
            j = at + i
            if 0 <= j < len(mix):
                mix[j] += v * p['volume']
            elif j >= len(mix):
                break
    peak = max(1.0, max((abs(v) for v in mix), default=0))
    out = array.array('h', (int(v / peak * 32000) for v in mix))
    with wave.open(a.out, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(out.tobytes())


main()
