#!/usr/bin/env python3
"""The launch video, from the game's own footage — docs/marketing/launch-video.md.

    # 1. footage: the real game, at a phone's own screen size, 30 fps
    for n in 1 2 8 9 15; do
      WARAYA_CLIP_DEVICE=844x390@2 WARAYA_CLIP_EVERY=2 WARAYA_CLIP=$n \\
        WARAYA_CLIP_OUT=$WORK/frames flutter test tool/clips.dart
    done
    # ...and each folder of frames to $WORK/clips/phone-<name>.mp4 (30 fps)

    # 2. the video
    python3 tool/promo/build.py $WORK          # needs ffmpeg, node, playwright

Writes docs/media/promo/waraya-<layout>.mp4 for each layout: `story` (9:16,
TikTok, Reels, Shorts, Stories) and `feed` (4:5, the Facebook and Instagram
feed). Every word is drawn by tool/promo/cards.html; the gameplay is never
re-timed, only cut — what plays is the recorded solutions the tests play.
"""

import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
FPS = 30

LAYOUTS = {
    # A phone on its side, as wide as the frame — the game is landscape and
    # a narrower phone is a smaller game. Words in the sky above it, more
    # under the ground below, all of it above the strip the apps cover with
    # their own buttons and caption (roughly the bottom fifth).
    'story': {
        'W': 1080, 'H': 1920,
        'screen': {'x': 20, 'y': 640, 'w': 1040, 'h': 481},
        'bezel': 20, 'horizon': 1144,
        'topBand': [190, 610], 'bottomBand': [1160, 1540],
        'type': {'big': 100, 'mid': 62, 'small': 48, 'mark': 300, 'title': 150},
        'endHead': 230, 'endHorizon': 1050, 'endGap': 70,
    },
    'feed': {
        'W': 1080, 'H': 1350,
        'screen': {'x': 20, 'y': 418, 'w': 1040, 'h': 481},
        'bezel': 20, 'horizon': 922,
        'topBand': [20, 398], 'bottomBand': [932, 1330],
        'type': {'big': 86, 'mid': 52, 'small': 38, 'mark': 210, 'title': 116},
        'endHead': 50, 'endHorizon': 690, 'endGap': 34,
    },
}

BRAND = {'bottom_small': 'ورايا · لعبة ألغاز مصرية'}

# The cut. Each segment is footage (a clip and where in it), or a frame of
# it held still, or the end card — with the words over it, in seconds from
# the segment's start.
SEGMENTS = [
    # The hook: a door opens by itself in front of you.
    {'clip': 'phone-01-the-plate', 'from': 3.4, 'dur': 1.6, 'cards': [
        (0, 1.6, {'top_big': 'الباب ده فتح لوحده؟'}),
    ]},
    # The turn: who opened it.
    {'clip': 'phone-01-the-plate', 'hold': 5.0, 'dur': 2.4, 'cards': [
        (0, 2.4, {'top_big': 'لأ… ده <span class="chip">انت</span>',
                  'top_small': 'من ٢٫٥ ثانية بالظبط',
                  'ring': {'x': 591, 'y': 308, 'r': 44}}),
        (0.5, 2.4, {'bottom_big': 'الفاتح اللي على الزرار ده ماضيك'}),
    ]},
    # How: the whole level, from the start.
    {'clip': 'phone-01-the-plate', 'from': 0.6, 'dur': 6.8, 'cards': [
        (0, 3.0, {'top_big': '١. اقف على الزرار'}),
        (3.0, 4.4, {'top_big': '٢. وامشي', 'top_small': 'من غير ما تستنى'}),
        (4.4, 6.8, {'top_big': '٣. ماضيك يدوس مكانك', 'top_small': 'والباب يفتحلك'}),
        (0, 6.8, BRAND),
    ]},
    # The second rule.
    {'clip': 'phone-02-the-step', 'from': 5.6, 'dur': 4.0, 'cards': [
        (0, 1.7, {'top_big': 'وماضيك مش خيال', 'top_small': 'ده جسم حقيقي'}),
        (1.7, 4.0, {'top_big': 'تطلع فوقه', 'top_small': 'بس لو كنت وطيت'}),
        (0, 4.0, BRAND),
    ]},
    # How far it goes.
    {'clip': 'phone-09-two-of-you', 'from': 0.0, 'dur': 0.0, 'cards': []},
    {'clip': 'phone-08-in-the-light', 'from': 0.0, 'dur': 0.0, 'cards': []},
    # Everywhere.
    {'clip': 'phone-15-all-of-it', 'from': 0.0, 'dur': 0.0, 'cards': []},
    {'end': True, 'dur': 3.6, 'cards': []},
]

