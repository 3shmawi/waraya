// The launch video, frame by frame — docs/marketing/launch-video.md — and
// every video after it in the same style (FILMS below): the mirror's is
// docs/marketing/mirror-video.md.
//
//   node tool/promo/film.js WORK [story|feed ...]
//   FILM=mirror node tool/promo/film.js WORK
//
// WORK/mark/{panel,tile}/NNN.png is the ending's walk-in, painted by the game
// (tool/promo/mark_frames.dart). WORK/clips/phone-<name>.mp4 is the game's own footage at a phone's screen
// size (tool/clips.dart with WARAYA_CLIP_DEVICE=844x390@2, 30 fps). This
// cuts it into JPEG frames once, then draws every frame of the video in
// tool/promo/motion.html — window.frame(t) is a pure function of t, so the
// same frame comes out every run — and pipes them into ffmpeg.
//
// Writes the film's own `out(layout)`, docs/media/promo/waraya-<layout>.mp4
// for the launch. Needs ffmpeg and Playwright
// (CHROMIUM=<executable> if Playwright's own browser is not installed).
const fs = require('fs');
const path = require('path');
const { spawn, execFileSync } = require('child_process');
const { chromium } = require('playwright');
const QRCode = require('qrcode');

// Where the code at the end goes: a page that sends an Android to Google
// Play, an iPhone to the App Store, and a computer to the choices.
const GET_URL = 'https://waraya.pages.dev/get';

const FPS = 30;
const REPO = path.resolve(__dirname, '..', '..');

// ——— the layouts ———
// A phone on its side, as wide as the frame: the game is landscape, and a
// narrower phone is a smaller game. Words in the sky above it; the bottom
// fifth of a 9:16 frame is kept for the apps' own buttons and caption.
const LAYOUTS = {
  story: {
    W: 1080, H: 1920,
    screen: { x: 40, y: 760, w: 1000, h: 462 }, bezel: 22,
    horizon: 1252, sunY: 720, capY: 400, lowY: 1420, reflect: true,
    type: { big: 96, mid: 58, small: 48 },
    platCapY: 330, platLift: 70, platScale: 1, cardY: 1300, cardW: 334, cardPad: 22, iconS: 100,
    end: { mark: 250, title: 128, facts: 46, head: 120, horizon: 1250, gap: 60, rowGap: 26, pill: 46,
      qr: { cx: 540, cy: 860, s: 400, text: 52 } },
  },
  feed: {
    W: 1080, H: 1350,
    screen: { x: 40, y: 420, w: 1000, h: 462 }, bezel: 22,
    horizon: 930, sunY: 380, capY: 96, lowY: 958,
    type: { big: 82, mid: 52, small: 40 },
    platCapY: 70, platLift: 190, platScale: 0.74, cardY: 930, cardW: 300, cardPad: 16, iconS: 80,
    end: { mark: 160, title: 104, facts: 34, head: 110, headX: 770, horizon: 760, gap: 50, rowGap: 18, pill: 38,
      qr: { cx: 300, cy: 330, s: 330, text: 38 } },
  },
};

// ——— the clips, and the moves the controls light up with ———
// The moves are each level's recorded `solution` (lib/level/levels.dart);
// tool/clips.dart stands still for leadIn before playing them.
const L = (s) => ({ s, x: -1 }), R = (s) => ({ s, x: 1 }), W = (s) => ({ s, x: 0 });
const j = (m) => ({ ...m, j: true }), c = (m) => ({ ...m, c: true });
const LAUNCH_CLIPS = {
  c1: { file: 'phone-01-the-plate', moves: [R(1.8), W(1.2), L(4.8)] },
  c2: { file: 'phone-02-the-step', moves: [L(3.3), c(W(2.5)), R(.9), W(.15), L(.4), j(L(.55)), j(L(.6)), L(1.5)] },
  c8: { file: 'phone-08-in-the-light', moves: [L(1.58), c(W(2.2)), L(.6), W(1.3), R(.12), j(R(.55)), W(.1), j(R(.6)), R(1.6)] },
  c9: { file: 'phone-09-two-of-you', moves: [L(3.1), W(1.8), R(2.5), W(1.8), R(1.4), R(1.8)] },
  c15: { file: 'phone-15-all-of-it', moves: [L(.27), j(L(.55)), L(.15), W(.2), R(2.3), c(W(1.2)), R(3), W(.5), R(.4),
    j(R(.55)), R(.1), W(1), R(.9), j(R(.55)), R(3.9), c(W(1.2)), L(.6), W(1.1), R(.05), j(R(.55)), W(.1), j(R(.6)), R(2)] },
};

