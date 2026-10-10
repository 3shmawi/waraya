#!/usr/bin/env python3
"""A voice over the launch video — docs/marketing/launch-video.md.

    pip install edge-tts
    python3 tool/promo/voice.py WORK [VOICE]      # VOICE: ar-EG-ShakirNeural (default)
                                                  #        or ar-EG-SalmaNeural

Says each line in its scene of tool/promo/film.js, in an Egyptian voice
(Microsoft's, through edge-tts — needs speech.platform.bing.com reachable).
A line that runs longer than its scene is said faster until it fits, rather
than spilling into the next one. Writes docs/media/promo/waraya-<layout>-voice.mp4
next to each silent video, which stays: a poster who wants a trending sound
instead of a voice still has it.
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROMO = os.path.join(os.path.dirname(os.path.dirname(HERE)), 'docs', 'media', 'promo')

# (starts at, has until, what is said). Times are film.js's SCENES.
LINES = [
    (0.15, 1.85, 'الباب ده فتح لوحده؟'),
    (2.0, 5.3, 'لأ… ده انت، من تانيتين ونص.'),       # into the rewind, which says nothing
    (5.6, 12.3, 'في ورايا، ظلك بيعيد حركاتك بعد شوية. اقف على الزرار، وامشي… وماضيك هو اللي يفتحلك.'),
    (12.4, 16.5, 'وماضيك مش خيال: وطّي، واطلع فوقه.'),
    (16.6, 21.3, 'ظلّين، ونور بيمسح ماضيك، وستاشر مرحلة كل واحدة أصعب.'),
    (21.35, 24.35, 'موبايل، كمبيوتر، أو من المتصفح.'),
    (24.3, 30.45, 'ورايا: لعبة مصرية، مجانية، ومن غير إعلانات. صوّر الكود ونزّلها.'),
]

# Faster than this and the voice stops sounding like somebody talking.
MAX_RATE = 30

# The voice leaves ~0.65 s of silence at each end and ~0.7 s at every full
# stop: trim the ends, and cut any pause inside down to a breath.
TIGHTEN = ('silenceremove=start_periods=1:start_threshold=-45dB,'
           'silenceremove=stop_periods=-1:stop_duration=0.3:stop_threshold=-45dB:stop_silence=0.22,'
           'areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse')


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                          '-of', 'csv=p=0', path], check=True, capture_output=True, text=True)
    return float(out.stdout)


def say(text, voice, rate, path):
    cmd = ['edge-tts', '--voice', voice, '--rate', f'{rate:+d}%', '--text', text, '--write-media', path]
    proxy = os.environ.get('HTTPS_PROXY') or os.environ.get('https_proxy')
    if proxy:
        cmd += ['--proxy', proxy]
    subprocess.run(cmd, check=True, capture_output=True)


def main():
    work = sys.argv[1]
    voice = sys.argv[2] if len(sys.argv) > 2 else 'ar-EG-ShakirNeural'
    out = os.path.join(work, 'voice')
    os.makedirs(out, exist_ok=True)

    clips = []
    for i, (at, until, text) in enumerate(LINES):
        raw, path = os.path.join(out, f'{i}.mp3'), os.path.join(out, f'{i}.wav')
        rate = 0
        while True:
            say(text, voice, rate, raw)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', raw, '-af', TIGHTEN, path], check=True)
            if duration(path) <= until - at or rate >= MAX_RATE:
                break
            rate += 6
        if duration(path) > until - at:
            print(f'  ! runs {duration(path) - (until - at):.2f}s past its scene: shorten the line')
        clips.append((at, path))
        print(f'{at:5.2f}s  {duration(path):.2f}s / {until - at:.2f}s  rate {rate:+d}%  {text}')

    inputs, filters = [], []
    for i, (at, path) in enumerate(clips):
        inputs += ['-i', path]
        ms = int(at * 1000)
        filters.append(f'[{i + 1}:a]adelay={ms}|{ms},aresample=44100[a{i}]')
    mix = ''.join(f'[a{i}]' for i in range(len(clips)))
    filters.append(f'{mix}amix=inputs={len(clips)}:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=11[voice]')

    for name in ('story', 'feed'):
        video = os.path.join(PROMO, f'waraya-{name}.mp4')
        final = os.path.join(PROMO, f'waraya-{name}-voice.mp4')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', video, *inputs,
                        '-filter_complex', ';'.join(filters),
                        '-map', '0:v', '-map', '[voice]', '-c:v', 'copy',
                        '-c:a', 'aac', '-b:a', '128k', '-ar', '44100', '-ac', '2',
                        '-t', str(duration(video)), '-movflags', '+faststart', final], check=True)
        print('wrote', final)
    with open(os.path.join(out, 'voice.json'), 'w') as f:
        json.dump({'voice': voice}, f)


if __name__ == '__main__':
    main()