END = {
    'tag': 'لعبة مصرية · مجانية · من غير إعلانات',
    'cta': 'نزّلها دلوقتي',
    'also': 'وعلى الكمبيوتر و itch.io',
}


def run(cmd):
    subprocess.run(cmd, check=True)


def build(work, name, layout):
    out_dir = os.path.join(work, 'promo-' + name)
    shutil.rmtree(out_dir, ignore_errors=True)
    os.makedirs(out_dir)

    # Every still layer this layout needs, drawn in one browser session.
    layers = [
        {'name': 'base', 'spec': {'kind': 'base', 'layout': layout}},
        {'name': 'chrome', 'spec': {'kind': 'chrome', 'layout': layout}},
        {'name': 'end', 'spec': {'kind': 'end', 'layout': layout, 'card': END}},
    ]
    for i, seg in enumerate(SEGMENTS):
        for j, (_, _, card) in enumerate(seg['cards']):
            layers.append({'name': f'cap-{i}-{j}',
                           'spec': {'kind': 'caption', 'layout': layout, 'card': card}})
    listing = os.path.join(out_dir, 'layers.json')
    with open(listing, 'w') as f:
        json.dump(layers, f, ensure_ascii=False)
    run(['node', os.path.join(HERE, 'render.js'), listing, out_dir])

    s = layout['screen']
    parts = []
    for i, seg in enumerate(SEGMENTS):
        dur = seg['dur']
        part = os.path.join(out_dir, f'part-{i:02d}.mp4')
        inputs, filters = [], []
        if seg.get('end'):
            inputs += ['-loop', '1', '-t', str(dur), '-i', os.path.join(out_dir, 'end.png')]
            last = '[0:v]'
            filters.append(f'{last}fade=t=in:st=0:d=0.35,format=yuv420p[v]')
        else:
            clip = os.path.join(work, 'clips', seg['clip'] + '.mp4')
            inputs += ['-loop', '1', '-t', str(dur), '-i', os.path.join(out_dir, 'base.png')]
            if 'hold' in seg:
                still = os.path.join(out_dir, f'hold-{i}.png')
                run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', str(seg['hold']), '-i', clip,
                     '-frames:v', '1', still])
                inputs += ['-loop', '1', '-t', str(dur), '-i', still]
            else:
                inputs += ['-ss', str(seg['from']), '-t', str(dur), '-i', clip]
            inputs += ['-loop', '1', '-t', str(dur), '-i', os.path.join(out_dir, 'chrome.png')]
            filters.append(f"[1:v]fps={FPS},scale={s['w']}:{s['h']}:flags=lanczos,setsar=1[g]")
            filters.append(f"[0:v][g]overlay={s['x']}:{s['y']}:shortest=1[a]")
            filters.append('[a][2:v]overlay=0:0[b0]')
            last = '[b0]'
            for j, (start, end, _) in enumerate(seg['cards']):
                k = 3 + j
                inputs += ['-loop', '1', '-t', str(dur), '-i', os.path.join(out_dir, f'cap-{i}-{j}.png')]
                fade_out = max(start, end - 0.15)
                filters.append(
                    f'[{k}:v]format=rgba,fade=t=in:st={start}:d=0.18:alpha=1,'
                    f'fade=t=out:st={fade_out}:d=0.15:alpha=1[c{j}]')
                nxt = f'[b{j + 1}]'
                filters.append(f"{last}[c{j}]overlay=0:0:enable='between(t,{start},{end})'{nxt}")
                last = nxt
            filters.append(f'{last}format=yuv420p[v]')
        run(['ffmpeg', '-y', '-loglevel', 'error', *inputs,
             '-filter_complex', ';'.join(filters), '-map', '[v]',
             '-r', str(FPS), '-t', str(dur),
             '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', part])
        parts.append(part)

    concat = os.path.join(out_dir, 'parts.txt')
    with open(concat, 'w') as f:
        f.writelines(f"file '{p}'\n" for p in parts)
    final_dir = os.path.join(REPO, 'docs', 'media', 'promo')
    os.makedirs(final_dir, exist_ok=True)
    final = os.path.join(final_dir, f'waraya-{name}.mp4')
    # A silent track: some apps treat a video with no audio as broken, and
    # every one of them lets the poster add a sound over it.
    run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', concat,
         '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
         '-map', '0:v', '-map', '1:a', '-shortest',
         '-c:v', 'libx264', '-preset', 'slow', '-crf', '19', '-pix_fmt', 'yuv420p',
         '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', final])
    print('wrote', final)


if __name__ == '__main__':
    work = sys.argv[1]
    only = sys.argv[2:] or list(LAYOUTS)
    for name in only:
        build(work, name, LAYOUTS[name])