// ——— the cut ———
// Times in seconds; `from`/`hold`/`a`/`b` are times into a clip. Positions
// are in the phone screen's own pixels (844 x 390), read off the footage.
const LAUNCH_SCENES = {
  // A door opens in front of you, by itself.
  hook: { at: 0, dur: 1.9, from: 4.2, doorX: [[4.1, 140], [4.67, 207], [5.0, 245], [6.05, 375]], doorY: [185, 335],
    glow: [4.65, 5.6] },
  // Who opened it: freeze while your past stands on the plate, push in on it.
  reveal: { at: 1.9, dur: 2.8, hold: 6.05, shadow: { x: 690, y: 311 }, zoom: 1.7 },
  // Back to the start, like a tape.
  rewind: { at: 4.7, dur: 0.8, a: 6.05, b: 0.6 },
  // How: the whole level, in three steps.
  how: { at: 5.5, dur: 6.8, from: 0.6, steps: [
    [0, 2.9, 1, 'اقف على الزرار', 'حتى لو مالوش لازمة دلوقتي'],
    [3.0, 4.3, 2, 'وامشي', 'من غير ما تستنى'],
    [4.4, 6.8, 3, 'ماضيك يدوس مكانك', 'والباب يفتحلك'],
  ] },
  // The second rule: your past is a body you can stand on.
  step: { at: 12.3, dur: 4.2, from: 5.4, shadowY: 297,
    shadowX: [[6.9, 378], [7.3, 330], [7.6, 305], [7.8, 320], [7.95, 340], [8.15, 360], [8.4, 395], [8.65, 425], [8.9, 430]],
    // The tag from when your past ducks; the arc while you run at it, gone
    // the frame you leave the ground (8.05).
    label: [6.9, 8.9], arc: [7.3, 8.0] },
  // How far it goes, fast.
  montage: { at: 16.5, dur: 4.6, cuts: [
    { clip: 'c9', from: 7.4, dur: 1.6, text: 'ظلّين؟', sub: 'يبقى انت في مكانين في نفس اللحظة', shake: true },
    // Your past walks into the light and is gone (4.8), then out the far side.
    { clip: 'c8', from: 4.35, dur: 1.5, text: 'والنور بيمسح ماضيك', sub: 'جوّه النور… مش موجود', flash: 0.5 },
    { clip: 'c15', from: 1.0, dur: 1.5, counter: true, sub: 'كل واحدة أصعب من اللي قبلها' },
  ] },
  // Everywhere.
  platforms: { at: 21.1, dur: 3.1, clip: 'c15', from: 18.4 },
  // Long enough to get a phone out and scan the code.
  end: { at: 24.2, dur: 6.3 },
};

// ——— the mirror, the first weekly drop (docs/marketing/mirror-video.md) ———
// The same cut as the launch, about one thing: your past arrives on the
// mirror and you are where it is. Positions read off the footage the same
// way (844 x 390, frame round(t*30)+1).
const MIRROR_CLIPS = {
  m1: { file: 'phone-16-the-mirror', moves: [L(.5), R(2.25), W(2.2), L(5)] },
  m2: { file: 'phone-17-the-mirror-in-the-light', moves: [R(2.15), W(1.85), R(1.1), W(1.5), L(6)] },
  m3: { file: 'phone-24-two-mirrors', moves: [R(2.2), R(.95), W(1.7), L(.5), W(.6), L(.5), W(1), R(6)] },
  m4: { file: 'phone-25-all-of-it-in-the-mirror', moves: [R(1.75), W(2), R(1.9), W(1.2), L(7)] },
};
const MIRROR_SCENES = {
  // You are down on the button, where there is no climbing back — and then
  // you are up on the ledge.
  hook: { at: 0, dur: 2.4, clip: 'm1', from: 3.4, text: 'نزل تحت…', sub: 'ورجع فوق إزاي؟', subAt: 1.4 },
  // How: freeze the moment your past arrives on the mirror.
  reveal: { at: 2.4, dur: 2.8, clip: 'm1', hold: 5.1, shadow: { x: 172, y: 190 }, zoom: 1.7,
    label: 'ماضيك', text: 'ماضيك وصل [المراية]', sub: 'فانت رجعت مكانه', low: 'المراية بترجّعك لمكان ماضيك' },
  rewind: { at: 5.2, dur: 0.8, clip: 'm1', a: 5.1, b: 0.6, secs: 4 },
  how: { at: 6.0, dur: 7.6, clip: 'm1', from: 0.6, you: false, steps: [
    [0, 2.4, 1, 'المس المراية', 'وكمّل عادي'],
    [2.5, 4.3, 2, 'انزل على الزرار', 'ومن تحت مفيش طلعة'],
    [4.4, 7.6, 3, 'ماضيك يوصل المراية', 'تطلع مكانه… وهو يدوس الزرار'],
  ] },
  montage: { at: 13.6, dur: 4.7, cuts: [
    { clip: 'm2', from: 5.6, dur: 1.6, text: 'والمراية في النور؟', sub: 'ماضيك في النور مش موجود', flash: 0.5 },
    { clip: 'm3', from: 5.1, dur: 1.5, text: 'مرايتين؟', sub: 'كل واحدة بترجّعك ليها', shake: true },
    { clip: 'm4', from: 7.0, dur: 1.6, counter: true, to: 9, unit: 'مراحل جديدة', sub: 'كل واحدة أصعب من اللي قبلها' },
  ] },
  end: { at: 18.3, dur: 6.3 },
};

