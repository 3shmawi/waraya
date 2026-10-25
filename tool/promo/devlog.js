// The devlog: short clips of a thing being built, out of the bench itself —
// grey boxes, the recorded solutions and wrong ideas — with a line on each
// (docs/media/devlog.md).
//
//   node tool/promo/devlog.js WORK [n ...]
//
// WORK/<day>/00-<level>/NNNNN.png are frames from tool/clips.dart
// (WARAYA_CLIP_LOOK=bench, WARAYA_CLIP_LEVEL, WARAYA_CLIP_IDEA, 30 fps; see
// the doc for each day's). The words are drawn by a browser, because a
// browser is what joins Arabic letters, onto a transparent sheet that ffmpeg
// lays over the footage. Writes docs/media/devlog/<slug>.mp4: 1080x1920, a
// silent track for the sound the app puts on.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

const REPO = path.resolve(__dirname, '..', '..');
const FPS = 30;

// `from`/`to` trim the footage, in seconds. `pair` is two renders at a
// phone's shape, the bench over the game.
const DAYS = [
  { n: 1, slug: 'dog-1-it-sees-you', dir: 'd1', from: 0, to: 8.5,
    line: 'زوّدت كلب للعبة', sub: 'وأول ما شافني… زي أي كلب في الشارع' },
  { n: 2, slug: 'dog-2-hide-up-there', dir: 'd2', from: 1, to: 15,
    line: 'طب أطلع فوق وأستخبى؟', sub: 'ماضيّا واقف… والكلب مبيجريش ورا حد واقف' },
  { n: 3, slug: 'dog-3-a-companion', dir: 'd3', from: 2.5, to: 18.7,
    line: 'بس الحمد لله معانا ونيس', sub: 'ظلنا: يتحرك فوق، والكلب يجري وراه' },
  { n: 4, slug: 'dog-4-a-lamp', dir: 'd4', from: 2.5, to: 16,
    line: 'زوّدت لمبة', sub: 'والكلب مبيشوفش ماضيك وهو في النور' },
  { n: 5, slug: 'dog-5-boxes-to-this', pair: ['d6a', 'd6b'], from: 3.5, to: 15,
    line: 'من مستطيلات…', sub: 'لده', labels: ['الورشة', 'اللعبة'] },
];

const frames = (work, dir) => {
  const d = path.join(work, dir);
  const sub = fs.readdirSync(d).find((f) => f.startsWith('00-'));
  return path.join(d, sub, '%05d.png');
};

const style = `
  @font-face { font-family: 'Cairo'; src: url('file://${REPO}/assets/fonts/Cairo-Regular.ttf'); }
  html, body { margin: 0; background: transparent; }
  body { width: 1080px; height: 1920px; position: relative; font-family: 'Cairo', sans-serif; direction: rtl; }
  .t { position: absolute; left: 60px; right: 60px; text-align: center; color: #FFE7B0;
       text-shadow: 0 4px 18px rgba(0,0,0,.85), 0 0 3px rgba(0,0,0,.9); line-height: 1.25; }
  .chip { position: absolute; top: 120px; left: 0; right: 0; text-align: center; }
  .chip span { background: #14100A; color: #FFE7B0; border-radius: 999px; padding: 10px 30px; font-size: 36px; }
  .label { position: absolute; left: 50%; transform: translateX(-50%); background: rgba(20,16,10,.8); color: #FFE7B0;
           border-radius: 14px; padding: 4px 18px; font-size: 34px; }`;

function sheet(day) {
  const ar = (n) => String(n).replace(/[0-9]/g, (d) => String.fromCharCode(0x0660 + +d));
  const chip = `<div class="chip"><span>بعمل لعبة · يوم ${ar(day.n)}</span></div>`;
  if (day.pair) {
    return `${chip}
      <div class="t" style="top:230px;font-size:84px">${day.line}</div>
      <div class="label" style="top:440px">${day.labels[0]}</div>
      <div class="label" style="top:1090px">${day.labels[1]}</div>
      <div class="t" style="top:1700px;font-size:84px">${day.sub}</div>`;
  }
  return `${chip}
    <div class="t" style="top:1290px;font-size:80px">${day.line}</div>
    <div class="t" style="top:1420px;font-size:46px;color:#E9D8BC">${day.sub}</div>`;
}

(async () => {
  const work = path.resolve(process.argv[2]);
  const only = process.argv.slice(3).map(Number);
  const out = path.join(REPO, 'docs', 'media', 'devlog');
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch({
    ...(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {}),
    args: ['--allow-file-access-from-files'],
  });
  const page = await browser.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  for (const day of DAYS) {
    if (only.length && !only.includes(day.n)) continue;
    await page.setContent(`<!doctype html><meta charset="utf-8"><style>${style}</style><body>${sheet(day)}</body>`);
    await page.evaluate(() => document.fonts.ready);
    const words = path.join(work, `words-${day.n}.png`);
    await page.screenshot({ path: words, omitBackground: true });
    const trim = ['-ss', String(day.from), '-t', String(day.to - day.from)];
    const audio = ['-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100'];
    const file = path.join(out, `${day.slug}.mp4`);
    const tail = ['-map', '[v]', '-map', `${day.pair ? 3 : 2}:a`, '-shortest',
      '-c:v', 'libx264', '-preset', 'slow', '-crf', '20', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', file];
    if (day.pair) {
      // The bench over the game, the same moment in both, on the dark.
      execFileSync('ffmpeg', ['-y', '-loglevel', 'error',
        '-framerate', String(FPS), ...trim, '-i', frames(work, day.pair[0]),
        '-framerate', String(FPS), ...trim, '-i', frames(work, day.pair[1]),
        '-i', words, ...audio, '-filter_complex',
        `color=c=0x0B0709:s=1080x1920:r=${FPS}[bg];[bg][0:v]overlay=0:420:shortest=1[a];[a][1:v]overlay=0:1070[b];[b][2:v]overlay=0:0[v]`,
        ...tail]);
    } else {
      execFileSync('ffmpeg', ['-y', '-loglevel', 'error',
        '-framerate', String(FPS), ...trim, '-i', frames(work, day.dir),
        '-i', words, ...audio, '-filter_complex', '[0:v][1:v]overlay=0:0[v]',
        ...tail]);
    }
    console.log(`wrote ${file}`);
  }
  await browser.close();
})();