const FILMS = {
  launch: { clips: LAUNCH_CLIPS, scenes: LAUNCH_SCENES,
    out: (layout) => path.join(REPO, 'docs', 'media', 'promo', `waraya-${layout}.mp4`) },
  mirror: { clips: MIRROR_CLIPS, scenes: MIRROR_SCENES, endNew: 'جديد: المراية',
    out: (layout) => path.join(REPO, 'docs', 'media', 'drops', `mirror-${layout}.mp4`) },
};
const FILM = FILMS[process.env.FILM || 'launch'];
if (!FILM) throw new Error(`no film called ${process.env.FILM}: ${Object.keys(FILMS).join(', ')}`);
const CLIPS = FILM.clips, SCENES = FILM.scenes;

function extract(work, key) {
  const dir = path.join(work, 'jpg', key);
  if (fs.existsSync(path.join(dir, 'done'))) return fs.readdirSync(dir).filter((f) => f.endsWith('.jpg')).length;
  fs.mkdirSync(dir, { recursive: true });
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', path.join(work, 'clips', CLIPS[key].file + '.mp4'),
    '-vf', `fps=${FPS}`, '-q:v', '2', path.join(dir, '%05d.jpg')]);
  fs.writeFileSync(path.join(dir, 'done'), '');
  return fs.readdirSync(dir).filter((f) => f.endsWith('.jpg')).length;
}

async function film(page, work, name) {
  const layout = { ...LAYOUTS[name] };
  layout.k = layout.screen.w / 844;
  const counts = {};
  for (const key of Object.keys(CLIPS)) counts[key] = extract(work, key);
  const clips = {};
  for (const [key, cl] of Object.entries(CLIPS)) {
    clips[key] = { moves: cl.moves, leadIn: 0.8, endsAt: cl.moves.reduce((a, m) => a + m.s, 0) };
  }
  const total = Math.max(...Object.values(SCENES).map((s) => s.at + s.dur));
  await page.setViewportSize({ width: layout.W, height: layout.H });
  const code = QRCode.create(GET_URL, { errorCorrectionLevel: 'H' }).modules;
  const qr = { size: code.size, data: Array.from(code.data) };
  await page.evaluate(({ layout, scenes, clips, counts, work, qr, endNew }) => {
    window.setup({
      L: layout, scenes, clips, qr, endNew,
      mark: (shape, p) => `file://${work}/mark/${shape}/${String(Math.round(p * 45)).padStart(3, '0')}.png`,
      frame: (key, ct) => {
        const i = Math.min(counts[key], Math.max(1, Math.round(ct * 30) + 1));
        return `file://${work}/jpg/${key}/${String(i).padStart(5, '0')}.jpg`;
      },
    });
  }, { layout, scenes: SCENES, clips, counts, work, qr, endNew: FILM.endNew });

  const only = process.env.FRAMES;   // "12.5,20": just those stills, for looking
  if (only) {
    for (const t of only.split(',').map(Number)) {
      await page.evaluate((t) => window.frame(t), t);
      await page.screenshot({ path: path.join(work, `still-${name}-${t}.png`) });
    }
    return;
  }

  const out = FILM.out(name);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  // A silent track: some apps treat a video with no sound as broken, and
  // every one of them lets the poster put a sound over it.
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error',
    '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'png', '-i', '-',
    '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
    '-map', '0:v', '-map', '1:a', '-shortest',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '96k', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  const done = new Promise((ok, fail) => ff.on('close', (code) => (code ? fail(new Error('ffmpeg ' + code)) : ok())));

  const frames = Math.round(total * FPS);
  for (let n = 0; n < frames; n++) {
    const t = n / FPS;
    await page.evaluate((t) => window.frame(t), t);
    const png = await page.screenshot({ type: 'png' });
    if (!ff.stdin.write(png)) await new Promise((r) => ff.stdin.once('drain', r));
    if (n % 60 === 0) process.stdout.write(`\r${name} ${t.toFixed(1)}/${total}s`);
  }
  ff.stdin.end();
  await done;
  console.log(`\nwrote ${out}`);
}

(async () => {
  const [work, ...names] = process.argv.slice(2);
  const browser = await chromium.launch({
    ...(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {}),
    args: ['--allow-file-access-from-files'],
  });
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.goto('file://' + path.resolve(__dirname, 'motion.html'));
  for (const name of names.length ? names : Object.keys(LAYOUTS)) await film(page, path.resolve(work), name);
  await browser.close();
})();
